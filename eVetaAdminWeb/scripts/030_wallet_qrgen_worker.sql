-- 030_wallet_qrgen_worker.sql
-- Tokens y RPC para worker Termux 24/7 (generacion QR de recargas).

create table if not exists public.wallet_qrgen_tokens (
  id uuid primary key default gen_random_uuid(),
  label text,
  token_hash text not null unique,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

-- Migración segura si la tabla ya existía con otro esquema (p.ej. sin token_hash).
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'wallet_qrgen_tokens'
  ) then
    if not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'wallet_qrgen_tokens'
        and column_name = 'token_hash'
    ) then
      alter table public.wallet_qrgen_tokens add column token_hash text;
    end if;

    -- Si hay alguna columna antigua llamada "token", intentamos preservar compatibilidad.
    if exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'wallet_qrgen_tokens'
        and column_name = 'token'
    ) then
      execute $q$
        update public.wallet_qrgen_tokens
        set token_hash = coalesce(token_hash, md5(token::text))
      $q$;
    end if;

    -- Asegura NOT NULL + unicidad (puede fallar si hay filas antiguas sin hash).
    begin
      alter table public.wallet_qrgen_tokens alter column token_hash set not null;
    exception when others then
      -- Si hay filas legacy sin token_hash, se quedará nullable hasta que se limpien.
      null;
    end;

    begin
      create unique index if not exists uq_wallet_qrgen_tokens_token_hash
      on public.wallet_qrgen_tokens(token_hash);
    exception when others then
      null;
    end;
  end if;
end $$;

create index if not exists idx_wallet_qrgen_tokens_active
on public.wallet_qrgen_tokens(is_active, created_at desc);

alter table if exists public.wallet_qrgen_tokens enable row level security;

drop policy if exists "wallet_qrgen_tokens_admin_select" on public.wallet_qrgen_tokens;
create policy "wallet_qrgen_tokens_admin_select"
on public.wallet_qrgen_tokens
for select
to authenticated
using (public.profile_is_admin());

drop policy if exists "wallet_qrgen_tokens_admin_update" on public.wallet_qrgen_tokens;
create policy "wallet_qrgen_tokens_admin_update"
on public.wallet_qrgen_tokens
for update
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

create or replace function public.create_wallet_qrgen_token(
  p_label text default null
)
returns table (
  token_id uuid,
  token text,
  label text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
  v_id uuid;
  v_has_token_col boolean := false;
begin
  if not public.profile_is_admin() then
    raise exception 'Sin permisos de administrador.';
  end if;

  v_token := 'qrgen_' || md5(random()::text || clock_timestamp()::text || auth.uid()::text);

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'wallet_qrgen_tokens'
      and column_name = 'token'
  ) into v_has_token_col;

  if v_has_token_col then
    execute $q$
      insert into public.wallet_qrgen_tokens (
        label,
        token,
        token_hash,
        is_active,
        created_by
      ) values (
        nullif(trim(coalesce($1, '')), ''),
        $2,
        md5($2),
        true,
        $3
      )
      returning id, label, created_at
    $q$
    into v_id, label, created_at
    using p_label, v_token, auth.uid();
  else
    insert into public.wallet_qrgen_tokens (
      label,
      token_hash,
      is_active,
      created_by
    ) values (
      nullif(trim(coalesce(p_label, '')), ''),
      md5(v_token),
      true,
      auth.uid()
    )
    returning id, wallet_qrgen_tokens.label, wallet_qrgen_tokens.created_at
    into v_id, label, created_at;
  end if;

  token_id := v_id;
  token := v_token;
  return next;
end;
$$;

create or replace function public.revoke_wallet_qrgen_token(
  p_token_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.profile_is_admin() then
    raise exception 'Sin permisos de administrador.';
  end if;

  update public.wallet_qrgen_tokens
  set is_active = false
  where id = p_token_id;
end;
$$;

create or replace function public.list_wallet_qrgen_tokens()
returns table (
  id uuid,
  label text,
  is_active boolean,
  created_at timestamptz,
  last_used_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    t.id,
    t.label,
    t.is_active,
    t.created_at,
    t.last_used_at
  from public.wallet_qrgen_tokens t
  where t.is_active = true
  order by t.created_at desc;
$$;

create or replace function public.touch_wallet_qrgen_token(
  p_token text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select id
  into v_id
  from public.wallet_qrgen_tokens
  where token_hash = md5(p_token)
    and is_active = true
  limit 1;

  if v_id is null then
    return false;
  end if;

  update public.wallet_qrgen_tokens
  set last_used_at = now()
  where id = v_id;

  return true;
end;
$$;

create or replace function public.claim_next_wallet_topup_for_qrgen(
  p_worker_id text default null
)
returns table (
  id uuid,
  user_id uuid,
  reference_code text,
  amount numeric,
  status public.wallet_topup_status,
  created_at timestamptz,
  proof_url text,
  proof_note text,
  reconciliation_hint jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topup public.wallet_topups;
begin
  select *
  into v_topup
  from public.wallet_topups wt
  where wt.status = 'pending_proof'
    and coalesce((wt.reconciliation_hint ->> 'qrgen_claimed')::boolean, false) = false
    -- No procesar solicitudes viejas: si pasan 10 min, el worker las ignora.
    and wt.created_at >= now() - interval '10 minutes'
    -- Si expiró (default 30 min), tampoco.
    and wt.expires_at > now()
  order by wt.created_at asc
  limit 1
  for update skip locked;

  if not found then
    return;
  end if;

  update public.wallet_topups
  set reconciliation_hint = coalesce(wallet_topups.reconciliation_hint, '{}'::jsonb)
    || jsonb_build_object(
      'qrgen_claimed', true,
      'qrgen_claimed_at', now(),
      'qrgen_worker_id', nullif(trim(coalesce(p_worker_id, '')), '')
    )
  where wallet_topups.id = v_topup.id;

  return query
  select
    wt.id,
    wt.user_id,
    wt.reference_code,
    wt.amount,
    wt.status,
    wt.created_at,
    wt.proof_url,
    wt.proof_note,
    wt.reconciliation_hint
  from public.wallet_topups wt
  where wt.id = v_topup.id;
end;
$$;

revoke all on function public.create_wallet_qrgen_token(text) from public;
revoke all on function public.revoke_wallet_qrgen_token(uuid) from public;
revoke all on function public.list_wallet_qrgen_tokens() from public;
revoke all on function public.touch_wallet_qrgen_token(text) from public;
revoke all on function public.claim_next_wallet_topup_for_qrgen(text) from public;

grant execute on function public.create_wallet_qrgen_token(text) to authenticated;
grant execute on function public.revoke_wallet_qrgen_token(uuid) to authenticated;
grant execute on function public.list_wallet_qrgen_tokens() to authenticated;
grant execute on function public.touch_wallet_qrgen_token(text) to service_role;
grant execute on function public.claim_next_wallet_topup_for_qrgen(text) to service_role;

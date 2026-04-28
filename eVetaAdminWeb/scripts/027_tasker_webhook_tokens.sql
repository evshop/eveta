-- 027_tasker_webhook_tokens.sql
-- Tokens para ingesta de notificaciones bancarias desde Tasker.

create table if not exists public.wallet_webhook_tokens (
  id uuid primary key default gen_random_uuid(),
  label text,
  token_hash text not null unique,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);

create index if not exists idx_wallet_webhook_tokens_active
on public.wallet_webhook_tokens(is_active, created_at desc);

alter table if exists public.wallet_webhook_tokens enable row level security;

drop policy if exists "wallet_webhook_tokens_admin_select" on public.wallet_webhook_tokens;
create policy "wallet_webhook_tokens_admin_select"
on public.wallet_webhook_tokens
for select
to authenticated
using (public.profile_is_admin());

drop policy if exists "wallet_webhook_tokens_admin_update" on public.wallet_webhook_tokens;
create policy "wallet_webhook_tokens_admin_update"
on public.wallet_webhook_tokens
for update
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

create or replace function public.create_wallet_webhook_token(
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
begin
  if not public.profile_is_admin() then
    raise exception 'Sin permisos de administrador.';
  end if;

  v_token := 'tsk_' || md5(random()::text || clock_timestamp()::text || auth.uid()::text);

  insert into public.wallet_webhook_tokens (
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
  returning id, wallet_webhook_tokens.label, wallet_webhook_tokens.created_at
  into v_id, label, created_at;

  token_id := v_id;
  token := v_token;
  return next;
end;
$$;

create or replace function public.revoke_wallet_webhook_token(
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

  update public.wallet_webhook_tokens
  set is_active = false
  where id = p_token_id;
end;
$$;

create or replace function public.list_wallet_webhook_tokens()
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
  from public.wallet_webhook_tokens t
  where t.is_active = true
  order by t.created_at desc;
$$;

create or replace function public.touch_wallet_webhook_token(
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
  from public.wallet_webhook_tokens
  where token_hash = md5(p_token)
    and is_active = true
  limit 1;

  if v_id is null then
    return false;
  end if;

  update public.wallet_webhook_tokens
  set last_used_at = now()
  where id = v_id;

  return true;
end;
$$;

revoke all on function public.create_wallet_webhook_token(text) from public;
revoke all on function public.revoke_wallet_webhook_token(uuid) from public;
revoke all on function public.list_wallet_webhook_tokens() from public;
revoke all on function public.touch_wallet_webhook_token(text) from public;

grant execute on function public.create_wallet_webhook_token(text) to authenticated;
grant execute on function public.revoke_wallet_webhook_token(uuid) to authenticated;
grant execute on function public.list_wallet_webhook_tokens() to authenticated;
grant execute on function public.touch_wallet_webhook_token(text) to service_role;

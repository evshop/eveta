-- 028_wallet_qr_sources.sql
-- Almacena QR fuente (imagen + texto plano) de recargas.

create table if not exists public.wallet_topup_qr_sources (
  id uuid primary key default gen_random_uuid(),
  topup_id uuid not null references public.wallet_topups(id) on delete cascade,
  provider text not null default 'yape',
  image_url text not null,
  raw_qr_text text not null,
  decoded_ok boolean not null default true,
  decoded_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists uq_wallet_topup_qr_sources_topup_provider
on public.wallet_topup_qr_sources(topup_id, provider);

alter table if exists public.wallet_topup_qr_sources enable row level security;

drop policy if exists "wallet_topup_qr_sources_admin_select" on public.wallet_topup_qr_sources;
create policy "wallet_topup_qr_sources_admin_select"
on public.wallet_topup_qr_sources
for select
to authenticated
using (public.profile_is_admin());

create or replace function public.store_wallet_topup_qr_source(
  p_topup_id uuid,
  p_provider text,
  p_image_url text,
  p_raw_qr_text text,
  p_decoded_ok boolean default true
)
returns public.wallet_topup_qr_sources
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.wallet_topup_qr_sources;
begin
  -- auth.uid() puede ser null cuando se invoca con service role desde Edge Functions.
  if auth.uid() is not null and not public.profile_is_admin() then
    raise exception 'Sin permisos de administrador.';
  end if;

  insert into public.wallet_topup_qr_sources (
    topup_id,
    provider,
    image_url,
    raw_qr_text,
    decoded_ok,
    created_by
  )
  values (
    p_topup_id,
    lower(coalesce(nullif(trim(p_provider), ''), 'yape')),
    trim(p_image_url),
    p_raw_qr_text,
    coalesce(p_decoded_ok, true),
    auth.uid()
  )
  on conflict (topup_id, provider)
  do update set
    image_url = excluded.image_url,
    raw_qr_text = excluded.raw_qr_text,
    decoded_ok = excluded.decoded_ok,
    decoded_at = now(),
    created_by = excluded.created_by
  returning * into v_row;

  update public.wallet_topups
  set reconciliation_hint = coalesce(reconciliation_hint, '{}'::jsonb)
    || jsonb_build_object(
      'qr_provider', v_row.provider,
      'qr_source_id', v_row.id,
      'qr_decoded_at', v_row.decoded_at
    ),
    status = case
      when status = 'pending_proof' then 'pending_review'::public.wallet_topup_status
      else status
    end
  where id = p_topup_id;

  return v_row;
end;
$$;

revoke all on function public.store_wallet_topup_qr_source(uuid, text, text, text, boolean) from public;
grant execute on function public.store_wallet_topup_qr_source(uuid, text, text, text, boolean) to authenticated, service_role;

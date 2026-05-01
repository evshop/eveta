-- 031_wallet_topup_qr_pending_proof.sql
-- 1) Al guardar texto del QR (worker) NO cambiar estado: sigue pending_proof hasta que el usuario suba comprobante.
-- 2) Ventana de pago del QR: 10 minutos (nuevas recargas).

-- A) store_wallet_topup_qr_source: solo hint + QR; no forzar pending_review
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
    )
  where id = p_topup_id;

  return v_row;
end;
$$;

-- B) Nuevas filas: expiración 10 minutos
alter table public.wallet_topups
  alter column expires_at set default (now() + interval '10 minutes');

-- C) create_wallet_topup_request: fija expires_at explícito (10 min)
create or replace function public.create_wallet_topup_request(
  p_amount numeric
)
returns table (
  topup_id uuid,
  reference_code text,
  amount numeric,
  status text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
set default_transaction_read_only = off
as $$
declare
  v_uid uuid;
  v_amount numeric(14,2);
  v_ref text;
  v_topup_id uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  v_amount := round(coalesce(p_amount, 0)::numeric, 2);
  if v_amount <= 0 then
    raise exception 'El monto debe ser mayor a 0.';
  end if;

  perform public.ensure_wallet_account(v_uid);

  v_ref := public.generate_wallet_reference_code();
  insert into public.wallet_topups (
    user_id,
    reference_code,
    amount,
    status,
    expires_at
  ) values (
    v_uid,
    v_ref,
    v_amount,
    'pending_proof',
    now() + interval '10 minutes'
  )
  returning id into v_topup_id;

  return query
  select
    t.id,
    t.reference_code,
    t.amount,
    t.status::text,
    t.expires_at
  from public.wallet_topups t
  where t.id = v_topup_id;
end;
$$;

revoke all on function public.store_wallet_topup_qr_source(uuid, text, text, text, boolean) from public;
grant execute on function public.store_wallet_topup_qr_source(uuid, text, text, text, boolean) to authenticated, service_role;

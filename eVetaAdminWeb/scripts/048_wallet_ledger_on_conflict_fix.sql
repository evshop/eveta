-- 048_wallet_ledger_on_conflict_fix.sql
--
-- Problema: 024 crea
--   CREATE UNIQUE INDEX uq_wallet_ledger_topup_credit ON wallet_ledger(topup_id)
--   WHERE topup_id IS NOT NULL AND direction = 'credit' AND source_type = 'topup_approved';
-- Eso es un ÍNDICE único parcial, no un CONSTRAINT con ese nombre.
-- Las funciones usaban "ON CONFLICT ON CONSTRAINT uq_wallet_ledger_topup_credit" → error 42704.
--
-- Solución: usar inferencia que coincida con ese índice parcial:
--   ON CONFLICT (topup_id) WHERE ( predicado igual al del índice ) DO NOTHING;

create or replace function public.wallet_apply_topup_credit_from_bank_event(
  p_topup_id uuid,
  p_event_id uuid
)
returns public.wallet_topups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topup public.wallet_topups;
  v_credit numeric(14,2);
begin
  select *
  into v_topup
  from public.wallet_topups
  where id = p_topup_id
  for update;

  if not found then
    raise exception 'Recarga no encontrada.';
  end if;

  if v_topup.status = 'approved' then
    return v_topup;
  end if;

  if v_topup.status not in ('pending_proof', 'pending_review') then
    raise exception 'La recarga no está pendiente.';
  end if;

  if v_topup.expires_at <= now() then
    update public.wallet_topups set status = 'expired' where id = v_topup.id returning * into v_topup;
    return v_topup;
  end if;

  v_credit := round(coalesce(v_topup.amount, 0)::numeric, 2);
  if v_credit <= 0 then
    raise exception 'Monto inválido.';
  end if;

  perform public.ensure_wallet_account(v_topup.user_id);

  update public.wallet_accounts
  set balance = balance + v_credit
  where user_id = v_topup.user_id;

  insert into public.wallet_ledger (
    user_id,
    direction,
    amount,
    source_type,
    source_id,
    topup_id,
    meta
  )
  values (
    v_topup.user_id,
    'credit',
    v_credit,
    'topup_approved',
    v_topup.reference_code,
    v_topup.id,
    jsonb_build_object(
      'auto', true,
      'bank_event_id', p_event_id,
      'credited_amount', v_credit,
      'paid_amount', v_topup.amount,
      'requested_amount', v_topup.requested_amount,
      'verification_delta', v_topup.verification_delta
    )
  )
  on conflict (topup_id) where (
    topup_id is not null
    and direction = 'credit'
    and source_type = 'topup_approved'
  )
  do nothing;

  update public.wallet_topups
  set
    status = 'approved',
    approved_by = null,
    approved_at = now(),
    reconciliation_hint = coalesce(reconciliation_hint, '{}'::jsonb)
      || jsonb_build_object(
        'bank_match_status', 'confirmed',
        'bank_confirmed_at', now()
      )
      || case when p_event_id is null then '{}'::jsonb else jsonb_build_object('bank_event_id', p_event_id) end
  where id = v_topup.id
  returning * into v_topup;

  return v_topup;
end;
$$;

revoke all on function public.wallet_apply_topup_credit_from_bank_event(uuid, uuid) from public;
revoke all on function public.wallet_apply_topup_credit_from_bank_event(uuid, uuid) from anon;
revoke all on function public.wallet_apply_topup_credit_from_bank_event(uuid, uuid) from authenticated;
revoke all on function public.wallet_apply_topup_credit_from_bank_event(uuid, uuid) from service_role;

-- Una sola implementación: delega en wallet_apply (evita duplicar el INSERT y el ON CONFLICT).
create or replace function public.auto_approve_wallet_topup_by_bank_event(
  p_topup_id uuid,
  p_event_id uuid default null
)
returns public.wallet_topups
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Solo service_role.';
  end if;

  return public.wallet_apply_topup_credit_from_bank_event(p_topup_id, p_event_id);
end;
$$;

revoke all on function public.auto_approve_wallet_topup_by_bank_event(uuid, uuid) from public;
grant execute on function public.auto_approve_wallet_topup_by_bank_event(uuid, uuid) to service_role;

create or replace function public.approve_wallet_topup(
  p_topup_id uuid
)
returns public.wallet_topups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_topup public.wallet_topups;
begin
  if not public.profile_is_admin() then
    raise exception 'Sin permisos para aprobar recargas.';
  end if;

  select *
  into v_topup
  from public.wallet_topups
  where id = p_topup_id
  for update;

  if not found then
    raise exception 'Recarga no encontrada.';
  end if;

  if v_topup.status = 'approved' then
    return v_topup;
  end if;

  if v_topup.status <> 'pending_review' then
    raise exception 'La recarga no está en revisión.';
  end if;

  if coalesce(v_topup.proof_url, '') = '' then
    raise exception 'No existe comprobante de pago.';
  end if;

  perform public.ensure_wallet_account(v_topup.user_id);

  update public.wallet_accounts
  set balance = balance + v_topup.amount
  where user_id = v_topup.user_id;

  insert into public.wallet_ledger (
    user_id,
    direction,
    amount,
    source_type,
    source_id,
    topup_id,
    meta
  )
  values (
    v_topup.user_id,
    'credit',
    v_topup.amount,
    'topup_approved',
    v_topup.reference_code,
    v_topup.id,
    jsonb_build_object(
      'approved_by', auth.uid(),
      'reference_code', v_topup.reference_code
    )
  )
  on conflict (topup_id) where (
    topup_id is not null
    and direction = 'credit'
    and source_type = 'topup_approved'
  )
  do nothing;

  update public.wallet_topups
  set
    status = 'approved',
    approved_by = auth.uid(),
    approved_at = now(),
    rejected_at = null,
    reject_reason = null
  where id = p_topup_id
  returning * into v_topup;

  return v_topup;
end;
$$;

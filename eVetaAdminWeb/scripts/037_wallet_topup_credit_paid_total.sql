-- 037_wallet_topup_credit_paid_total.sql
-- Tras verificación por notificación (monto exacto), acredita lo que el usuario PAGÓ:
--   wallet_topups.amount = requested_amount + verification_delta
-- Antes solo se acreditaba requested_amount; ahora el saldo sube por el total pagado.

create or replace function public.auto_approve_wallet_topup_by_bank_event(
  p_topup_id uuid,
  p_event_id uuid default null
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
  if auth.role() <> 'service_role' then
    raise exception 'Solo service_role.';
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
  on conflict on constraint uq_wallet_ledger_topup_credit
  do nothing;

  update public.wallet_topups
  set
    status = 'approved',
    approved_by = null,
    approved_at = now(),
    reconciliation_hint = coalesce(reconciliation_hint, '{}'::jsonb)
      || case when p_event_id is null then '{}'::jsonb else jsonb_build_object('bank_event_id', p_event_id) end
  where id = v_topup.id
  returning * into v_topup;

  return v_topup;
end;
$$;

revoke all on function public.auto_approve_wallet_topup_by_bank_event(uuid, uuid) from public;
grant execute on function public.auto_approve_wallet_topup_by_bank_event(uuid, uuid) to service_role;

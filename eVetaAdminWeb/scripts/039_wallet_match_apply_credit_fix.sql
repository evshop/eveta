-- 039_wallet_match_apply_credit_fix.sql
-- Problema: match_wallet_topups_with_bank_event llamaba a auto_approve_wallet_topup_by_bank_event,
-- que exige auth.role() = 'service_role'. Dentro de una función SECURITY DEFINER anidada el JWT/rol
-- a veces no es 'service_role', la acreditación falla y toda la transacción del match se revierte.
--
-- Solución:
--   - wallet_apply_topup_credit_from_bank_event: aplica crédito y aprueba (sin chequeo de rol).
--     NO conceder a anon/authenticated/service_role: solo la invoca el owner desde match/auto_approve.
--   - match usa wallet_apply... directamente.
--   - auto_approve sigue disponible para llamadas directas con service_role (delega a wallet_apply).
--   - bank_incoming_events.matched_reference_code: código EV... visible en admin sin join.
--   - Ventana de tiempo del evento vs. created_at un poco más amplia (notificaciones retrasadas).

alter table public.bank_incoming_events
  add column if not exists matched_reference_code text;

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
  on conflict on constraint uq_wallet_ledger_topup_credit
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

create or replace function public.match_wallet_topups_with_bank_event(
  p_event_id uuid
)
returns table (
  topup_id uuid,
  event_id uuid,
  match_status text,
  score integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.bank_incoming_events;
  v_topup public.wallet_topups;
  v_score int := 0;
  v_ev_ts timestamptz;
  v_after public.wallet_topups;
  v_have_topup boolean := false;
begin
  select *
  into v_event
  from public.bank_incoming_events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Evento bancario no encontrado.';
  end if;

  v_ev_ts := coalesce(v_event.detected_at, v_event.received_at, now());

  if coalesce(trim(v_event.detected_reference), '') <> '' then
    select *
    into v_topup
    from public.wallet_topups
    where reference_code = trim(v_event.detected_reference)
      and status in ('pending_review', 'pending_proof')
      and expires_at > v_ev_ts
      and expires_at > now()
    order by created_at desc
    limit 1;

    if found then
      v_score := 95;
      v_have_topup := true;
    end if;
  end if;

  if not v_have_topup and v_event.detected_amount is not null then
    select *
    into v_topup
    from public.wallet_topups
    where status in ('pending_review', 'pending_proof')
      and round(amount, 2) = round(v_event.detected_amount::numeric, 2)
      and expires_at > v_ev_ts
      and expires_at > now()
      and v_ev_ts >= created_at - interval '2 hours'
      and v_ev_ts <= expires_at
    order by created_at desc
    limit 1;

    if found then
      v_score := 70;
      v_have_topup := true;
    end if;
  end if;

  if not v_have_topup then
    update public.bank_incoming_events
    set
      match_status = 'unmatched',
      matched_topup_id = null,
      matched_reference_code = null,
      matched_at = null
    where id = v_event.id;

    return query
    select null::uuid, v_event.id, 'unmatched'::text, 0;
    return;
  end if;

  update public.wallet_topups
  set reconciliation_hint = coalesce(reconciliation_hint, '{}'::jsonb)
    || jsonb_build_object(
      'bank_event_id', v_event.id,
      'bank_match_status', 'suggested',
      'bank_match_score', v_score,
      'bank_detected_amount', v_event.detected_amount,
      'bank_detected_reference', v_event.detected_reference,
      'bank_detected_at', v_ev_ts
    )
  where id = v_topup.id;

  v_after := public.wallet_apply_topup_credit_from_bank_event(v_topup.id, v_event.id);

  if v_after.status = 'approved' then
    update public.bank_incoming_events
    set
      match_status = 'matched_confirmed',
      matched_topup_id = v_topup.id,
      matched_reference_code = v_topup.reference_code,
      matched_at = now()
    where id = v_event.id;

    return query
    select v_topup.id, v_event.id, 'matched_confirmed'::text, v_score;
  else
    update public.bank_incoming_events
    set
      match_status = 'matched_suggested',
      matched_topup_id = v_topup.id,
      matched_reference_code = v_topup.reference_code,
      matched_at = now()
    where id = v_event.id;

    return query
    select v_topup.id, v_event.id, 'matched_suggested'::text, v_score;
  end if;
end;
$$;

revoke all on function public.match_wallet_topups_with_bank_event(uuid) from public;
grant execute on function public.match_wallet_topups_with_bank_event(uuid) to service_role;

-- Opcional: rellenar código EV en eventos ya conciliados antes de esta migración.
update public.bank_incoming_events e
set matched_reference_code = t.reference_code
from public.wallet_topups t
where e.matched_topup_id = t.id
  and (e.matched_reference_code is null or e.matched_reference_code = '');

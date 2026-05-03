-- 044_wallet_match_fix_created_window.sql
-- Corrige 043: el filtro created_at >= now() - 24h era demasiado estricto (ventana deslizante).
-- Una recarga puede ser válida por expires_at y quedar fuera de ese created_at aunque el monto coincida.
-- Regla: notificación received_at en las últimas 24 h; recarga pendiente con expires_at > now();
--         monto exacto. Sin filtro por created_at.

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

  if v_event.received_at < now() - interval '24 hours' then
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

  if v_event.detected_amount is null then
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

  select *
  into v_topup
  from public.wallet_topups
  where status in ('pending_review', 'pending_proof')
    and round(amount, 2) = round(v_event.detected_amount::numeric, 2)
    and expires_at > now()
  order by created_at desc
  limit 1;

  if found then
    v_score := 70;
    v_have_topup := true;
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
      'bank_received_at', v_event.received_at
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

-- 042_wallet_match_time_received_at_first.sql
-- El teléfono/Tasker manda "3-5-2026 18.01" en hora local (p. ej. Bolivia UTC-4).
-- Si detected_at se guardó como si fuera UTC del servidor, queda ~4 h antes de received_at
-- y el match falla: v_ev_ts < created_at del topup.
--
-- Para conciliar usamos primero received_at (now() de Postgres al insertar = mismo reloj que created_at del topup).
-- detected_at sigue guardándose para mostrar en admin; el webhook debe corregir el offset (ver tasker-bank-webhook).

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

  v_ev_ts := coalesce(v_event.received_at, v_event.detected_at, now());

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

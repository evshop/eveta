-- 032_wallet_bank_match_pending_proof.sql
-- Tras 031, las recargas siguen en pending_proof hasta subir comprobante.
-- El matcher bancario debe poder sugerir match también en pending_proof (monto / referencia).

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
begin
  select *
  into v_event
  from public.bank_incoming_events
  where id = p_event_id
  for update;

  if not found then
    raise exception 'Evento bancario no encontrado.';
  end if;

  if coalesce(trim(v_event.detected_reference), '') <> '' then
    select *
    into v_topup
    from public.wallet_topups
    where reference_code = trim(v_event.detected_reference)
      and status in ('pending_review', 'pending_proof')
    order by created_at desc
    limit 1;

    if found then
      v_score := 95;
    end if;
  end if;

  if v_topup.id is null and v_event.detected_amount is not null then
    select *
    into v_topup
    from public.wallet_topups
    where status in ('pending_review', 'pending_proof')
      and amount = v_event.detected_amount
      and created_at >= coalesce(v_event.detected_at, v_event.received_at) - interval '2 hours'
      and created_at <= coalesce(v_event.detected_at, v_event.received_at) + interval '2 hours'
    order by abs(extract(epoch from (created_at - coalesce(v_event.detected_at, v_event.received_at)))) asc
    limit 1;

    if found then
      v_score := 70;
    end if;
  end if;

  if v_topup.id is null then
    update public.bank_incoming_events
    set
      match_status = 'unmatched',
      matched_topup_id = null,
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
      'bank_detected_at', coalesce(v_event.detected_at, v_event.received_at)
    )
  where id = v_topup.id;

  update public.bank_incoming_events
  set
    match_status = 'matched_suggested',
    matched_topup_id = v_topup.id,
    matched_at = now()
  where id = v_event.id;

  return query
  select v_topup.id, v_event.id, 'matched_suggested'::text, v_score;
end;
$$;

revoke all on function public.match_wallet_topups_with_bank_event(uuid) from public;
grant execute on function public.match_wallet_topups_with_bank_event(uuid) to service_role;

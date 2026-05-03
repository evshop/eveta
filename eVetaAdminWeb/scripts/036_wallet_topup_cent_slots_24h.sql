-- 036_wallet_topup_cent_slots_24h.sql
-- Centavos de verificación por cupos globales (misma base en Bs):
--   - Prioridad: 0.01 .. 0.09 (una petición activa por cada centavo).
--   - Si están ocupados: 0.10, luego 0.11 .. 0.99 hasta encontrar libre.
-- Peticiones pendientes: expires_at = now() + 24h. Al vencer sin pagar se ELIMINAN
-- (liberan cupo; cascada borra wallet_topup_qr_sources).
-- match_wallet_topups_with_bank_event: monto exacto, solo topups no vencidos al momento
-- del evento; intenta auto_aprobar al matchear.

alter table public.wallet_topups
  alter column expires_at set default (now() + interval '24 hours');

drop function if exists public.create_wallet_topup_request(numeric);

create or replace function public.create_wallet_topup_request(
  p_amount numeric
)
returns table (
  topup_id uuid,
  reference_code text,
  amount numeric,
  requested_amount numeric,
  verification_delta numeric,
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
  v_base numeric(14,2);
  v_delta numeric(14,2);
  v_amount numeric(14,2);
  v_ref text;
  v_topup_id uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  v_base := round(coalesce(p_amount, 0)::numeric, 2);
  if v_base <= 0 then
    raise exception 'El monto debe ser mayor a 0.';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('wallet_topup_slot:' || v_base::text)
  );

  delete from public.wallet_topups t
  where t.status in ('pending_proof', 'pending_review')
    and t.expires_at <= now();

  select d.delta into v_delta
  from unnest(array[
    0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09
  ]::numeric[]) as d(delta)
  where not exists (
    select 1
    from public.wallet_topups wt
    where wt.status in ('pending_proof', 'pending_review')
      and wt.expires_at > now()
      and round(coalesce(wt.requested_amount, 0)::numeric, 2) = v_base
      and round(coalesce(wt.verification_delta, 0)::numeric, 2) = round(d.delta, 2)
  )
  order by random()
  limit 1;

  if v_delta is null then
    select d.delta into v_delta
    from generate_series(10, 99) gs
    cross join lateral (select round((gs::numeric / 100.0), 2) as delta) d
    where not exists (
      select 1
      from public.wallet_topups wt
      where wt.status in ('pending_proof', 'pending_review')
        and wt.expires_at > now()
        and round(coalesce(wt.requested_amount, 0)::numeric, 2) = v_base
        and round(coalesce(wt.verification_delta, 0)::numeric, 2) = round(d.delta, 2)
    )
    order by d.delta asc
    limit 1;
  end if;

  if v_delta is null then
    raise exception 'Hay demasiadas recargas pendientes para este monto. Intenta más tarde.';
  end if;

  v_delta := round(v_delta::numeric, 2);
  v_amount := round((v_base + v_delta)::numeric, 2);

  perform public.ensure_wallet_account(v_uid);
  v_ref := public.generate_wallet_reference_code();

  insert into public.wallet_topups (
    user_id,
    reference_code,
    amount,
    requested_amount,
    verification_delta,
    status,
    expires_at
  ) values (
    v_uid,
    v_ref,
    v_amount,
    v_base,
    v_delta,
    'pending_proof',
    now() + interval '24 hours'
  )
  returning id into v_topup_id;

  return query
  select
    t.id,
    t.reference_code,
    t.amount,
    t.requested_amount,
    t.verification_delta,
    t.status::text,
    t.expires_at
  from public.wallet_topups t
  where t.id = v_topup_id;
end;
$$;

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
      and v_ev_ts >= created_at - interval '5 minutes'
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

  v_after := public.auto_approve_wallet_topup_by_bank_event(v_topup.id, v_event.id);

  if v_after.status = 'approved' then
    update public.bank_incoming_events
    set
      match_status = 'matched_confirmed',
      matched_topup_id = v_topup.id,
      matched_at = now()
    where id = v_event.id;

    return query
    select v_topup.id, v_event.id, 'matched_confirmed'::text, v_score;
  else
    update public.bank_incoming_events
    set
      match_status = 'matched_suggested',
      matched_topup_id = v_topup.id,
      matched_at = now()
    where id = v_event.id;

    return query
    select v_topup.id, v_event.id, 'matched_suggested'::text, v_score;
  end if;
end;
$$;

revoke all on function public.match_wallet_topups_with_bank_event(uuid) from public;
grant execute on function public.match_wallet_topups_with_bank_event(uuid) to service_role;

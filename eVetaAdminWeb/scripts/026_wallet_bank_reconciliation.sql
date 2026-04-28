-- 026_wallet_bank_reconciliation.sql
-- Ingesta de notificaciones bancarias (Tasker) + matching asistido de recargas.

create table if not exists public.bank_incoming_events (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'tasker_android',
  bank_app text,
  title text,
  body text,
  raw_payload jsonb not null default '{}'::jsonb,
  detected_amount numeric(14,2),
  detected_reference text,
  detected_sender text,
  detected_at timestamptz,
  received_at timestamptz not null default now(),
  match_status text not null default 'unmatched'
    check (match_status in ('unmatched', 'matched_suggested', 'matched_confirmed', 'discarded')),
  matched_topup_id uuid references public.wallet_topups(id) on delete set null,
  matched_at timestamptz
);

create index if not exists idx_bank_events_received
on public.bank_incoming_events(received_at desc);

create index if not exists idx_bank_events_reference
on public.bank_incoming_events(detected_reference);

create index if not exists idx_bank_events_amount
on public.bank_incoming_events(detected_amount);

alter table if exists public.bank_incoming_events enable row level security;

drop policy if exists "bank_events_admin_select" on public.bank_incoming_events;
create policy "bank_events_admin_select"
on public.bank_incoming_events
for select
to authenticated
using (public.profile_is_admin());

drop policy if exists "bank_events_admin_update" on public.bank_incoming_events;
create policy "bank_events_admin_update"
on public.bank_incoming_events
for update
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

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

  -- 1) Match fuerte por referencia exacta.
  if coalesce(trim(v_event.detected_reference), '') <> '' then
    select *
    into v_topup
    from public.wallet_topups
    where reference_code = trim(v_event.detected_reference)
      and status = 'pending_review'
    order by created_at desc
    limit 1;

    if found then
      v_score := 95;
    end if;
  end if;

  -- 2) Fallback por monto + ventana de tiempo.
  if v_topup.id is null and v_event.detected_amount is not null then
    select *
    into v_topup
    from public.wallet_topups
    where status = 'pending_review'
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

create or replace function public.confirm_wallet_topup_match_and_approve(
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
begin
  if not public.profile_is_admin() then
    raise exception 'Sin permisos para aprobar recargas.';
  end if;

  if p_event_id is not null then
    update public.bank_incoming_events
    set
      match_status = 'matched_confirmed',
      matched_topup_id = p_topup_id,
      matched_at = now()
    where id = p_event_id;

    update public.wallet_topups
    set reconciliation_hint = coalesce(reconciliation_hint, '{}'::jsonb)
      || jsonb_build_object(
        'bank_event_id', p_event_id,
        'bank_match_status', 'confirmed',
        'bank_confirmed_at', now()
      )
    where id = p_topup_id;
  end if;

  select * into v_topup from public.approve_wallet_topup(p_topup_id);
  return v_topup;
end;
$$;

revoke all on function public.match_wallet_topups_with_bank_event(uuid) from public;
revoke all on function public.confirm_wallet_topup_match_and_approve(uuid, uuid) from public;

grant execute on function public.match_wallet_topups_with_bank_event(uuid) to service_role;
grant execute on function public.confirm_wallet_topup_match_and_approve(uuid, uuid) to authenticated;

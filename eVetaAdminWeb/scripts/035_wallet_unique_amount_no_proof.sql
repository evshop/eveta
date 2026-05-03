  -- 035_wallet_unique_amount_no_proof.sql
  -- Recargas: monto base + centavos únicos para verificación (Tasker).
  -- - amount: monto a pagar (único, incluye centavos)
  -- - requested_amount: monto real a acreditar (base)
  -- - verification_delta: centavos usados para verificación
  -- - expires_at: 15 minutos
  -- - Aprobación automática sin comprobante (service_role) acreditando requested_amount.

  alter table public.wallet_topups
    add column if not exists requested_amount numeric(14,2),
    add column if not exists verification_delta numeric(14,2);

  -- Nuevas solicitudes duran 15 minutos.
  alter table public.wallet_topups
    alter column expires_at set default (now() + interval '15 minutes');

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

    -- Delta único de 0.01 a 0.95 (paso 0.01)
    v_delta := (floor(random() * 95)::int + 1) / 100.0;
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
      now() + interval '15 minutes'
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

  -- Aprobación automática sin comprobante (solo service_role).
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
    -- Solo service_role (auth.uid() será null normalmente en service_role).
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

    v_credit := round(coalesce(v_topup.requested_amount, v_topup.amount)::numeric, 2);
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

  -- Confirmación admin: ahora puede aprobar aunque no haya comprobante (usa auto approve si no hay proof).
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

    select * into v_topup from public.wallet_topups where id = p_topup_id;
    if not found then
      raise exception 'Recarga no encontrada.';
    end if;

    if coalesce(v_topup.proof_url, '') = '' then
      -- Sin comprobante: aprueba vía función auto (pero desde admin no tenemos service_role).
      -- Por eso, reutilizamos approve_wallet_topup sólo si existe comprobante.
      raise exception 'Esta recarga usa verificación automática por monto. Aprueba desde el webhook/banco o usa service_role.';
    end if;

    return public.approve_wallet_topup(p_topup_id);
  end;
  $$;

  revoke all on function public.auto_approve_wallet_topup_by_bank_event(uuid, uuid) from public;
  grant execute on function public.auto_approve_wallet_topup_by_bank_event(uuid, uuid) to service_role;


-- 025_wallet_business_functions.sql
-- RPC de wallet: topups, revisión admin, balance y débitos de compra.

create or replace function public.generate_wallet_reference_code()
returns text
language sql
stable
as $$
  -- Yape: solo letras/números (sin guiones). Ej: EV4A9C2F01B3
  select 'EV' || upper(substring(md5(random()::text || clock_timestamp()::text), 1, 11));
$$;

create or replace function public.get_wallet_balance()
returns numeric
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_uid uuid;
  v_balance numeric(14,2);
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  perform public.ensure_wallet_account(v_uid);

  select balance into v_balance
  from public.wallet_accounts
  where user_id = v_uid;

  return coalesce(v_balance, 0);
end;
$$;

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
    status
  ) values (
    v_uid,
    v_ref,
    v_amount,
    'pending_proof'
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

create or replace function public.submit_wallet_topup_proof(
  p_topup_id uuid,
  p_proof_url text,
  p_proof_note text default null,
  p_reconciliation_hint jsonb default '{}'::jsonb
)
returns public.wallet_topups
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_topup public.wallet_topups;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  select *
  into v_topup
  from public.wallet_topups
  where id = p_topup_id
    and user_id = v_uid
  for update;

  if not found then
    raise exception 'Recarga no encontrada.';
  end if;

  if v_topup.status not in ('pending_proof', 'pending_review') then
    raise exception 'La recarga ya fue procesada.';
  end if;

  if coalesce(trim(p_proof_url), '') = '' then
    raise exception 'Debes adjuntar comprobante.';
  end if;

  update public.wallet_topups
  set
    proof_url = trim(p_proof_url),
    proof_note = nullif(trim(coalesce(p_proof_note, '')), ''),
    reconciliation_hint = coalesce(p_reconciliation_hint, '{}'::jsonb),
    status = 'pending_review'
  where id = p_topup_id
  returning * into v_topup;

  return v_topup;
end;
$$;

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
  on conflict on constraint uq_wallet_ledger_topup_credit
  do nothing;

  update public.wallet_topups
  set
    status = 'approved',
    approved_by = auth.uid(),
    approved_at = now(),
    rejected_at = null,
    reject_reason = null
  where id = v_topup.id
  returning * into v_topup;

  return v_topup;
end;
$$;

create or replace function public.reject_wallet_topup(
  p_topup_id uuid,
  p_reason text default null
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
    raise exception 'Sin permisos para rechazar recargas.';
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
    raise exception 'La recarga ya fue aprobada.';
  end if;

  update public.wallet_topups
  set
    status = 'rejected',
    approved_by = auth.uid(),
    rejected_at = now(),
    reject_reason = nullif(trim(coalesce(p_reason, '')), '')
  where id = v_topup.id
  returning * into v_topup;

  return v_topup;
end;
$$;

create or replace function public.wallet_debit_for_orders(
  p_order_ids uuid[]
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_total numeric(14,2);
  v_current_balance numeric(14,2);
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;
  if p_order_ids is null or array_length(p_order_ids, 1) is null then
    raise exception 'No hay pedidos para cobrar.';
  end if;

  perform public.ensure_wallet_account(v_uid);

  select coalesce(sum(o.total), 0)
  into v_total
  from public.orders o
  where o.id = any(p_order_ids)
    and o.buyer_id = v_uid
    and o.status = 'pending';

  v_total := round(coalesce(v_total, 0)::numeric, 2);
  if v_total <= 0 then
    raise exception 'No hay montos pendientes en los pedidos.';
  end if;

  select balance
  into v_current_balance
  from public.wallet_accounts
  where user_id = v_uid
  for update;

  if v_current_balance < v_total then
    raise exception 'Saldo insuficiente. Saldo actual: Bs %, requerido: Bs %.',
      trim(to_char(v_current_balance, 'FM999999990.00')),
      trim(to_char(v_total, 'FM999999990.00'));
  end if;

  update public.wallet_accounts
  set balance = balance - v_total
  where user_id = v_uid;

  insert into public.wallet_ledger (
    user_id,
    direction,
    amount,
    source_type,
    source_id,
    meta
  )
  values (
    v_uid,
    'debit',
    v_total,
    'orders_checkout',
    array_to_string(p_order_ids, ','),
    jsonb_build_object('order_ids', p_order_ids)
  );

  update public.orders
  set status = 'paid'
  where id = any(p_order_ids)
    and buyer_id = v_uid
    and status = 'pending';

  return v_total;
end;
$$;

create or replace function public.wallet_buy_event_ticket(
  p_ticket_type_id uuid,
  p_quantity integer default 1
)
returns table (
  charged_amount numeric,
  tickets_created integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_qty int;
  v_ticket_type record;
  v_total numeric(14,2);
  v_balance numeric(14,2);
  v_created int;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  v_qty := greatest(coalesce(p_quantity, 1), 1);

  select *
  into v_ticket_type
  from public.event_ticket_types
  where id = p_ticket_type_id
    and is_active = true
  for update;

  if not found then
    raise exception 'Tipo de entrada no disponible.';
  end if;

  if v_ticket_type.stock is not null and v_ticket_type.sold_count + v_qty > v_ticket_type.stock then
    raise exception 'No hay stock suficiente para esa cantidad.';
  end if;

  v_total := round((v_ticket_type.price * v_qty)::numeric, 2);
  if v_total <= 0 then
    raise exception 'Monto inválido para la compra.';
  end if;

  perform public.ensure_wallet_account(v_uid);

  select balance
  into v_balance
  from public.wallet_accounts
  where user_id = v_uid
  for update;

  if v_balance < v_total then
    raise exception 'Saldo insuficiente. Saldo actual: Bs %, requerido: Bs %.',
      trim(to_char(v_balance, 'FM999999990.00')),
      trim(to_char(v_total, 'FM999999990.00'));
  end if;

  update public.wallet_accounts
  set balance = balance - v_total
  where user_id = v_uid;

  insert into public.wallet_ledger (
    user_id,
    direction,
    amount,
    source_type,
    source_id,
    event_ticket_type_id,
    meta
  )
  values (
    v_uid,
    'debit',
    v_total,
    'event_ticket_purchase',
    p_ticket_type_id::text,
    p_ticket_type_id,
    jsonb_build_object('ticket_type_id', p_ticket_type_id, 'quantity', v_qty)
  );

  v_created := public.test_purchase_event_ticket(p_ticket_type_id, v_qty);

  return query
  select v_total, coalesce(v_created, 0);
end;
$$;

revoke all on function public.generate_wallet_reference_code() from public;
revoke all on function public.get_wallet_balance() from public;
revoke all on function public.create_wallet_topup_request(numeric) from public;
revoke all on function public.submit_wallet_topup_proof(uuid, text, text, jsonb) from public;
revoke all on function public.approve_wallet_topup(uuid) from public;
revoke all on function public.reject_wallet_topup(uuid, text) from public;
revoke all on function public.wallet_debit_for_orders(uuid[]) from public;
revoke all on function public.wallet_buy_event_ticket(uuid, integer) from public;

grant execute on function public.get_wallet_balance() to authenticated;
grant execute on function public.create_wallet_topup_request(numeric) to authenticated;
grant execute on function public.submit_wallet_topup_proof(uuid, text, text, jsonb) to authenticated;
grant execute on function public.approve_wallet_topup(uuid) to authenticated;
grant execute on function public.reject_wallet_topup(uuid, text) to authenticated;
grant execute on function public.wallet_debit_for_orders(uuid[]) to authenticated;
grant execute on function public.wallet_buy_event_ticket(uuid, integer) to authenticated;

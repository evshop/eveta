-- 033_wallet_orders_status_confirmed_fix.sql
-- Fix: wallet_debit_for_orders no debe poner status='paid' porque puede violar
-- orders_status_check en instalaciones donde los estados válidos son
-- pending/confirmed/shipped/delivered/cancelled.

-- 1) Normaliza datos antiguos (si existe algún registro en paid).
update public.orders
set status = 'confirmed'
where status = 'paid';

-- 2) Reemplaza la función para marcar 'confirmed' al cobrar wallet.
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
  set status = 'confirmed'
  where id = any(p_order_ids)
    and buyer_id = v_uid
    and status = 'pending';

  return v_total;
end;
$$;

revoke all on function public.wallet_debit_for_orders(uuid[]) from public;
grant execute on function public.wallet_debit_for_orders(uuid[]) to authenticated;


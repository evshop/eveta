-- 071_portal_delivery_ready_flow.sql
--  * Nuevo flujo: al crear pedido desde Shop, `delivery_status = awaiting_store_ready` (no va al pool).
--  * La tienda (Portal) marca "Listo para recoger" → `awaiting_driver` (visible en pool Delivery).
--  * RPC para rechazar pedido (sin repartidor asignado).
--  * Al marcar `delivered`, alinea `orders.status` a `delivered` para el historial en Shop/Portal.
--
-- Requisitos: 065, 070 aplicados.

begin;

-- 1) Tienda: liberar pedido al pool de reparto
create or replace function public.portal_mark_ready_for_pickup(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  update public.orders o
  set delivery_status = 'awaiting_driver'
  where o.id = p_order_id
    and o.delivery_status = 'awaiting_store_ready'
    and o.status = 'confirmed'
    and o.driver_id is null
    and exists (
      select 1
      from public.profiles_portal pp
      where pp.id = o.seller_id
        and pp.auth_user_id = auth.uid()
        and pp.is_active = true
    );

  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'No se pudo marcar listo para recoger (estado inválido o sin permiso).';
  end if;
end;
$$;

revoke all on function public.portal_mark_ready_for_pickup(uuid) from public;
grant execute on function public.portal_mark_ready_for_pickup(uuid) to authenticated;

-- 2) Tienda: rechazar / cancelar antes de que un repartidor esté asignado
create or replace function public.portal_reject_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  update public.orders o
  set
    status = 'cancelled',
    delivery_status = 'cancelled'
  where o.id = p_order_id
    and o.driver_id is null
    and o.status in ('pending', 'confirmed')
    and o.delivery_status in ('awaiting_store_ready', 'awaiting_driver')
    and exists (
      select 1
      from public.profiles_portal pp
      where pp.id = o.seller_id
        and pp.auth_user_id = auth.uid()
        and pp.is_active = true
    );

  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'No se pudo cancelar el pedido.';
  end if;
end;
$$;

revoke all on function public.portal_reject_order(uuid) from public;
grant execute on function public.portal_reject_order(uuid) to authenticated;

-- 3) Reparto: al entregar, reflejar también en `status` del pedido
create or replace function public.advance_delivery_status(p_order_id uuid, p_next text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  if p_next not in ('picked_up', 'delivered') then
    raise exception 'Estado de entrega no válido.';
  end if;

  if p_next = 'picked_up' then
    update public.orders o
    set delivery_status = 'picked_up'
    where o.id = p_order_id
      and o.driver_id = auth.uid()
      and o.delivery_status = 'driver_assigned';
  elsif p_next = 'delivered' then
    update public.orders o
    set
      delivery_status = 'delivered',
      status = 'delivered'
    where o.id = p_order_id
      and o.driver_id = auth.uid()
      and o.delivery_status = 'picked_up';
  end if;

  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'No se pudo actualizar el pedido.';
  end if;
end;
$$;

revoke all on function public.advance_delivery_status(uuid, text) from public;
grant execute on function public.advance_delivery_status(uuid, text) to authenticated;

commit;

-- 070_delivery_online_pool_rls_buyer_display.sql
-- Objetivo:
--  * Repartidores en línea (`profiles_delivery.is_online`) para disponibilidad.
--  * Pedidos en pool (`delivery_status = awaiting_driver`) visibles solo para repartidores activos y en línea.
--  * Ítems de esos pedidos visibles para el mismo conjunto (lectura).
--  * RPC `has_online_delivery_couriers()` para eVetaShop antes de confirmar entrega.
--  * RPC `accept_delivery_order` / `advance_delivery_status` para la app Delivery.
--  * Columna opcional `orders.buyer_display_name` para mostrar nombre al repartidor sin leer `profiles`.
--
-- Requisitos: 034, 052, 065 (RLS base en orders/order_items).

begin;

-- Si ya existían versiones antiguas de estas RPC con otro tipo de retorno:
drop function if exists public.accept_delivery_order(uuid);
drop function if exists public.advance_delivery_status(uuid, text);
drop function if exists public.advance_delivery_status(uuid);

-- 1) Columna en línea para repartidores
alter table if exists public.profiles_delivery
  add column if not exists is_online boolean not null default false;

comment on column public.profiles_delivery.is_online is
  'Si true, el repartidor está disponible para ver pedidos y la tienda puede ofrecer delivery.';

-- 2) Nombre del comprador en el pedido (rellenado desde eVetaShop al crear)
alter table if exists public.orders
  add column if not exists buyer_display_name text;

comment on column public.orders.buyer_display_name is
  'Etiqueta legible del comprador para la app Delivery (evita SELECT en profiles).';

update public.orders o
set buyer_display_name = coalesce(nullif(trim(p.full_name), ''), nullif(trim(p.email), ''), 'Cliente')
from public.profiles p
where p.id = o.buyer_id
  and (o.buyer_display_name is null or trim(o.buyer_display_name) = '');

-- 3) Helper: repartidor activo y en línea
create or replace function public.is_profiles_delivery_online(p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.profiles_delivery pd
    where pd.auth_user_id = p_uid
      and pd.is_active = true
      and pd.is_online = true
  );
$$;

revoke all on function public.is_profiles_delivery_online(uuid) from public;
grant execute on function public.is_profiles_delivery_online(uuid) to authenticated;

-- 4) Pool de pedidos: SELECT para repartidor en línea
drop policy if exists "orders_select_delivery_pool" on public.orders;
create policy "orders_select_delivery_pool"
on public.orders
for select
to authenticated
using (
  public.is_profiles_delivery_online(auth.uid())
  and delivery_status = 'awaiting_driver'
  and driver_id is null
);

-- 5) Ítems de pedidos en pool (para imágenes / nombres de producto)
drop policy if exists "order_items_select_delivery_pool" on public.order_items;
create policy "order_items_select_delivery_pool"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = public.order_items.order_id
      and o.delivery_status = 'awaiting_driver'
      and o.driver_id is null
      and public.is_profiles_delivery_online(auth.uid())
  )
);

-- 6) Tienda: ¿hay al menos un repartidor en línea?
create or replace function public.has_online_delivery_couriers()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.profiles_delivery pd
    where pd.is_active = true
      and pd.is_online = true
  );
$$;

revoke all on function public.has_online_delivery_couriers() from public;
grant execute on function public.has_online_delivery_couriers() to authenticated;

-- 7) Aceptar pedido (asigna driver_id)
create or replace function public.accept_delivery_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_n int;
begin
  if not public.is_profiles_delivery_online(auth.uid()) then
    raise exception 'Debes estar en línea para aceptar pedidos.';
  end if;

  update public.orders o
  set
    driver_id = auth.uid(),
    delivery_status = 'driver_assigned'
  where o.id = p_order_id
    and o.delivery_status = 'awaiting_driver'
    and o.driver_id is null;

  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'El pedido ya no está disponible.';
  end if;
end;
$$;

revoke all on function public.accept_delivery_order(uuid) from public;
grant execute on function public.accept_delivery_order(uuid) to authenticated;

-- 8) Avanzar estado de entrega (solo el repartidor asignado)
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
    set delivery_status = 'delivered'
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

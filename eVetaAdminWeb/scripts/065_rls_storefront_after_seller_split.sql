-- 065_rls_storefront_after_seller_split.sql
-- Tras 064 (`products.seller_id` ya no es `profiles.id`):
--  * Permite que la app eVetaShop (anon/authenticated) lea tiendas activas
--    desde `profiles_portal` (catálogo, búsqueda, perfil de tienda).
--  * Refuerza policies de `orders` / `order_items` para que el dueño Portal
--    pueda ver sus pedidos sin depender de `profiles`.
--
-- Requisitos: scripts 034, 052, 061, 064 aplicados.

begin;

-- 1) Lectura pública de tiendas activas en profiles_portal.
alter table if exists public.profiles_portal enable row level security;

drop policy if exists "profiles_portal_storefront_read" on public.profiles_portal;
create policy "profiles_portal_storefront_read"
on public.profiles_portal
for select
to anon, authenticated
using (
  is_active = true
  and coalesce(is_seller, false) = true
);

-- 2) RLS de orders.
alter table if exists public.orders enable row level security;

drop policy if exists "orders_select_buyer_seller_admin" on public.orders;
create policy "orders_select_buyer_seller_admin"
on public.orders
for select
to authenticated
using (
  buyer_id = auth.uid()
  or exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.orders.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or driver_id = auth.uid()
  or public.is_profiles_portal_admin(auth.uid())
);

drop policy if exists "orders_insert_buyer" on public.orders;
create policy "orders_insert_buyer"
on public.orders
for insert
to authenticated
with check (buyer_id = auth.uid());

drop policy if exists "orders_update_seller_admin" on public.orders;
create policy "orders_update_seller_admin"
on public.orders
for update
to authenticated
using (
  exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.orders.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or driver_id = auth.uid()
  or public.is_profiles_portal_admin(auth.uid())
)
with check (
  exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.orders.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or driver_id = auth.uid()
  or public.is_profiles_portal_admin(auth.uid())
);

-- 3) RLS de order_items.
alter table if exists public.order_items enable row level security;

drop policy if exists "order_items_select_buyer_seller_admin" on public.order_items;
create policy "order_items_select_buyer_seller_admin"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1 from public.orders o
    where o.id = public.order_items.order_id
      and (
        o.buyer_id = auth.uid()
        or o.driver_id = auth.uid()
      )
  )
  or exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.order_items.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or public.is_profiles_portal_admin(auth.uid())
);

drop policy if exists "order_items_insert_buyer" on public.order_items;
create policy "order_items_insert_buyer"
on public.order_items
for insert
to authenticated
with check (
  exists (
    select 1 from public.orders o
    where o.id = public.order_items.order_id
      and o.buyer_id = auth.uid()
  )
);

drop policy if exists "order_items_update_seller_admin" on public.order_items;
create policy "order_items_update_seller_admin"
on public.order_items
for update
to authenticated
using (
  exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.order_items.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or public.is_profiles_portal_admin(auth.uid())
)
with check (
  exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.order_items.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or public.is_profiles_portal_admin(auth.uid())
);

commit;

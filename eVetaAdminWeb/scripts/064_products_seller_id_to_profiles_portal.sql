-- 064_products_seller_id_to_profiles_portal.sql
-- Big bang: products/orders/order_items.seller_id pasa a referenciar profiles_portal(id).
-- Tras este script, `profiles` queda libre de roles tienda/portal/delivery.
--
-- Backfill cubre dos casos:
--   a) seller_id = profiles_portal.legacy_profile_id (cuentas migradas desde profiles legacy)
--   b) seller_id = profiles_portal.auth_user_id      (flujos nuevos que usaban auth.uid())
--
-- Requisitos:
--   * 034 (split tablas) aplicado
--   * 059 (limpieza de columnas legacy en profiles) aplicado
--   * 061 (RLS admin sin recursión) aplicado

begin;

-- 0) Quitar PRIMERO las FKs hacia public.profiles sobre seller_id.
--    Si no, cualquier UPDATE que ponga profiles_portal.id en seller_id falla con 23503
--    (p. ej. products_seller_id_fkey).
alter table if exists public.products drop constraint if exists products_seller_id_fkey;
alter table if exists public.orders drop constraint if exists orders_seller_id_fkey;
alter table if exists public.order_items drop constraint if exists order_items_seller_id_fkey;

do $$
declare
  r record;
begin
  for r in
    select c.conname, c.conrelid::regclass::text as table_name
    from pg_constraint c
    where c.contype = 'f'
      and c.conrelid::regclass::text in (
        'public.products', 'public.orders', 'public.order_items'
      )
      and c.confrelid::regclass::text = 'public.profiles'
      and array_to_string(c.conkey, ',') = array_to_string(
        array(
          select attnum from pg_attribute
          where attrelid = c.conrelid and attname = 'seller_id'
        ), ','
      )
  loop
    execute format('alter table %s drop constraint if exists %I', r.table_name, r.conname);
  end loop;
end $$;

-- 1) Backfill products.seller_id -> profiles_portal.id
update public.products p
set seller_id = pp.id
from public.profiles_portal pp
where pp.legacy_profile_id is not null
  and p.seller_id = pp.legacy_profile_id;

update public.products p
set seller_id = pp.id
from public.profiles_portal pp
where pp.auth_user_id is not null
  and p.seller_id = pp.auth_user_id
  and not exists (
    select 1 from public.profiles_portal x where x.id = p.seller_id
  );

-- 2) Backfill orders.seller_id -> profiles_portal.id
update public.orders o
set seller_id = pp.id
from public.profiles_portal pp
where pp.legacy_profile_id is not null
  and o.seller_id = pp.legacy_profile_id;

update public.orders o
set seller_id = pp.id
from public.profiles_portal pp
where pp.auth_user_id is not null
  and o.seller_id = pp.auth_user_id
  and not exists (
    select 1 from public.profiles_portal x where x.id = o.seller_id
  );

-- 3) Backfill order_items.seller_id -> profiles_portal.id
update public.order_items oi
set seller_id = pp.id
from public.profiles_portal pp
where pp.legacy_profile_id is not null
  and oi.seller_id = pp.legacy_profile_id;

update public.order_items oi
set seller_id = pp.id
from public.profiles_portal pp
where pp.auth_user_id is not null
  and oi.seller_id = pp.auth_user_id
  and not exists (
    select 1 from public.profiles_portal x where x.id = oi.seller_id
  );

-- 4) Crear FKs hacia profiles_portal(id). Idempotente.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'products_seller_id_profiles_portal_fkey'
  ) then
    alter table public.products
      add constraint products_seller_id_profiles_portal_fkey
      foreign key (seller_id) references public.profiles_portal(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'orders_seller_id_profiles_portal_fkey'
  ) then
    alter table public.orders
      add constraint orders_seller_id_profiles_portal_fkey
      foreign key (seller_id) references public.profiles_portal(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'order_items_seller_id_profiles_portal_fkey'
  ) then
    alter table public.order_items
      add constraint order_items_seller_id_profiles_portal_fkey
      foreign key (seller_id) references public.profiles_portal(id) on delete cascade;
  end if;
end $$;

-- 5) RLS de products: dueño = profiles_portal.auth_user_id; admin via is_profiles_portal_admin.
alter table if exists public.products enable row level security;

drop policy if exists "products_select_owner_or_admin" on public.products;
drop policy if exists "products_insert_owner_or_admin" on public.products;
drop policy if exists "products_update_owner_or_admin" on public.products;
drop policy if exists "products_delete_owner_or_admin" on public.products;
drop policy if exists "products_select_public" on public.products;

create policy "products_select_public"
on public.products
for select
to anon, authenticated
using (true);

create policy "products_insert_owner_or_admin"
on public.products
for insert
to authenticated
with check (
  exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.products.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or public.is_profiles_portal_admin(auth.uid())
);

create policy "products_update_owner_or_admin"
on public.products
for update
to authenticated
using (
  exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.products.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or public.is_profiles_portal_admin(auth.uid())
)
with check (
  exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.products.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or public.is_profiles_portal_admin(auth.uid())
);

create policy "products_delete_owner_or_admin"
on public.products
for delete
to authenticated
using (
  exists (
    select 1 from public.profiles_portal pp
    where pp.id = public.products.seller_id
      and pp.auth_user_id = auth.uid()
      and pp.is_active = true
  )
  or public.is_profiles_portal_admin(auth.uid())
);

-- 6) Cleanup: borra filas residuales en profiles para usuarios que ahora viven solo en
--    profiles_portal o profiles_delivery. Si la fila tiene historial como buyer (orders.buyer_id),
--    no se elimina y se emite un NOTICE.
do $$
declare
  r record;
begin
  for r in
    select p.id
    from public.profiles p
    where p.id in (
      select pp.auth_user_id from public.profiles_portal pp where pp.auth_user_id is not null
      union
      select pd.auth_user_id from public.profiles_delivery pd where pd.auth_user_id is not null
    )
  loop
    begin
      delete from public.profiles where id = r.id;
    exception
      when foreign_key_violation then
        raise notice '064: profile % conserva referencias (orders.buyer_id u otra tabla); fila no eliminada.', r.id;
    end;
  end loop;
end $$;

commit;

-- Verificación
select
  (select count(*) from public.products
     where seller_id is not null
       and not exists (select 1 from public.profiles_portal pp where pp.id = public.products.seller_id)
  ) as products_orphan_seller,
  (select count(*) from public.orders
     where seller_id is not null
       and not exists (select 1 from public.profiles_portal pp where pp.id = public.orders.seller_id)
  ) as orders_orphan_seller,
  (select count(*) from public.order_items
     where seller_id is not null
       and not exists (select 1 from public.profiles_portal pp where pp.id = public.order_items.seller_id)
  ) as order_items_orphan_seller,
  (select count(*) from public.profiles p
     where p.id in (
       select pp.auth_user_id from public.profiles_portal pp where pp.auth_user_id is not null
       union
       select pd.auth_user_id from public.profiles_delivery pd where pd.auth_user_id is not null
     )
  ) as profiles_with_portal_or_delivery_uid;

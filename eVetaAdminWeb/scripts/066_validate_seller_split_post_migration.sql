-- 066_validate_seller_split_post_migration.sql
-- Checklist de verificación tras 064 + 065. Ejecutar en Supabase SQL Editor.
-- Salida esperada: cada conteo en 0 (excepto los que están explícitamente marcados).

-- 1) Productos huérfanos (seller_id no existe en profiles_portal).
select 'products_orphan' as check_name,
       count(*)         as offending_rows
from public.products p
where p.seller_id is not null
  and not exists (
    select 1 from public.profiles_portal pp where pp.id = p.seller_id
  );

-- 2) Pedidos huérfanos.
select 'orders_orphan' as check_name,
       count(*)        as offending_rows
from public.orders o
where o.seller_id is not null
  and not exists (
    select 1 from public.profiles_portal pp where pp.id = o.seller_id
  );

-- 3) order_items huérfanos.
select 'order_items_orphan' as check_name,
       count(*)             as offending_rows
from public.order_items oi
where oi.seller_id is not null
  and not exists (
    select 1 from public.profiles_portal pp where pp.id = oi.seller_id
  );

-- 4) `profiles` no debe contener cuentas Portal/Delivery (cero filas con esos auth_user_id).
select 'profiles_with_portal_or_delivery_uid' as check_name,
       count(*)                                as offending_rows
from public.profiles p
where p.id in (
  select pp.auth_user_id from public.profiles_portal pp where pp.auth_user_id is not null
  union
  select pd.auth_user_id from public.profiles_delivery pd where pd.auth_user_id is not null
);

-- 5) Columnas legacy de Portal/Delivery deben estar ausentes en profiles.
select 'profiles_legacy_columns_present' as check_name,
       count(*)                          as offending_rows
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name in (
    'is_admin','is_seller','is_delivery',
    'shop_name','shop_description','shop_logo_url','shop_banner_url',
    'is_partner_verified','partner_display_order',
    'shop_border_color','shop_address','shop_lat','shop_lng','shop_location_photos'
  );

-- 6) FKs vigentes hacia profiles_portal en products/orders/order_items.
select 'fks_to_profiles_portal_present' as check_name,
       count(*)                          as observed_rows
from pg_constraint c
where c.contype = 'f'
  and c.conrelid::regclass::text in ('public.products', 'public.orders', 'public.order_items')
  and c.confrelid::regclass::text = 'public.profiles_portal';
-- Esperado: 3.

-- 7) Confirma que no quedan FKs hacia public.profiles desde productos/pedidos/items por seller_id.
select 'fks_seller_to_profiles_remaining' as check_name,
       count(*)                            as offending_rows
from pg_constraint c
where c.contype = 'f'
  and c.conrelid::regclass::text in ('public.products', 'public.orders', 'public.order_items')
  and c.confrelid::regclass::text = 'public.profiles'
  and array_to_string(c.conkey, ',') = array_to_string(
    array(
      select attnum from pg_attribute
      where attrelid = c.conrelid and attname = 'seller_id'
    ), ','
  );

-- 8) profile_is_admin RPC no depende de `profiles` (debe usar profiles_portal).
select 'profile_is_admin_uses_profiles_table' as check_name,
       count(*)                                as offending_rows
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'profile_is_admin'
  and pg_get_functiondef(p.oid) ilike '%from public.profiles %'
  and pg_get_functiondef(p.oid) not ilike '%profiles_portal%';

-- 9) Policies clave esperadas (productos, profiles_portal storefront, orders, order_items).
select 'expected_policies_present' as check_name,
       count(*)                    as observed_rows
from pg_policies
where schemaname = 'public'
  and policyname in (
    'products_select_public',
    'products_insert_owner_or_admin',
    'products_update_owner_or_admin',
    'products_delete_owner_or_admin',
    'profiles_portal_storefront_read',
    'orders_select_buyer_seller_admin',
    'orders_update_seller_admin',
    'order_items_select_buyer_seller_admin',
    'order_items_update_seller_admin'
  );
-- Esperado: 9.

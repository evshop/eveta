-- 057_hard_reset_all_apps_data.sql
-- RESET TOTAL de datos de negocio para arrancar limpio con separación por app.
--
-- Qué limpia:
-- - Shop: profiles
-- - Portal/Admin: profiles_portal
-- - Delivery: profiles_delivery
-- - Catálogo/pedidos: products, order_items, orders
-- - Authentication: auth.users (todas las cuentas de login; luego créalas de nuevo en Dashboard)
--
-- Si quieres conservar usuarios de Auth, comenta el paso 3) (delete auth.users).
--
-- Importante:
-- - NO elimina estructura (tablas, funciones, policies).
-- - Este script es destructivo e irreversible.
-- - Ejecutar en entorno correcto (no producción accidentalmente).

begin;

-- 1) Limpiar tablas dependientes de pedidos/productos.
truncate table public.order_items restart identity cascade;
truncate table public.orders restart identity cascade;
truncate table public.products restart identity cascade;

-- 2) Limpiar perfiles por app.
truncate table public.profiles_portal restart identity cascade;
truncate table public.profiles_delivery restart identity cascade;
truncate table public.profiles restart identity cascade;

-- 2b) Storage: filas en storage.objects suelen tener FK a auth.users (owner / owner_id).
--     Sin esto, DELETE FROM auth.users falla y en el dashboard siguen todos los usuarios
--     (email y Google OAuth siguen en auth.users + auth.identities).
do $storage_unlock$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'storage'
      and table_name = 'objects'
      and column_name = 'owner_id'
  ) then
    execute 'update storage.objects set owner_id = null where owner_id is not null';
  end if;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'storage'
      and table_name = 'objects'
      and column_name = 'owner'
  ) then
    execute 'update storage.objects set owner = null where owner is not null';
  end if;
end
$storage_unlock$;

-- 3) Borrar todas las cuentas de Supabase Auth (email, Google, etc.).
--    Revisa en el panel "Messages" del SQL Editor la línea NOTICE con filas borradas.
do $wipe_auth$
declare
  n bigint;
begin
  delete from auth.users;
  get diagnostics n = row_count;
  raise notice '057: filas borradas en auth.users = %', n;
end
$wipe_auth$;

commit;

-- Verificación rápida
select
  (select count(*) from auth.users) as auth_users_rows,
  (select count(*) from public.profiles) as profiles_rows,
  (select count(*) from public.profiles_portal) as profiles_portal_rows,
  (select count(*) from public.profiles_delivery) as profiles_delivery_rows,
  (select count(*) from public.products) as products_rows,
  (select count(*) from public.orders) as orders_rows,
  (select count(*) from public.order_items) as order_items_rows;


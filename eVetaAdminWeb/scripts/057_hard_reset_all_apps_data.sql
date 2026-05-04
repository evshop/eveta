-- 057_hard_reset_all_apps_data.sql
-- RESET TOTAL de datos de negocio para arrancar limpio con separación por app.
--
-- Qué limpia:
-- - Shop: profiles
-- - Portal/Admin: profiles_portal
-- - Delivery: profiles_delivery
-- - Catálogo/pedidos: products, order_items, orders
-- - Opcional: auth.users (comentado; usar solo si quieres borrar logins también)
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

-- 3) Si también quieres borrar TODAS las cuentas de login de Supabase Auth,
-- descomenta este bloque (dejar comentado por defecto para evitar lockout).
--
-- do $$
-- begin
--   delete from auth.users;
-- end $$;

commit;

-- Verificación rápida
select
  (select count(*) from public.profiles) as profiles_rows,
  (select count(*) from public.profiles_portal) as profiles_portal_rows,
  (select count(*) from public.profiles_delivery) as profiles_delivery_rows,
  (select count(*) from public.products) as products_rows,
  (select count(*) from public.orders) as orders_rows,
  (select count(*) from public.order_items) as order_items_rows;


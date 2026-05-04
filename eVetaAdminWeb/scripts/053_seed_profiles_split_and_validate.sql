-- 053_seed_profiles_split_and_validate.sql
-- Ejecuta los seeds una vez aplicados 034 + 051 + 052.
-- Pobla `profiles_portal` y `profiles_delivery` desde `profiles` legacy
-- conservando `legacy_profile_id` para mantener compatibilidad con
-- referencias existentes (orders.seller_id, products.seller_id, etc.).
--
-- Estos seeds NO vinculan auth_user_id automáticamente. La vinculación se hace
-- en el primer login de cada usuario:
--   - Portal/Admin: ensure_portal_membership_for_current_user() (script 051)
--   - Delivery: el repartidor inicia sesión y se actualiza la fila por email.

-- 1) Sembrado idempotente.
select public.seed_portal_profiles_from_legacy() as inserted_portal;
select public.seed_delivery_profiles_from_legacy() as inserted_delivery;

-- 2) Validación rápida de RLS / cobertura.
--    Conteos esperados después del seed (ajusta según tu data real):
--      * total sellers en profiles  ~= total filas en profiles_portal
--      * total deliveries en profiles ~= total filas en profiles_delivery
do $$
declare
  v_legacy_sellers integer;
  v_portal integer;
  v_legacy_deliveries integer;
  v_delivery integer;
begin
  select count(*) into v_legacy_sellers
  from public.profiles
  where coalesce(is_seller, false) = true
    and coalesce(trim(email), '') <> '';

  select count(*) into v_portal from public.profiles_portal;

  select count(*) into v_legacy_deliveries
  from public.profiles
  where coalesce(is_delivery, false) = true
    and coalesce(trim(email), '') <> '';

  select count(*) into v_delivery from public.profiles_delivery;

  raise notice 'profiles_portal: % filas (legacy sellers: %)', v_portal, v_legacy_sellers;
  raise notice 'profiles_delivery: % filas (legacy deliveries: %)', v_delivery, v_legacy_deliveries;
end $$;

-- 3) Validación de policies clave: deben existir self-policies y admin-policies.
do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from pg_policies
  where schemaname = 'public'
    and tablename in ('profiles_portal', 'profiles_delivery')
    and policyname in (
      'profiles_portal_admin_all',
      'profiles_portal_self_select',
      'profiles_portal_self_update',
      'profiles_portal_self_insert',
      'profiles_delivery_admin_all',
      'profiles_delivery_self_select',
      'profiles_delivery_self_update'
    );
  if v_count < 7 then
    raise warning
      'Faltan políticas RLS para perfiles separados (esperadas 7, encontradas %). Revisa 034 y 052.',
      v_count;
  else
    raise notice 'RLS OK: 7 políticas presentes para profiles_portal/profiles_delivery.';
  end if;
end $$;

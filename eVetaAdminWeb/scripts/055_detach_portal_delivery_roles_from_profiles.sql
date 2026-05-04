-- 055_detach_portal_delivery_roles_from_profiles.sql
-- Limpieza de transición: saca roles Portal/Delivery de `profiles` legacy
-- para que la separación por app sea efectiva a nivel de datos.
--
-- Importante:
-- - NO elimina filas de `profiles` para no romper referencias legacy
--   (`products.seller_id`, `order_items.seller_id`, etc.).
-- - Solo apaga flags de rol en `profiles` cuando esa cuenta ya existe en
--   `profiles_portal` o `profiles_delivery`.
--
-- Orden recomendado:
--   034 -> 051 -> 052 -> 053 -> 054 -> 055

do $$
declare
  v_updated integer := 0;
begin
  with target_ids as (
    select pp.legacy_profile_id as id
    from public.profiles_portal pp
    where pp.legacy_profile_id is not null
    union
    select pd.legacy_profile_id as id
    from public.profiles_delivery pd
    where pd.legacy_profile_id is not null
  )
  update public.profiles p
  set
    is_seller = false,
    is_admin = false,
    is_delivery = false,
    updated_at = now()
  from target_ids t
  where p.id = t.id
    and (
      coalesce(p.is_seller, false)
      or coalesce(p.is_admin, false)
      or coalesce(p.is_delivery, false)
    );

  get diagnostics v_updated = row_count;
  raise notice 'profiles legacy roles limpiados: % filas', v_updated;
end $$;

-- Verificación rápida
select
  count(*) filter (
    where coalesce(is_seller, false) or coalesce(is_admin, false) or coalesce(is_delivery, false)
  ) as profiles_with_legacy_roles
from public.profiles;


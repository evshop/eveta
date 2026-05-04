-- 056_remove_portal_delivery_shop_data_from_profiles.sql
-- Limpieza fuerte solicitada:
--   - En `profiles` solo deben quedar datos de usuarios eVetaShop.
--   - Si una fila legacy ya está migrada a `profiles_portal` o `profiles_delivery`,
--     se limpian campos de Portal/tienda en `profiles`.
--
-- Este script NO borra filas de `profiles` (evita romper FKs históricas).
-- Solo limpia columnas de negocio Portal/Delivery en filas migradas.
--
-- Orden recomendado:
--   034 -> 051 -> 052 -> 053 -> 054 -> 055 -> 056

do $$
declare
  v_updated integer := 0;
begin
  with migrated_ids as (
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
    -- Flags legacy ya limpiados en 055, reforzamos aquí.
    is_seller = false,
    is_admin = false,
    is_delivery = false,
    is_partner_verified = false,
    partner_display_order = 0,

    -- Datos de tienda/portal fuera de `profiles`.
    shop_name = null,
    shop_description = null,
    shop_logo_url = null,
    shop_banner_url = null,
    shop_address = null,
    shop_lat = null,
    shop_lng = null,
    shop_location_photos = '[]'::jsonb,

    updated_at = now()
  from migrated_ids m
  where p.id = m.id;

  get diagnostics v_updated = row_count;
  raise notice 'profiles limpiados (campos tienda/portal): % filas', v_updated;
end $$;

-- Verificación rápida: cuántas filas migradas aún conservan datos de tienda.
with migrated_ids as (
  select legacy_profile_id as id from public.profiles_portal where legacy_profile_id is not null
  union
  select legacy_profile_id as id from public.profiles_delivery where legacy_profile_id is not null
)
select count(*) as migrated_profiles_with_shop_data
from public.profiles p
join migrated_ids m on m.id = p.id
where
  coalesce(trim(p.shop_name), '') <> ''
  or coalesce(trim(p.shop_description), '') <> ''
  or coalesce(trim(p.shop_logo_url), '') <> ''
  or coalesce(trim(p.shop_banner_url), '') <> ''
  or coalesce(trim(p.shop_address), '') <> ''
  or p.shop_lat is not null
  or p.shop_lng is not null
  or jsonb_array_length(coalesce(p.shop_location_photos, '[]'::jsonb)) > 0;


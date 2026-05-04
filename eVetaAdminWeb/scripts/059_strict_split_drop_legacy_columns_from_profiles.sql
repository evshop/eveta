-- 059_strict_split_drop_legacy_columns_from_profiles.sql
-- Modo ESTRICTO solicitado:
--   `profiles` queda solo para eVetaShop (sin columnas legacy de Portal/Delivery).
--
-- Este script:
-- 1) Reescribe funciones de acceso para que NO dependan de `profiles`.
-- 2) Elimina columnas legacy de Portal/Delivery en `profiles`.
--
-- ADVERTENCIA:
-- - Es destructivo a nivel de esquema.
-- - Si existen consultas antiguas que lean estas columnas en `profiles`,
--   deberán migrarse a `profiles_portal` / `profiles_delivery`.

begin;

-- 1) Admin role: desde Portal únicamente (ya no desde profiles).
create or replace function public.profile_is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (
      select pp.is_admin
      from public.profiles_portal pp
      where pp.auth_user_id = auth.uid()
        and pp.is_active = true
      limit 1
    ),
    false
  );
$$;

revoke all on function public.profile_is_admin() from public;
grant execute on function public.profile_is_admin() to authenticated;

-- 2) Autolink Portal SIN fallback a `profiles`.
create or replace function public.ensure_portal_membership_for_current_user()
returns public.profiles_portal
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_email text;
  v_row public.profiles_portal;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  select lower(trim(u.email))
  into v_email
  from auth.users u
  where u.id = v_uid;

  if v_email is null or v_email = '' then
    raise exception 'No se pudo resolver email del usuario.';
  end if;

  select * into v_row
  from public.profiles_portal
  where auth_user_id = v_uid
  limit 1;
  if found then
    return v_row;
  end if;

  update public.profiles_portal
  set auth_user_id = v_uid
  where email = v_email
    and auth_user_id is null
  returning * into v_row;
  if found then
    return v_row;
  end if;

  raise exception 'Tu cuenta no está vinculada a Portal.';
end;
$$;

revoke all on function public.ensure_portal_membership_for_current_user() from public;
grant execute on function public.ensure_portal_membership_for_current_user() to authenticated;

-- 3) Autolink Delivery SIN fallback a `profiles`.
create or replace function public.ensure_delivery_membership_for_current_user()
returns public.profiles_delivery
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_email text;
  v_row public.profiles_delivery;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  select lower(trim(u.email))
  into v_email
  from auth.users u
  where u.id = v_uid;

  if v_email is null or v_email = '' then
    raise exception 'No se pudo resolver email del usuario.';
  end if;

  select * into v_row
  from public.profiles_delivery
  where auth_user_id = v_uid
  limit 1;
  if found then
    return v_row;
  end if;

  update public.profiles_delivery
  set auth_user_id = v_uid
  where email = v_email
    and auth_user_id is null
  returning * into v_row;
  if found then
    return v_row;
  end if;

  raise exception 'Tu cuenta no está vinculada a Delivery.';
end;
$$;

revoke all on function public.ensure_delivery_membership_for_current_user() from public;
grant execute on function public.ensure_delivery_membership_for_current_user() to authenticated;

-- 4) Seeds legacy deshabilitados (ya no existe fuente por roles en `profiles`).
create or replace function public.seed_portal_profiles_from_legacy()
returns integer
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'seed_portal_profiles_from_legacy deshabilitado: esquema estricto sin roles Portal en profiles.';
end;
$$;

create or replace function public.seed_delivery_profiles_from_legacy()
returns integer
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'seed_delivery_profiles_from_legacy deshabilitado: esquema estricto sin roles Delivery en profiles.';
end;
$$;

revoke all on function public.seed_portal_profiles_from_legacy() from public;
revoke all on function public.seed_delivery_profiles_from_legacy() from public;
grant execute on function public.seed_portal_profiles_from_legacy() to authenticated;
grant execute on function public.seed_delivery_profiles_from_legacy() to authenticated;

-- 5) Quitar columnas legacy de Portal/Delivery en profiles.
alter table public.profiles
  drop column if exists is_admin cascade,
  drop column if exists is_seller cascade,
  drop column if exists is_delivery cascade,
  drop column if exists shop_name cascade,
  drop column if exists shop_description cascade,
  drop column if exists shop_logo_url cascade,
  drop column if exists shop_banner_url cascade,
  drop column if exists is_partner_verified cascade,
  drop column if exists partner_display_order cascade,
  drop column if exists shop_border_color cascade,
  drop column if exists shop_address cascade,
  drop column if exists shop_lat cascade,
  drop column if exists shop_lng cascade,
  drop column if exists shop_location_photos cascade;

commit;

-- Verificación: estas columnas ya no deben existir en profiles.
select column_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name in (
    'is_admin','is_seller','is_delivery',
    'shop_name','shop_description','shop_logo_url','shop_banner_url',
    'is_partner_verified','partner_display_order',
    'shop_border_color','shop_address','shop_lat','shop_lng','shop_location_photos'
  )
order by column_name;


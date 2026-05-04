-- 052_profiles_split_self_rls_and_shop_columns.sql
-- Cierra el set de cambios para "Separar usuarios por app":
--   1) Agrega columnas faltantes en profiles_portal (ubicación + fotos del local)
--      para que Portal pueda guardar todos los datos sin depender de profiles.
--   2) Refuerza RLS:
--      - profiles_portal: self UPDATE/INSERT por auth_user_id (vendedor edita su tienda)
--      - profiles_delivery: self UPDATE por auth_user_id (datos básicos del repartidor)
--   3) Las políticas admin existentes (profiles_*_admin_all) siguen vigentes desde 034.

-- 1) Columnas de ubicación/fotos en profiles_portal (alineado con profiles).
alter table public.profiles_portal
  add column if not exists shop_border_color text,
  add column if not exists shop_address text,
  add column if not exists shop_lat numeric(9,6),
  add column if not exists shop_lng numeric(9,6),
  add column if not exists shop_location_photos jsonb not null default '[]'::jsonb;

alter table public.profiles_portal
  drop constraint if exists profiles_portal_shop_lat_range_chk;
alter table public.profiles_portal
  add constraint profiles_portal_shop_lat_range_chk
  check (shop_lat is null or (shop_lat >= -90 and shop_lat <= 90));

alter table public.profiles_portal
  drop constraint if exists profiles_portal_shop_lng_range_chk;
alter table public.profiles_portal
  add constraint profiles_portal_shop_lng_range_chk
  check (shop_lng is null or (shop_lng >= -180 and shop_lng <= 180));

alter table public.profiles_portal
  drop constraint if exists profiles_portal_shop_location_photos_max3_chk;
alter table public.profiles_portal
  add constraint profiles_portal_shop_location_photos_max3_chk
  check (
    jsonb_typeof(shop_location_photos) = 'array'
    and jsonb_array_length(shop_location_photos) <= 3
  );

comment on column public.profiles_portal.shop_address is
  'Dirección física de la tienda para recojo (cuenta Portal).';
comment on column public.profiles_portal.shop_lat is
  'Latitud de la ubicación única de la tienda (cuenta Portal).';
comment on column public.profiles_portal.shop_lng is
  'Longitud de la ubicación única de la tienda (cuenta Portal).';
comment on column public.profiles_portal.shop_location_photos is
  'Fotos del frente/interior del local (max 3 URLs) para Delivery.';

-- 2) RLS self-update / self-insert en profiles_portal.
alter table if exists public.profiles_portal enable row level security;

drop policy if exists "profiles_portal_self_update" on public.profiles_portal;
create policy "profiles_portal_self_update"
on public.profiles_portal
for update
to authenticated
using (auth_user_id = auth.uid() and is_active = true)
with check (auth_user_id = auth.uid() and is_active = true);

drop policy if exists "profiles_portal_self_insert" on public.profiles_portal;
create policy "profiles_portal_self_insert"
on public.profiles_portal
for insert
to authenticated
with check (auth_user_id = auth.uid());

-- 3) RLS self-update en profiles_delivery (datos del repartidor sobre su propia fila).
alter table if exists public.profiles_delivery enable row level security;

drop policy if exists "profiles_delivery_self_update" on public.profiles_delivery;
create policy "profiles_delivery_self_update"
on public.profiles_delivery
for update
to authenticated
using (auth_user_id = auth.uid() and is_active = true)
with check (auth_user_id = auth.uid() and is_active = true);

-- 049_store_single_location.sql
-- Una sola ubicación por tienda (perfil vendedor) para logística de delivery.
-- Se usa como punto de recojo (pickup) al crear pedidos.

alter table public.profiles
  add column if not exists shop_address text,
  add column if not exists shop_lat numeric(9,6),
  add column if not exists shop_lng numeric(9,6);

alter table public.profiles
  drop constraint if exists profiles_shop_lat_range_chk;
alter table public.profiles
  drop constraint if exists profiles_shop_lng_range_chk;
alter table public.profiles
  add constraint profiles_shop_lat_range_chk
  check (shop_lat is null or (shop_lat >= -90 and shop_lat <= 90));
alter table public.profiles
  add constraint profiles_shop_lng_range_chk
  check (shop_lng is null or (shop_lng >= -180 and shop_lng <= 180));

comment on column public.profiles.shop_address is
  'Dirección física de la tienda para recojo.';
comment on column public.profiles.shop_lat is
  'Latitud de la ubicación única de la tienda.';
comment on column public.profiles.shop_lng is
  'Longitud de la ubicación única de la tienda.';

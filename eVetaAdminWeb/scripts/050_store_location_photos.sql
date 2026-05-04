-- 050_store_location_photos.sql
-- Fotos de referencia del local de recojo (máximo 3 por tienda).

alter table public.profiles
  add column if not exists shop_location_photos jsonb not null default '[]'::jsonb;

alter table public.profiles
  drop constraint if exists profiles_shop_location_photos_max3_chk;
alter table public.profiles
  add constraint profiles_shop_location_photos_max3_chk
  check (
    jsonb_typeof(shop_location_photos) = 'array'
    and jsonb_array_length(shop_location_photos) <= 3
  );

comment on column public.profiles.shop_location_photos is
  'Fotos de referencia del frente/interior del local para facilitar recojo en delivery (max 3 URLs).';

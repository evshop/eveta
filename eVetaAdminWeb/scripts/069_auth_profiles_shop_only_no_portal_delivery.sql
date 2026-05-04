-- 069_auth_profiles_shop_only_no_portal_delivery.sql
-- Problema: al crear vendedor/repartidor desde Admin (Edge Function), un trigger
-- habitual en `auth.users` inserta una fila en `public.profiles` para TODO nuevo usuario.
-- En el split estricto, esas cuentas NO deben existir en `profiles`.
--
-- Qué hace este script:
-- 1) Limpia filas `profiles` ya huérfanas de cuentas marcadas como Portal/Delivery en metadata.
-- 2) Reemplaza `public.handle_new_user()` para NO insertar en `profiles` cuando
--    `raw_user_meta_data->>'app'` sea portal_seller / delivery / portal.
-- 3) Recrea el trigger `on_auth_user_created` en `auth.users` (nombre habitual en plantillas Supabase).
--
-- Si tu proyecto usa otro nombre de trigger/función, en SQL Editor ejecutá antes:
--   select tgname, p.proname
--   from pg_trigger t
--   join pg_proc p on p.oid = t.tgfoid
--   join pg_class c on c.oid = t.tgrelid
--   join pg_namespace n on n.oid = c.relnamespace
--   where n.nspname = 'auth' and c.relname = 'users' and not t.tgisinternal;
--
-- Ajustá el INSERT de la función si tu tabla `profiles` exige columnas NOT NULL distintas.

begin;

-- 1) Limpieza: borra profiles de usuarios Auth marcados como app Portal/Delivery.
delete from public.profiles p
using auth.users u
where p.id = u.id
  and lower(coalesce(u.raw_user_meta_data->>'app', '')) in ('portal_seller', 'delivery', 'portal');

-- 2) Función: solo Shop (resto de signups) recibe fila en profiles.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(new.raw_user_meta_data->>'app', '')) in ('portal_seller', 'delivery', 'portal') then
    return new;
  end if;

  -- Ajusta columnas según tu esquema real de `public.profiles`.
  insert into public.profiles (id, email, full_name, updated_at)
  values (
    new.id,
    lower(trim(coalesce(new.email, ''))),
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    now()
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

-- 3) Trigger en auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

commit;

-- Verificación rápida: usuarios Portal/Delivery no deberían tener fila en profiles.
select u.id, u.email, u.raw_user_meta_data->>'app' as app_meta
from auth.users u
where lower(coalesce(u.raw_user_meta_data->>'app', '')) in ('portal_seller', 'delivery', 'portal')
  and exists (select 1 from public.profiles p where p.id = u.id);

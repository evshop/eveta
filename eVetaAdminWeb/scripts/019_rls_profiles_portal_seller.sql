-- 019_rls_profiles_portal_seller.sql
-- 1) Vendedores del Portal: INSERT/UPDATE de su propia fila (shop_name, shop_logo_url, shop_banner_url, etc.).
-- 2) Panel Admin Web: usuarios con profiles.is_admin pueden leer/actualizar cualquier perfil (socios, notas).
-- 3) App Tienda + flujos login: lectura amplia de profiles para anon/authenticated (tienda por seller_id, búsqueda por email/tel).
--
-- Nota: SELECT abierto expone todas las columnas de la fila (p. ej. admin_portal_note). Si eso no es aceptable,
-- mueve datos sensibles a otra tabla con RLS más estricta o a una vista sin esas columnas.
--
-- Ejecutar en Supabase SQL Editor. Revisa nombres si ya existen políticas.

alter table if exists public.profiles enable row level security;

-- Evita recursión RLS al comprobar is_admin en políticas sobre profiles.
create or replace function public.profile_is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select p.is_admin from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

revoke all on function public.profile_is_admin() from public;
grant execute on function public.profile_is_admin() to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_select_public" on public.profiles;
create policy "profiles_select_public"
on public.profiles
for select
to anon, authenticated
using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin"
on public.profiles
for update
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

-- 061_fix_profiles_portal_admin_rls_recursion.sql
--
-- Problema: policy "profiles_portal_admin_all" usa public.profile_is_admin(), y esa
-- función consulta profiles_portal bajo RLS -> recursión / bloqueos.
-- Además, sin `set row_security = off` el helper puede seguir viendo 0 filas bajo RLS
-- y el admin NO puede listar/editar otras filas de profiles_portal (panel web vacío).
--
-- Solución: helper SECURITY DEFINER con `set row_security = off` en la definición
-- para leer profiles_portal y decidir si la sesión es admin de Portal.

create or replace function public.is_profiles_portal_admin(p_uid uuid)
returns boolean
language sql
security definer
set search_path = public
set row_security = off
stable
as $$
  select coalesce(
    (
      select pp.is_admin
      from public.profiles_portal pp
      where pp.auth_user_id = p_uid
        and pp.is_active = true
      limit 1
    ),
    false
  );
$$;

revoke all on function public.is_profiles_portal_admin(uuid) from public;
grant execute on function public.is_profiles_portal_admin(uuid) to authenticated;

-- Mantén profile_is_admin() como alias estable (RPC en apps).
create or replace function public.profile_is_admin()
returns boolean
language sql
security definer
set search_path = public
set row_security = off
stable
as $$
  select public.is_profiles_portal_admin(auth.uid());
$$;

revoke all on function public.profile_is_admin() from public;
grant execute on function public.profile_is_admin() to authenticated;

-- Policies admin sin recursión.
alter table if exists public.profiles_portal enable row level security;
drop policy if exists "profiles_portal_admin_all" on public.profiles_portal;
create policy "profiles_portal_admin_all"
on public.profiles_portal
for all
to authenticated
using (public.is_profiles_portal_admin(auth.uid()))
with check (public.is_profiles_portal_admin(auth.uid()));

alter table if exists public.profiles_delivery enable row level security;
drop policy if exists "profiles_delivery_admin_all" on public.profiles_delivery;
create policy "profiles_delivery_admin_all"
on public.profiles_delivery
for all
to authenticated
using (public.is_profiles_portal_admin(auth.uid()))
with check (public.is_profiles_portal_admin(auth.uid()));

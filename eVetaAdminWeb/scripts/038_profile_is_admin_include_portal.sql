-- 038_profile_is_admin_include_portal.sql
-- Tras 034, muchos administradores del panel viven en profiles_portal (is_admin),
-- pero bank_incoming_events y otras políticas solo miraban public.profiles.is_admin.
-- Esto hacía que la web devolviera 0 filas en "Notificaciones bancarias" aunque existieran.

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
  )
  or coalesce(
    (
      select pp.is_admin
      from public.profiles_portal pp
      where pp.auth_user_id = auth.uid()
        and pp.is_active = true
    ),
    false
  );
$$;

revoke all on function public.profile_is_admin() from public;
grant execute on function public.profile_is_admin() to authenticated;

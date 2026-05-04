-- 058_bootstrap_portal_admin_after_reset.sql
-- Crea/vincula la cuenta admin de Portal después del reset.
--
-- Uso:
-- 1) Crea primero el usuario en Auth (Dashboard Supabase > Authentication > Users)
-- 2) Reemplaza los valores en v_email/v_auth_user_id
-- 3) Ejecuta este script

do $$
declare
  v_email text := lower(trim('evetashop@gmail.com')); -- TODO: cambia correo
  v_auth_user_id uuid;
begin
  -- Resuelve el UID real desde auth.users por email.
  select u.id
  into v_auth_user_id
  from auth.users u
  where lower(trim(u.email)) = v_email
  limit 1;

  if v_auth_user_id is null then
    raise exception 'No existe usuario en auth.users para %; créalo primero en Authentication.', v_email;
  end if;

  insert into public.profiles_portal (
    auth_user_id,
    legacy_profile_id,
    email,
    full_name,
    is_admin,
    is_seller,
    is_active
  )
  values (
    v_auth_user_id,
    null,
    v_email,
    'Administrador',
    true,
    false,
    true
  )
  on conflict (email) do update
  set
    auth_user_id = excluded.auth_user_id,
    is_admin = true,
    is_seller = false,
    is_active = true;
end $$;

-- Verificación
select id, auth_user_id, email, is_admin, is_seller, is_active
from public.profiles_portal
where email = lower(trim('evetashop@gmail.com'));


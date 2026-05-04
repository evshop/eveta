-- 058_bootstrap_portal_admin_after_reset.sql
-- Crea/vincula la cuenta admin de Portal después del reset.
--
-- Uso:
-- 1) Crea primero el usuario en Auth (Dashboard Supabase > Authentication > Users)
-- 2) Reemplaza los valores en v_email/v_auth_user_id
-- 3) Ejecuta este script

do $$
declare
  v_email     text := lower(trim('evetashop@gmail.com')); -- TODO: cambia correo si aplica
  v_full_name text := 'Administrador eVeta';
  v_shop_name text := 'eVeta';
  v_shop_desc text := 'Tienda oficial de eVeta.';
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

  -- Admin = también tienda oficial verificada en Portal.
  insert into public.profiles_portal (
    auth_user_id,
    email,
    full_name,
    shop_name,
    shop_description,
    is_admin,
    is_seller,
    is_partner_verified,
    partner_display_order,
    is_active
  )
  values (
    v_auth_user_id,
    v_email,
    v_full_name,
    v_shop_name,
    v_shop_desc,
    true,
    true,
    true,
    0,
    true
  )
  on conflict (email) do update
  set
    auth_user_id        = excluded.auth_user_id,
    full_name           = coalesce(public.profiles_portal.full_name, excluded.full_name),
    shop_name           = coalesce(public.profiles_portal.shop_name, excluded.shop_name),
    shop_description    = coalesce(public.profiles_portal.shop_description, excluded.shop_description),
    is_admin            = true,
    is_seller           = true,
    is_partner_verified = true,
    is_active           = true;
end $$;

-- Verificación
select id, auth_user_id, email, full_name, shop_name,
       is_admin, is_seller, is_partner_verified, is_active
from public.profiles_portal
where email = lower(trim('evetashop@gmail.com'));


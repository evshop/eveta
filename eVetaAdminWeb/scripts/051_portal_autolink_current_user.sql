-- 051_portal_autolink_current_user.sql
-- Transición segura: si un vendedor/admin antiguo existe solo en `profiles`,
-- al loguearse en Portal se crea/vincula su fila en `profiles_portal`.

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
  v_legacy public.profiles;
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

  -- 1) Ya vinculado por auth_user_id.
  select *
  into v_row
  from public.profiles_portal
  where auth_user_id = v_uid
  limit 1;
  if found then
    return v_row;
  end if;

  -- 2) Existe por email (pre-seed): vincular auth_user_id.
  update public.profiles_portal
  set auth_user_id = v_uid
  where email = v_email
    and auth_user_id is null
  returning * into v_row;
  if found then
    return v_row;
  end if;

  -- 3) Fallback legacy desde profiles (solo cuentas seller/admin).
  select *
  into v_legacy
  from public.profiles p
  where lower(trim(coalesce(p.email, ''))) = v_email
  limit 1;

  if found and (coalesce(v_legacy.is_seller, false) or coalesce(v_legacy.is_admin, false)) then
    insert into public.profiles_portal (
      auth_user_id,
      legacy_profile_id,
      email,
      full_name,
      avatar_url,
      phone,
      address,
      username,
      phone_verified_at,
      shop_name,
      shop_description,
      shop_logo_url,
      shop_banner_url,
      is_partner_verified,
      partner_display_order,
      is_admin,
      is_seller,
      is_active
    )
    values (
      v_uid,
      v_legacy.id,
      v_email,
      v_legacy.full_name,
      v_legacy.avatar_url,
      v_legacy.phone,
      v_legacy.address,
      v_legacy.username,
      v_legacy.phone_verified_at,
      v_legacy.shop_name,
      v_legacy.shop_description,
      v_legacy.shop_logo_url,
      v_legacy.shop_banner_url,
      coalesce(v_legacy.is_partner_verified, false),
      coalesce(v_legacy.partner_display_order, 0),
      coalesce(v_legacy.is_admin, false),
      coalesce(v_legacy.is_seller, false),
      true
    )
    on conflict (email) do update
      set auth_user_id = excluded.auth_user_id
    returning * into v_row;

    return v_row;
  end if;

  raise exception 'Tu cuenta no está vinculada a Portal.';
end;
$$;

revoke all on function public.ensure_portal_membership_for_current_user() from public;
grant execute on function public.ensure_portal_membership_for_current_user() to authenticated;

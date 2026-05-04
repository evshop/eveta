-- 054_delivery_autolink_current_user.sql
-- Equivalente a 051 pero para Delivery: en el primer login del repartidor
-- vincula su auth_user_id a una fila pre-sembrada en profiles_delivery
-- (creada por seed_delivery_profiles_from_legacy() o por un admin).
--
-- También permite migrar una cuenta legacy de profiles (con is_delivery=true)
-- creando la fila correspondiente en profiles_delivery si aún no existe.

create or replace function public.ensure_delivery_membership_for_current_user()
returns public.profiles_delivery
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_email text;
  v_row public.profiles_delivery;
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
  from public.profiles_delivery
  where auth_user_id = v_uid
  limit 1;
  if found then
    return v_row;
  end if;

  -- 2) Existe por email (pre-seed): vincular auth_user_id.
  update public.profiles_delivery
  set auth_user_id = v_uid
  where email = v_email
    and auth_user_id is null
  returning * into v_row;
  if found then
    return v_row;
  end if;

  -- 3) Fallback legacy desde profiles (solo cuentas is_delivery=true).
  select *
  into v_legacy
  from public.profiles p
  where lower(trim(coalesce(p.email, ''))) = v_email
  limit 1;

  if found and coalesce(v_legacy.is_delivery, false) then
    insert into public.profiles_delivery (
      auth_user_id,
      legacy_profile_id,
      email,
      full_name,
      is_active
    )
    values (
      v_uid,
      v_legacy.id,
      v_email,
      v_legacy.full_name,
      true
    )
    on conflict (email) do update
      set auth_user_id = excluded.auth_user_id
    returning * into v_row;

    return v_row;
  end if;

  raise exception 'Tu cuenta no está vinculada a Delivery.';
end;
$$;

revoke all on function public.ensure_delivery_membership_for_current_user() from public;
grant execute on function public.ensure_delivery_membership_for_current_user() to authenticated;

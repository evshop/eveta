-- 034_separate_portal_delivery_profiles.sql
-- Objetivo: separar cuentas de Portal/Delivery respecto a eVetaShop.
-- Crea tablas dedicadas y funciones para migrar/vincular usuarios.

create table if not exists public.profiles_portal (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  legacy_profile_id uuid unique references public.profiles(id) on delete set null,
  email text not null unique,
  full_name text,
  avatar_url text,
  phone text,
  address text,
  username text,
  phone_verified_at timestamptz,
  shop_name text,
  shop_description text,
  shop_logo_url text,
  shop_banner_url text,
  is_partner_verified boolean not null default false,
  partner_display_order integer not null default 0,
  is_admin boolean not null default false,
  is_seller boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Si la tabla ya existía, asegúrate de agregar columnas nuevas de tienda.
alter table public.profiles_portal add column if not exists avatar_url text;
alter table public.profiles_portal add column if not exists phone text;
alter table public.profiles_portal add column if not exists address text;
alter table public.profiles_portal add column if not exists username text;
alter table public.profiles_portal add column if not exists phone_verified_at timestamptz;
alter table public.profiles_portal add column if not exists shop_name text;
alter table public.profiles_portal add column if not exists shop_description text;
alter table public.profiles_portal add column if not exists shop_logo_url text;
alter table public.profiles_portal add column if not exists shop_banner_url text;
alter table public.profiles_portal add column if not exists is_partner_verified boolean not null default false;
alter table public.profiles_portal add column if not exists partner_display_order integer not null default 0;

create table if not exists public.profiles_delivery (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  legacy_profile_id uuid unique references public.profiles(id) on delete set null,
  email text not null unique,
  full_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.trg_profiles_portal_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.trg_profiles_delivery_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_portal_updated_at on public.profiles_portal;
create trigger trg_profiles_portal_updated_at
before update on public.profiles_portal
for each row execute function public.trg_profiles_portal_updated_at();

drop trigger if exists trg_profiles_delivery_updated_at on public.profiles_delivery;
create trigger trg_profiles_delivery_updated_at
before update on public.profiles_delivery
for each row execute function public.trg_profiles_delivery_updated_at();

alter table if exists public.profiles_portal enable row level security;
alter table if exists public.profiles_delivery enable row level security;

drop policy if exists "profiles_portal_admin_all" on public.profiles_portal;
create policy "profiles_portal_admin_all"
on public.profiles_portal
for all
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

drop policy if exists "profiles_portal_self_select" on public.profiles_portal;
create policy "profiles_portal_self_select"
on public.profiles_portal
for select
to authenticated
using (auth_user_id = auth.uid() and is_active = true);

drop policy if exists "profiles_delivery_admin_all" on public.profiles_delivery;
create policy "profiles_delivery_admin_all"
on public.profiles_delivery
for all
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

drop policy if exists "profiles_delivery_self_select" on public.profiles_delivery;
create policy "profiles_delivery_self_select"
on public.profiles_delivery
for select
to authenticated
using (auth_user_id = auth.uid() and is_active = true);

create or replace function public.seed_portal_profiles_from_legacy()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  if auth.uid() is not null and not public.profile_is_admin() then
    raise exception 'Sin permisos de administrador.';
  end if;

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
  select
    null::uuid as auth_user_id, -- separar credenciales: vincular cuenta nueva luego
    p.id as legacy_profile_id,
    lower(trim(p.email)) as email,
    p.full_name,
    p.avatar_url,
    p.phone,
    p.address,
    p.username,
    p.phone_verified_at,
    p.shop_name,
    p.shop_description,
    p.shop_logo_url,
    p.shop_banner_url,
    coalesce(p.is_partner_verified, false),
    coalesce(p.partner_display_order, 0),
    coalesce(p.is_admin, false),
    coalesce(p.is_seller, false),
    true
  from public.profiles p
  where coalesce(p.is_seller, false) = true
    and coalesce(trim(p.email), '') <> ''
    and not exists (
      select 1 from public.profiles_portal pp where pp.email = lower(trim(p.email))
    );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.seed_delivery_profiles_from_legacy()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  if auth.uid() is not null and not public.profile_is_admin() then
    raise exception 'Sin permisos de administrador.';
  end if;

  insert into public.profiles_delivery (
    auth_user_id,
    legacy_profile_id,
    email,
    full_name,
    is_active
  )
  select
    null::uuid as auth_user_id, -- separar credenciales: vincular cuenta nueva luego
    p.id as legacy_profile_id,
    lower(trim(p.email)) as email,
    p.full_name,
    true
  from public.profiles p
  where coalesce(p.is_delivery, false) = true
    and coalesce(trim(p.email), '') <> ''
    and not exists (
      select 1 from public.profiles_delivery pd where pd.email = lower(trim(p.email))
    );

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.link_portal_auth_user(
  p_email text,
  p_auth_user_id uuid
)
returns public.profiles_portal
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.profiles_portal;
  v_auth_email text;
begin
  if auth.uid() is not null and not public.profile_is_admin() then
    raise exception 'Sin permisos de administrador.';
  end if;

  select lower(trim(u.email)) into v_auth_email
  from auth.users u
  where u.id = p_auth_user_id;

  if v_auth_email is null then
    raise exception 'Usuario auth no encontrado.';
  end if;

  if v_auth_email <> lower(trim(p_email)) then
    raise exception 'Email no coincide con auth.users.';
  end if;

  update public.profiles_portal
  set auth_user_id = p_auth_user_id
  where email = lower(trim(p_email))
  returning * into v_row;

  if not found then
    raise exception 'Perfil portal no encontrado para %.', p_email;
  end if;

  return v_row;
end;
$$;

create or replace function public.link_delivery_auth_user(
  p_email text,
  p_auth_user_id uuid
)
returns public.profiles_delivery
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.profiles_delivery;
  v_auth_email text;
begin
  if auth.uid() is not null and not public.profile_is_admin() then
    raise exception 'Sin permisos de administrador.';
  end if;

  select lower(trim(u.email)) into v_auth_email
  from auth.users u
  where u.id = p_auth_user_id;

  if v_auth_email is null then
    raise exception 'Usuario auth no encontrado.';
  end if;

  if v_auth_email <> lower(trim(p_email)) then
    raise exception 'Email no coincide con auth.users.';
  end if;

  update public.profiles_delivery
  set auth_user_id = p_auth_user_id
  where email = lower(trim(p_email))
  returning * into v_row;

  if not found then
    raise exception 'Perfil delivery no encontrado para %.', p_email;
  end if;

  return v_row;
end;
$$;

revoke all on function public.seed_portal_profiles_from_legacy() from public;
revoke all on function public.seed_delivery_profiles_from_legacy() from public;
revoke all on function public.link_portal_auth_user(text, uuid) from public;
revoke all on function public.link_delivery_auth_user(text, uuid) from public;

grant execute on function public.seed_portal_profiles_from_legacy() to authenticated;
grant execute on function public.seed_delivery_profiles_from_legacy() to authenticated;
grant execute on function public.link_portal_auth_user(text, uuid) to authenticated;
grant execute on function public.link_delivery_auth_user(text, uuid) to authenticated;


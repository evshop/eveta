-- 024_bootstrap_admin_account.sql
-- Utilidad: marcar una cuenta como admin en profiles.
--
-- 1) Inicia sesión con esa cuenta en cualquier app (para conocer auth.uid()) o cópialo desde Supabase Auth users.
-- 2) Reemplaza el UUID en las consultas de abajo.
--
-- IMPORTANTE: Ejecutar en Supabase SQL Editor con permisos de owner.

-- Reemplaza por el user id real (auth.uid / auth.users.id)
-- Example:
--   \set admin_id '00000000-0000-0000-0000-000000000000'

-- A) Crear perfil si no existe
insert into public.profiles (id, email, full_name, is_admin)
values (
  'REPLACE_ADMIN_UUID_HERE'::uuid,
  null,
  'Admin',
  true
)
on conflict (id) do update
set is_admin = true;

-- B) Verificar
select id, email, full_name, is_admin
from public.profiles
where id = 'REPLACE_ADMIN_UUID_HERE'::uuid;

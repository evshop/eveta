-- 062_admin_portal_note_on_profiles_portal.sql
-- Nota interna visible solo administradores Panel Web (opcional pero recomendado).
--
-- Migración recomendada (si existe la columna legacy en profiles):
--   update public.profiles_portal pp
--   set admin_portal_note = p.admin_portal_note
--   from public.profiles p
--   where pp.legacy_profile_id = p.id
--     and pp.admin_portal_note is null
--     and p.admin_portal_note is not null;

alter table public.profiles_portal
  add column if not exists admin_portal_note text;

comment on column public.profiles_portal.admin_portal_note is
  'Texto libre solo admin: contraseña/pista/notas para acceso al portal del partner.';

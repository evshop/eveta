-- Nota interna visible solo para administradores del panel (p. ej. contraseña o pista de acceso al portal).
-- Ejecutar en Supabase SQL Editor. Ajusta políticas RLS si hace falta: solo is_admin puede leer/escribir.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS admin_portal_note text;

COMMENT ON COLUMN public.profiles.admin_portal_note IS
  'Texto libre solo admin: referencia de contraseña o notas de acceso al portal del vendedor.';

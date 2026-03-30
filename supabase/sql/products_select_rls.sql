-- =============================================================================
-- RLS: el panel admin debe ver TODOS los productos del vendedor (activos e inactivos).
-- La app eVetaShop solo consulta con .eq('is_active', true) en el código.
--
-- Si en Supabase tenías una política SELECT tipo: USING (is_active = true)
-- sin excepción para seller_id, los productos inactivos no aparecen en el admin.
--
-- Pasos en Supabase → SQL Editor:
-- 1) Tabla Authentication → Policies en `products`: anota los nombres de políticas SELECT.
-- 2) Elimina las que restrinjan la lectura solo a is_active (o que choquen).
-- 3) Ejecuta lo de abajo (ajusta `public.profiles` si tu esquema difiere).
-- =============================================================================

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Una sola política SELECT: lectura pública de activos + dueño ve los suyos + admin ve todo.
DROP POLICY IF EXISTS "products_select_public_sellers_admins" ON public.products;

CREATE POLICY "products_select_public_sellers_admins"
ON public.products
FOR SELECT
USING (
  is_active = true
  OR seller_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.profiles AS pr
    WHERE pr.id = auth.uid()
      AND COALESCE(pr.is_admin, false) = true
  )
);

-- Notas:
-- - `anon`: auth.uid() es NULL → solo aplica is_active = true (correcto para la tienda).
-- - Vendedor autenticado: ve filas con is_active = true O donde él es seller_id (incl. inactivos).
-- - Admin: ve todas las filas vía EXISTS.

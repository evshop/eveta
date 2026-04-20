-- 017_rls_admin_products.sql
-- Objetivo:
-- 1) El dueño de la tienda maneja SOLO sus productos (seller_id = auth.uid()).
-- 2) Un admin (profiles.is_admin = true) puede manejar productos de CUALQUIER tienda.
--
-- Ejecuta este script en Supabase SQL Editor.
-- Si tus tablas/columnas difieren, ajusta nombres antes de ejecutar.

alter table if exists public.products enable row level security;

drop policy if exists "products_select_owner_or_admin" on public.products;
create policy "products_select_owner_or_admin"
on public.products
for select
to authenticated
using (
  seller_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_admin = true
  )
);

drop policy if exists "products_insert_owner_or_admin" on public.products;
create policy "products_insert_owner_or_admin"
on public.products
for insert
to authenticated
with check (
  seller_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_admin = true
  )
);

drop policy if exists "products_update_owner_or_admin" on public.products;
create policy "products_update_owner_or_admin"
on public.products
for update
to authenticated
using (
  seller_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_admin = true
  )
)
with check (
  seller_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_admin = true
  )
);

drop policy if exists "products_delete_owner_or_admin" on public.products;
create policy "products_delete_owner_or_admin"
on public.products
for delete
to authenticated
using (
  seller_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_admin = true
  )
);

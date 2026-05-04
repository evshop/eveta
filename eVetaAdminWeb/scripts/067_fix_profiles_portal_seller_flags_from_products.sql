-- 067_fix_profiles_portal_seller_flags_from_products.sql
-- Opcional: si ya hay productos con seller_id -> profiles_portal.id pero la fila Portal
-- tiene is_seller / is_partner_verified en false, la app Shop (RLS 065) y el Admin Web
-- no mostrarán la tienda. Este script alinea flags solo donde hay catálogo.

begin;

update public.profiles_portal pp
set
  is_seller = true,
  is_partner_verified = true,
  updated_at = now()
where pp.is_active = true
  and exists (
    select 1 from public.products pr
    where pr.seller_id = pp.id
  )
  and (
    coalesce(pp.is_seller, false) = false
    or coalesce(pp.is_partner_verified, false) = false
  );

commit;

select id, email, shop_name, is_seller, is_partner_verified,
       (select count(*) from public.products pr where pr.seller_id = pp.id) as product_count
from public.profiles_portal pp
where exists (select 1 from public.products pr where pr.seller_id = pp.id)
order by shop_name nulls last;

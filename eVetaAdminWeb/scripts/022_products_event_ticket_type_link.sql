-- 022_products_event_ticket_type_link.sql
-- Permite tratar entradas como productos especiales en checkout existente.

alter table if exists public.products
add column if not exists event_ticket_type_id uuid
references public.event_ticket_types(id)
on delete set null;

create index if not exists idx_products_event_ticket_type
on public.products(event_ticket_type_id)
where event_ticket_type_id is not null;

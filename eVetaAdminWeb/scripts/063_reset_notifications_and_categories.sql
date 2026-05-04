-- 063_reset_notifications_and_categories.sql
-- Reset selectivo:
-- - Historial de "notificaciones" bancarias (Tasker/webhook) => public.bank_incoming_events
-- - Catálogo de categorías => public.categories
--
-- No toca Auth users, perfiles, productos, pedidos, ni wallet_topups.

begin;

-- 1) "Notificaciones" bancarias recibidas (panel Admin -> Notificaciones bancarias).
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'bank_incoming_events'
  ) then
    truncate table public.bank_incoming_events restart identity cascade;
  end if;
end $$;

-- 2) Categorías (si hay FK desde products, esto puede requerir que products esté vacío o usar CASCADE).
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'categories'
  ) then
    truncate table public.categories restart identity cascade;
  end if;
end $$;

commit;

-- Verificación rápida
select
  (select count(*) from public.bank_incoming_events) as bank_incoming_events_rows,
  (select count(*) from public.categories) as categories_rows;


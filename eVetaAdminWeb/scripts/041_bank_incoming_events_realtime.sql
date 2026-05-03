-- 041_bank_incoming_events_realtime.sql
-- Inscribe bank_incoming_events en la publicación supabase_realtime para que el panel admin
-- reciba INSERT/UPDATE vía WebSocket (tiempo real) sin polling.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'bank_incoming_events'
  ) then
    alter publication supabase_realtime add table public.bank_incoming_events;
  end if;
end $$;

-- 020_events_qr_schema_rls.sql
-- Extensión eVeta: eventos con tickets QR multipersona y beneficios controlados.

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'ticket_benefit_state') then
    create type public.ticket_benefit_state as enum ('blocked', 'active', 'complete');
  end if;
end $$;

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  banner_url text,
  location text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.event_ticket_types (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  name text not null,
  description text,
  price numeric(12,2) not null check (price >= 0),
  people_count integer not null check (people_count > 0),
  benefits jsonb not null default '[]'::jsonb,
  stock integer check (stock is null or stock >= 0),
  sold_count integer not null default 0 check (sold_count >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.event_tickets (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  ticket_type_id uuid not null references public.event_ticket_types(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  qr_token text not null unique,
  people_count integer not null check (people_count > 0),
  used_people integer not null default 0 check (used_people >= 0 and used_people <= people_count),
  status text not null default 'active' check (status in ('active', 'completed', 'cancelled')),
  purchased_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ticket_benefits (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.event_tickets(id) on delete cascade,
  benefit_type text not null,
  total integer not null check (total >= 0),
  used integer not null default 0 check (used >= 0 and used <= total),
  state public.ticket_benefit_state not null default 'blocked',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (ticket_id, benefit_type)
);

create table if not exists public.ticket_action_logs (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.event_tickets(id) on delete cascade,
  action_type text not null check (action_type in ('entry', 'benefit')),
  benefit_type text,
  quantity integer not null default 1 check (quantity > 0),
  actor_user_id uuid references auth.users(id) on delete set null,
  action_meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_events_starts_at on public.events(starts_at);
create index if not exists idx_event_ticket_types_event on public.event_ticket_types(event_id);
create index if not exists idx_event_tickets_user on public.event_tickets(user_id, purchased_at desc);
create index if not exists idx_event_tickets_event on public.event_tickets(event_id, purchased_at desc);
create index if not exists idx_ticket_benefits_ticket on public.ticket_benefits(ticket_id);
create index if not exists idx_ticket_logs_ticket_created on public.ticket_action_logs(ticket_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_events_updated_at on public.events;
create trigger trg_events_updated_at
before update on public.events
for each row execute function public.set_updated_at();

drop trigger if exists trg_event_ticket_types_updated_at on public.event_ticket_types;
create trigger trg_event_ticket_types_updated_at
before update on public.event_ticket_types
for each row execute function public.set_updated_at();

drop trigger if exists trg_event_tickets_updated_at on public.event_tickets;
create trigger trg_event_tickets_updated_at
before update on public.event_tickets
for each row execute function public.set_updated_at();

drop trigger if exists trg_ticket_benefits_updated_at on public.ticket_benefits;
create trigger trg_ticket_benefits_updated_at
before update on public.ticket_benefits
for each row execute function public.set_updated_at();

create or replace function public.profile_is_staff()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select (p.is_admin or p.is_seller) from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

revoke all on function public.profile_is_staff() from public;
grant execute on function public.profile_is_staff() to authenticated;

alter table if exists public.events enable row level security;
alter table if exists public.event_ticket_types enable row level security;
alter table if exists public.event_tickets enable row level security;
alter table if exists public.ticket_benefits enable row level security;
alter table if exists public.ticket_action_logs enable row level security;

drop policy if exists "events_public_select" on public.events;
create policy "events_public_select"
on public.events
for select
to anon, authenticated
using (is_active = true or public.profile_is_admin());

drop policy if exists "events_admin_manage" on public.events;
create policy "events_admin_manage"
on public.events
for all
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

drop policy if exists "event_ticket_types_public_select" on public.event_ticket_types;
create policy "event_ticket_types_public_select"
on public.event_ticket_types
for select
to anon, authenticated
using (
  is_active = true
  and exists (
    select 1 from public.events e
    where e.id = event_id
      and e.is_active = true
  )
  or public.profile_is_admin()
);

drop policy if exists "event_ticket_types_admin_manage" on public.event_ticket_types;
create policy "event_ticket_types_admin_manage"
on public.event_ticket_types
for all
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

drop policy if exists "event_tickets_owner_or_staff_select" on public.event_tickets;
create policy "event_tickets_owner_or_staff_select"
on public.event_tickets
for select
to authenticated
using (
  user_id = auth.uid()
  or public.profile_is_staff()
);

drop policy if exists "event_tickets_admin_manage" on public.event_tickets;
create policy "event_tickets_admin_manage"
on public.event_tickets
for all
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

drop policy if exists "ticket_benefits_owner_or_staff_select" on public.ticket_benefits;
create policy "ticket_benefits_owner_or_staff_select"
on public.ticket_benefits
for select
to authenticated
using (
  exists (
    select 1
    from public.event_tickets t
    where t.id = ticket_id
      and (t.user_id = auth.uid() or public.profile_is_staff())
  )
);

drop policy if exists "ticket_benefits_admin_manage" on public.ticket_benefits;
create policy "ticket_benefits_admin_manage"
on public.ticket_benefits
for all
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

drop policy if exists "ticket_logs_owner_or_staff_select" on public.ticket_action_logs;
create policy "ticket_logs_owner_or_staff_select"
on public.ticket_action_logs
for select
to authenticated
using (
  exists (
    select 1
    from public.event_tickets t
    where t.id = ticket_id
      and (t.user_id = auth.uid() or public.profile_is_staff())
  )
);

drop policy if exists "ticket_logs_staff_insert" on public.ticket_action_logs;
create policy "ticket_logs_staff_insert"
on public.ticket_action_logs
for insert
to authenticated
with check (public.profile_is_staff());

-- 024_wallet_schema_rls.sql
-- Wallet de saldo (dinero) + recargas por QR con comprobante.

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'wallet_topup_status') then
    create type public.wallet_topup_status as enum ('pending_proof', 'pending_review', 'approved', 'rejected', 'expired');
  end if;
end $$;

create table if not exists public.wallet_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance numeric(14,2) not null default 0 check (balance >= 0),
  currency text not null default 'Bs',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_topups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reference_code text not null unique,
  amount numeric(14,2) not null check (amount > 0),
  status public.wallet_topup_status not null default 'pending_proof',
  proof_url text,
  proof_note text,
  reconciliation_hint jsonb not null default '{}'::jsonb,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  rejected_at timestamptz,
  reject_reason text,
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  direction text not null check (direction in ('credit', 'debit')),
  amount numeric(14,2) not null check (amount > 0),
  source_type text not null,
  source_id text,
  topup_id uuid references public.wallet_topups(id) on delete set null,
  order_id uuid references public.orders(id) on delete set null,
  event_ticket_type_id uuid references public.event_ticket_types(id) on delete set null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_wallet_topups_user_created
on public.wallet_topups(user_id, created_at desc);

create index if not exists idx_wallet_topups_status_created
on public.wallet_topups(status, created_at desc);

create index if not exists idx_wallet_ledger_user_created
on public.wallet_ledger(user_id, created_at desc);

create unique index if not exists uq_wallet_ledger_topup_credit
on public.wallet_ledger(topup_id)
where topup_id is not null and direction = 'credit' and source_type = 'topup_approved';

create or replace function public.ensure_wallet_account(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.wallet_accounts (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;
end;
$$;

create or replace function public.trg_wallet_accounts_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_wallet_accounts_updated_at on public.wallet_accounts;
create trigger trg_wallet_accounts_updated_at
before update on public.wallet_accounts
for each row execute function public.trg_wallet_accounts_updated_at();

drop trigger if exists trg_wallet_topups_updated_at on public.wallet_topups;
create trigger trg_wallet_topups_updated_at
before update on public.wallet_topups
for each row execute function public.set_updated_at();

alter table if exists public.wallet_accounts enable row level security;
alter table if exists public.wallet_topups enable row level security;
alter table if exists public.wallet_ledger enable row level security;

drop policy if exists "wallet_accounts_owner_select" on public.wallet_accounts;
create policy "wallet_accounts_owner_select"
on public.wallet_accounts
for select
to authenticated
using (user_id = auth.uid() or public.profile_is_admin());

drop policy if exists "wallet_accounts_owner_insert" on public.wallet_accounts;
create policy "wallet_accounts_owner_insert"
on public.wallet_accounts
for insert
to authenticated
with check (user_id = auth.uid() or public.profile_is_admin());

drop policy if exists "wallet_accounts_admin_update" on public.wallet_accounts;
create policy "wallet_accounts_admin_update"
on public.wallet_accounts
for update
to authenticated
using (public.profile_is_admin())
with check (public.profile_is_admin());

drop policy if exists "wallet_topups_owner_select" on public.wallet_topups;
create policy "wallet_topups_owner_select"
on public.wallet_topups
for select
to authenticated
using (user_id = auth.uid() or public.profile_is_admin());

drop policy if exists "wallet_topups_owner_insert" on public.wallet_topups;
create policy "wallet_topups_owner_insert"
on public.wallet_topups
for insert
to authenticated
with check (user_id = auth.uid() or public.profile_is_admin());

drop policy if exists "wallet_topups_owner_update" on public.wallet_topups;
create policy "wallet_topups_owner_update"
on public.wallet_topups
for update
to authenticated
using (user_id = auth.uid() or public.profile_is_admin())
with check (user_id = auth.uid() or public.profile_is_admin());

drop policy if exists "wallet_ledger_owner_select" on public.wallet_ledger;
create policy "wallet_ledger_owner_select"
on public.wallet_ledger
for select
to authenticated
using (user_id = auth.uid() or public.profile_is_admin());

drop policy if exists "wallet_ledger_admin_insert" on public.wallet_ledger;
create policy "wallet_ledger_admin_insert"
on public.wallet_ledger
for insert
to authenticated
with check (public.profile_is_admin());

revoke all on function public.ensure_wallet_account(uuid) from public;
grant execute on function public.ensure_wallet_account(uuid) to authenticated;

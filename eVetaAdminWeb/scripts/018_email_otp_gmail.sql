-- 018_email_otp_gmail.sql
-- Soporte para OTP por correo (6 dígitos) para signup y recuperación.

create extension if not exists pgcrypto;

create table if not exists public.email_otp_codes (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  purpose text not null check (purpose in ('signup', 'password_reset')),
  code_hash text not null,
  expires_at timestamptz not null,
  attempts int not null default 0,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_email_otp_codes_lookup
  on public.email_otp_codes (email, purpose, created_at desc);

alter table public.email_otp_codes enable row level security;

drop policy if exists "service_role_only_email_otp" on public.email_otp_codes;
create policy "service_role_only_email_otp"
on public.email_otp_codes
for all
to service_role
using (true)
with check (true);

-- Billing/trial entitlement fields for Perch.
-- Run this once in the Supabase SQL editor for the active project.

alter table public.danotch_user_profiles
  add column if not exists trial_started_at timestamptz,
  add column if not exists trial_ends_at timestamptz,
  add column if not exists lifetime_purchased_at timestamptz,
  add column if not exists billing_status text not null default 'trialing',
  add column if not exists dodo_customer_id text,
  add column if not exists dodo_payment_id text;

update public.danotch_user_profiles
set
  trial_started_at = coalesce(trial_started_at, now()),
  trial_ends_at = coalesce(trial_ends_at, now() + interval '14 days'),
  billing_status = case
    when lifetime_purchased_at is not null then 'paid'
    when coalesce(trial_ends_at, now() + interval '14 days') > now() then 'trialing'
    else 'expired'
  end;

alter table public.danotch_user_profiles
  alter column trial_started_at set default now(),
  alter column trial_ends_at set default (now() + interval '14 days');

create index if not exists danotch_user_profiles_billing_status_idx
  on public.danotch_user_profiles (billing_status);

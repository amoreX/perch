-- ============================================
-- Danotch — Supabase schema
-- All tables prefixed with danotch_
-- ============================================

-- 1. User profiles
create table danotch_user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  created_at timestamptz not null default now()
);

-- 2. Connected apps (Composio OAuth)
create table danotch_connected_apps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  app_type text not null,
  active boolean not null default false,
  composio_conn_id text,
  connected_at timestamptz,
  disconnected_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, app_type)
);

-- 3. Provider configs (BYOK)
create table danotch_provider_configs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  api_key_encrypted text not null,
  model_id text not null,
  is_active boolean not null default false,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, provider)
);

-- 4. Chat threads
create table danotch_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 5. Messages
create table danotch_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references danotch_threads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  content text not null default '',
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- 6. Scheduled tasks
create table danotch_scheduled_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  prompt text not null,
  task_type text not null default 'scheduled',
  cron text,
  interval_ms bigint,
  target_app text,
  notify_user boolean not null default false,
  enabled boolean not null default true,
  next_run_at timestamptz,
  last_run_at timestamptz,
  run_count integer not null default 0,
  last_result jsonb,
  created_at timestamptz not null default now()
);

-- 7. Notifications
create table danotch_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null,
  source_id uuid,
  title text not null,
  body text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Indexes
create index idx_danotch_connected_apps_user on danotch_connected_apps(user_id);
create index idx_danotch_provider_configs_user on danotch_provider_configs(user_id);
create index idx_danotch_threads_user on danotch_threads(user_id);
create index idx_danotch_messages_thread on danotch_messages(thread_id);
create index idx_danotch_scheduled_tasks_user on danotch_scheduled_tasks(user_id);
create index idx_danotch_scheduled_tasks_next_run on danotch_scheduled_tasks(enabled, next_run_at);
create index idx_danotch_notifications_user on danotch_notifications(user_id, created_at desc);
create index idx_danotch_notifications_unread on danotch_notifications(user_id, read) where read = false;

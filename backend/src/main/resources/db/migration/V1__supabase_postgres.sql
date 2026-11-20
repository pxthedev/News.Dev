-- Supabase PostgreSQL: private backend schema, never exposed through PostgREST.
create schema if not exists fionova;
revoke all on schema fionova from public;
create table fionova.users (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.users enable row level security;
revoke all on fionova.users from public;
create table fionova.emails (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.emails enable row level security;
revoke all on fionova.emails from public;
create table fionova.sessions (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.sessions enable row level security;
revoke all on fionova.sessions from public;
create table fionova.refresh_tokens (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.refresh_tokens enable row level security;
revoke all on fionova.refresh_tokens from public;
create table fionova.social_identities (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.social_identities enable row level security;
revoke all on fionova.social_identities from public;
create table fionova.password_resets (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.password_resets enable row level security;
revoke all on fionova.password_resets from public;
create table fionova.articles (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.articles enable row level security;
revoke all on fionova.articles from public;
create table fionova.live_events (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.live_events enable row level security;
revoke all on fionova.live_events from public;
create table fionova.reader_events (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.reader_events enable row level security;
revoke all on fionova.reader_events from public;
create table fionova.outbox (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.outbox enable row level security;
revoke all on fionova.outbox from public;
create table fionova.sources (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.sources enable row level security;
revoke all on fionova.sources from public;
create table fionova.imports (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.imports enable row level security;
revoke all on fionova.imports from public;
create table fionova.push_tokens (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.push_tokens enable row level security;
revoke all on fionova.push_tokens from public;
create table fionova.system (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.system enable row level security;
revoke all on fionova.system from public;
create table fionova.user_saved (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.user_saved enable row level security;
revoke all on fionova.user_saved from public;
create table fionova.user_reads (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.user_reads enable row level security;
revoke all on fionova.user_reads from public;
create table fionova.user_reading_days (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.user_reading_days enable row level security;
revoke all on fionova.user_reading_days from public;
create table fionova.user_alerts (
  owner_id text not null default '',
  id text not null check (length(id) between 1 and 1500 and position('/' in id) = 0),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (owner_id, id)
);
alter table fionova.user_alerts enable row level security;
revoke all on fionova.user_alerts from public;

-- B-tree indexes support filters and stable keyset pagination; GIN supports arrays.
create index articles_published on fionova.articles ((data->>'publishedAt') desc, id desc);
create index articles_confirmed_published on fionova.articles ((data->>'confirmed'), (data->>'publishedAt') desc, id desc);
create index articles_category_published on fionova.articles ((data->>'category'), (data->>'publishedAt') desc, id desc);
create index articles_urgency_published on fionova.articles ((data->>'urgency'), (data->>'publishedAt') desc, id desc);
create index articles_entities on fionova.articles using gin ((data->'entityIds'));
create index articles_companies on fionova.articles using gin ((data->'companyKeys'));
create index articles_search on fionova.articles using gin ((data->'searchTerms'));
create index sessions_user on fionova.sessions ((data->>'userId'));
create index sessions_expiry on fionova.sessions ((data->>'expiresAt'));
create index resets_expiry on fionova.password_resets ((data->>'expiresAt'));
create index outbox_due on fionova.outbox ((data->>'state'), (data->>'availableAt'));
create index outbox_expiry on fionova.outbox ((data->>'expiresAt'));
create index push_user on fionova.push_tokens ((data->>'userId'));
create index readers_day on fionova.reader_events ((data->>'day'));
create index saved_owner_time on fionova.user_saved (owner_id, (data->>'savedAt') desc);
create index days_owner_day on fionova.user_reading_days (owner_id, (data->>'day') desc);
create index alerts_owner_time on fionova.user_alerts (owner_id, (data->>'at') desc);
create index users_email on fionova.users ((data->>'email'));

-- Supabase roles are absent in ordinary PostgreSQL used by integration tests.
do $$
begin
  if exists (select 1 from pg_roles where rolname='anon') then
    revoke all on schema fionova from anon;
    revoke all on all tables in schema fionova from anon;
  end if;
  if exists (select 1 from pg_roles where rolname='authenticated') then
    revoke all on schema fionova from authenticated;
    revoke all on all tables in schema fionova from authenticated;
  end if;
end $$;

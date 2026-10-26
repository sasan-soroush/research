-- app_name 001: <describe>. Replace every "app_name" with the app's schema name.
-- Self-contained: depends only on auth.users. See ../../README.md for conventions.

create schema app_name;
create schema app_name_private;
comment on schema app_name is 'App: app_name. Exposed via Data API.';
comment on schema app_name_private is 'App: app_name. Internal helpers; never exposed.';

create function app_name_private.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create table app_name.items (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index items_user_id_idx on app_name.items (user_id);
create trigger set_updated_at before update on app_name.items
  for each row execute function app_name_private.set_updated_at();

alter table app_name.items enable row level security;
create policy "own items" on app_name.items for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Grants: signed-in users only, no anon access
revoke all on schema app_name_private from public;
revoke execute on all functions in schema app_name_private from public;
grant usage on schema app_name to authenticated, service_role;
grant select, insert, update, delete on all tables in schema app_name to authenticated;
grant all on all tables in schema app_name to service_role;
alter default privileges for role postgres in schema app_name
  grant select, insert, update, delete on tables to authenticated;
alter default privileges for role postgres in schema app_name
  grant all on tables to service_role;

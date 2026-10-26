-- excalidraw 001: projects + drawings, owned per user.
-- Self-contained: depends only on auth.users. See ../../README.md for conventions.

create schema excalidraw;
create schema excalidraw_private;
comment on schema excalidraw is 'App: excalidraw. Exposed via Data API.';
comment on schema excalidraw_private is 'App: excalidraw. Internal helpers; never exposed.';

-- updated_at trigger, kept inside the app so the app can be moved out alone
create function excalidraw_private.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create table excalidraw.projects (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name       text not null check (length(btrim(name)) between 1 and 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id) -- target for the composite FK below
);

create table excalidraw.drawings (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  project_id uuid, -- null = not in any project
  name       text not null default 'Untitled' check (length(btrim(name)) between 1 and 200),
  scene      jsonb not null default '{}'::jsonb, -- { elements, appState, files }
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- a drawing can only sit in a project owned by the same user;
  -- deleting a project keeps its drawings (they become unfiled)
  foreign key (project_id, user_id) references excalidraw.projects (id, user_id)
    on delete set null (project_id)
);

create index projects_user_id_idx on excalidraw.projects (user_id);
create index drawings_user_updated_idx on excalidraw.drawings (user_id, updated_at desc);
create index drawings_project_idx on excalidraw.drawings (project_id, user_id);

create trigger set_updated_at before update on excalidraw.projects
  for each row execute function excalidraw_private.set_updated_at();
create trigger set_updated_at before update on excalidraw.drawings
  for each row execute function excalidraw_private.set_updated_at();

-- RLS: each user sees and changes only their own rows
alter table excalidraw.projects enable row level security;
alter table excalidraw.drawings enable row level security;

create policy "own projects" on excalidraw.projects for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own drawings" on excalidraw.drawings for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Grants: signed-in users only, no anon access
revoke all on schema excalidraw_private from public;
revoke execute on all functions in schema excalidraw_private from public;
grant usage on schema excalidraw to authenticated, service_role;
grant select, insert, update, delete on all tables in schema excalidraw to authenticated;
grant all on all tables in schema excalidraw to service_role;
alter default privileges for role postgres in schema excalidraw
  grant select, insert, update, delete on tables to authenticated;
alter default privileges for role postgres in schema excalidraw
  grant all on tables to service_role;

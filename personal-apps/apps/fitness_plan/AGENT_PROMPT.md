The Supabase project this app uses has been renamed to **personal-apps** (same ref `xhvzzsblfumpnrtfmrdg`, same URL and keys).
It now hosts several of my personal apps, each in its own Postgres schema. Move this app into that structure and
add login, in one coordinated change. Read the whole brief before starting.

## Conventions (all apps in this project follow these)

- Each app has two schemas: `<app>` (API tables, exposed via the Data API) and `<app>_private` (functions,
  triggers, staging data; never exposed). For this app: `fitness_plan` and `fitness_plan_private`.
- `public` holds no app tables.
- An app only references its own two schemas and `auth.users`, so it can be moved to its own project later with
  `pg_dump --schema=fitness_plan --schema=fitness_plan_private`.
- All apps share one login (`auth.users`). Public sign-up will be turned off; the only account is mine and it
  already exists (it's the only row in `auth.users`).
- RLS on every table. User-owned rows: `user_id uuid not null default auth.uid() references auth.users(id) on delete cascade`,
  policies `to authenticated` with `using ((select auth.uid()) = user_id)` + the same `with check`.
  Shared catalog tables: `select` only, `to authenticated using (true)`.
- **No `anon` access.** Grants are explicit; new tables are not auto-exposed.
- Functions: `set search_path = ''`, fully qualified names, security invoker, in `<app>_private`, execute revoked from `public`.
- Migration names are prefixed with the app: `fitness_plan_001_...`, `fitness_plan_002_...`.

## Current state (checked 2026-10-26)

- 8 tables in `public`: `programs`, `exercises`, `program_days`, `day_exercises` (catalog), `workout_sessions`,
  `set_logs`, `user_settings`, `app_settings` (single-row settings with `id boolean`).
- Function `private.import_program(doc jsonb)`, which hard-codes `public.*` table names.
- `scratch.pages(url, status, html)`: 21 scraped exercise-guide pages (not exposed to the API).
- **Security problem:** `anon` has `ALL` on `workout_sessions` and `set_logs`, and `SELECT/UPDATE` on `app_settings`.
  Anyone with the publishable key (which ships in the app) can read/modify my workout data. The app has no login.
- All existing logged data is anonymous: 1 workout session and 35 set logs have `user_id = null`.
  `user_settings` is empty; `app_settings` has 1 row.
- Existing migrations in history: `init`, `import_program`.

## What to do

### 1. App: add login
- Sign-in screen (email + password, and/or magic link). **Sign-in only, no sign-up UI.**
- Keep the session (supabase-js persists it by default); add a sign-out action.
- If you use magic links, tell me which redirect URL(s) I must add under Authentication → URL Configuration.
- Replace all `app_settings` usage with `user_settings` (one row per user, upsert on `user_id`).
- Create the client with the schema: `createClient(url, publishableKey, { db: { schema: 'fitness_plan' } })`.
  Update any scripts that call `private.import_program` to `fitness_plan_private.import_program`.

### 2. Database migration `fitness_plan_001_own_schema_and_auth`
Inspect the live schema first and adapt if anything differs from the above. Do it in **one** migration:

1. `create schema fitness_plan; create schema fitness_plan_private;` with comments.
2. `alter table public.<t> set schema fitness_plan` for the 7 tables other than `app_settings`
   (policies, indexes, FKs move with them).
3. Backfill ownership. Assert there is exactly one user, then
   `update ... set user_id = <that id> where user_id is null` on `workout_sessions` and `set_logs`.
   Then `alter column user_id set not null` on both.
4. Copy `app_settings` into `fitness_plan.user_settings` for that user
   (`active_program_id`, `rest_seconds`; `on conflict (user_id) do update`). Then drop `public.app_settings`.
5. Policies: drop every existing policy on the moved tables. Recreate them:
   - `programs`, `exercises`, `program_days`, `day_exercises`: `for select to authenticated using (true)`.
   - `workout_sessions`, `set_logs`, `user_settings`: `for all to authenticated` with the ownership check
     (`using` + `with check`).
6. Indexes: make sure every FK column and every `user_id` has an index (`create index if not exists`).
7. Recreate `import_program(doc jsonb)` as `fitness_plan_private.import_program` with the same body but
   `fitness_plan.*` table names, `set search_path = ''`. Then `drop function private.import_program(jsonb)`.
8. `alter table scratch.pages set schema fitness_plan_private;` and rename it to `scraped_pages`
   (or drop it if the app/scripts no longer need it; ask me).
9. `drop schema private; drop schema scratch;` (plain `drop`, no cascade, so it fails if anything is left).
10. Grants:
    ```sql
    revoke all on all tables in schema fitness_plan from anon, authenticated;
    revoke all on schema fitness_plan_private from public;
    revoke execute on all functions in schema fitness_plan_private from public;
    grant usage on schema fitness_plan to authenticated, service_role;
    grant select on fitness_plan.programs, fitness_plan.exercises, fitness_plan.program_days, fitness_plan.day_exercises to authenticated;
    grant select, insert, update, delete on fitness_plan.workout_sessions, fitness_plan.set_logs, fitness_plan.user_settings to authenticated;
    grant all on all tables in schema fitness_plan to service_role;
    ```

### 3. Order of rollout (tell me when to do the dashboard step)
1. Apply the migration.
2. **I** add `fitness_plan` under Dashboard → Integrations → Data API → Exposed schemas.
3. Deploy the app change.
The app is broken between steps 1 and 3; keep that window short.

### 4. Verify, then report
- Run Supabase security + performance advisors; fix anything about these tables.
- As `anon`: every `fitness_plan` table is denied.
- As a random authenticated uid: sees catalog, sees **zero** sessions/sets/settings, cannot update mine.
- As me: sees my 1 session and 35 sets and my settings; can log a new set.
- In the deployed app: sign in, see history, log a set, sign out.
- `public`, `private`, `scratch` contain nothing from this app.

Report what you changed, the migration you applied, and anything I need to do in the dashboard.

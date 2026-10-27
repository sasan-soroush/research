# personal-apps (Supabase)

One Supabase project (`personal-apps-ca`, ref `nxeugbwlmjjagapwotwz`, region `ca-central-1`) holding the database for several personal apps.
Apps share one login (`auth.users`) and are otherwise fully separate.

```
auth                 shared: one account for all apps
<app>                one schema per app, exposed via the Data API
<app>_private        that app's internal helpers / staging data, never exposed
public               empty: no app tables here
```

Current apps: `excalidraw` (`apps/excalidraw/`), `fitness_plan` (`apps/fitness_plan/000_baseline.sql`).

## Rules for every app

1. **Schemas:** `<app>` for API tables, `<app>_private` for functions, triggers and staging data. Use snake_case names.
2. **Self-contained:** an app's objects only reference its own two schemas and `auth.users`. No shared helper
   functions, no cross-app foreign keys. (So each app has its own small `set_updated_at()` trigger function.)
3. **Ownership:** every user-owned table has
   `user_id uuid not null default auth.uid() references auth.users (id) on delete cascade`, plus an index on it.
4. **RLS on every table**, policies `to authenticated` with `using ((select auth.uid()) = user_id)` and the same
   `with check`. Shared read-only catalog tables may use `using (true)` for `select` only.
5. **No `anon` access** unless the app is genuinely public. Grants are explicit (new tables are not exposed
   automatically). The grants block is in `apps/_template/001_init.sql`.
6. **Functions:** `set search_path = ''`, fully qualified names, `security invoker` (default). Put them in
   `<app>_private` and revoke execute from `public`.
7. **Migrations:** one folder per app in `apps/<app>/`, files `NNN_description.sql`. Apply with the migration
   name `<app>_NNN_description` so the shared history shows which app each change belongs to.

## Adding a new app

1. Copy `apps/_template/001_init.sql` to `apps/<app>/001_init.sql`, replace `app_name`, add tables.
2. Apply it as migration `<app>_001_init`.
3. Dashboard → Integrations → Data API → **Exposed schemas**: add `<app>`.
4. Client: `createClient(url, publishableKey, { db: { schema: '<app>' } })`.

## Moving an app out to its own project later

```bash
pg_dump "$DB_URL" --schema=<app> --schema=<app>_private --no-owner --no-privileges > <app>.sql
```
Restore into the new project, re-run the app's grants block, and recreate its user(s) with the same UUIDs
(or remap `user_id`). Then point the app at the new URL/key.

## Auth settings shared by all apps

- Authentication → Sign In / Providers: turn **off** "Allow new users to sign up". This keeps strangers from creating
  accounts on any app.
- Authentication → URL Configuration:
  - **Redirect URLs** is an allow-list. Add each app's exact URL (no wildcards like `*.onrender.com`, which
    would match other people's sites). Each app passes its own URL as `emailRedirectTo`.
  - **Site URL** is the single fallback when a requested URL isn't on the list. Leave it alone.
  - Only email links (magic link, password reset) use these. Password sign-in doesn't.
- Email templates are shared, so keep their wording app-neutral.

| App        | URL                                  |
|------------|--------------------------------------|
| excalidraw | https://drawings-v9u1.onrender.com   |

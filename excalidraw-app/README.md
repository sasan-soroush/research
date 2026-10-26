# Drawings (personal Excalidraw)

My own Excalidraw: sign in, organise drawings into projects, open them from any device.

- Vite + React + [`@excalidraw/excalidraw`](https://www.npmjs.com/package/@excalidraw/excalidraw)
- Data: Supabase project **personal-apps**, schema `excalidraw` (see `../personal-apps/`)
- Hosting: Render static site (free), auto-deploys on push

## How it works

- Login: email + password, or a magic link. Sign-in only; accounts are not created from the app.
- `excalidraw.projects` and `excalidraw.drawings` (scene stored as JSON, images included). Row-level security:
  each user only sees their own rows.
- The editor autosaves 1.5 s after the last change, and when the tab is hidden or closed. Panning, zooming and
  selecting don't count as changes.
- Deleting a project keeps its drawings (they move to Unfiled).
- Routes: `#/`, `#/unfiled`, `#/p/<project>`, `#/d/<drawing>`.

## Develop

```bash
cp .env.example .env.local   # fill in the publishable key
npm install
npm run dev
```

## Deploy (Render static site)

- Root directory `excalidraw-app`, build `npm ci && npm run build`, publish directory `dist`
- Env vars: `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`
- Supabase: `excalidraw` must be listed under Data API → Exposed schemas, and the site URL must be in
  Authentication → URL Configuration → Redirect URLs (for magic links).

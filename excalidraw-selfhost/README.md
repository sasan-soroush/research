# Self-hosted Excalidraw

Runs Excalidraw with its own live-collaboration server behind Caddy (automatic HTTPS).

| Service      | What it is                                                                 |
|--------------|----------------------------------------------------------------------------|
| `excalidraw` | The web app, built from source (pinned commit) with the collab URL set to your domain |
| `room`       | [`excalidraw-room`](https://github.com/excalidraw/excalidraw-room), the socket.io relay for live collaboration |
| `caddy`      | Serves everything on one domain; `/socket.io/*` goes to `room`, everything else to `excalidraw` |

## Requirements

- A Linux server with Docker + the Compose plugin
- **About 4 GB RAM for the build.** If the server is small, build on another machine and push the image, or add swap.
- A domain (e.g. `draw.example.com`) whose DNS A/AAAA record points to the server, with ports 80 and 443 open

## Deploy

```bash
cp .env.example .env        # then set SITE_ADDRESS and PUBLIC_URL to your domain
docker compose up -d --build
```

Open `https://draw.example.com`. The first build takes a few minutes; Caddy gets a Let's Encrypt cert automatically.

**Changing `PUBLIC_URL` requires a rebuild**, because Vite bakes the collab URL into the JS bundle:
`docker compose build excalidraw && docker compose up -d`.

### Local test

Run with no `.env`. The defaults serve `https://localhost` with Caddy's self-signed local CA. Accept the browser warning.
Collaboration needs HTTPS (or plain `localhost`) because it uses WebCrypto for end-to-end encryption.

## Updating

Change `EXCALIDRAW_REF` in the `Dockerfile` to a newer commit from
[excalidraw/excalidraw master](https://github.com/excalidraw/excalidraw/commits/master). Then run:

```bash
docker compose build --pull excalidraw && docker compose pull room caddy && docker compose up -d
```

## What stays on your server, and what doesn't

- **Drawing alone:** fully local. Scenes live in the browser's localStorage/IndexedDB; nothing is sent anywhere.
- **Live collaboration:** real-time sync goes through **your** `room` server. Everything is end-to-end encrypted
  (the key is in the URL `#fragment`, which never reaches any server).
- **Still uses excalidraw.com services (E2E-encrypted, opaque to them):**
  - *Export → "Shareable link"* uploads to `json.excalidraw.com`.
  - Collab-room persistence and images pasted during collaboration go to Excalidraw's Firebase project.
  - The public library browser (`libraries.excalidraw.com`).

  To make these self-hosted too, you need a compatible storage backend, such as a community project like
  `excalidraw-storage-backend`, plus a patched frontend. That's out of scope here. If you never use share links or
  images in collab sessions, nothing leaves your server.
- Tracking is disabled in the build (`VITE_APP_ENABLE_TRACKING=false`).

## Optional: put it behind auth

Excalidraw has no user accounts. To restrict access, add `basic_auth` to the `Caddyfile`
(hash a password with `docker compose exec caddy caddy hash-password`):

```caddy
{$SITE_ADDRESS}

basic_auth {
	alice $2a$14$...hash...
}
...
```

## Files

- `Dockerfile`: builds the app from a pinned upstream commit
- `docker-compose.yml`: the three services
- `Caddyfile`: TLS + routing
- `.env.example`: domain settings

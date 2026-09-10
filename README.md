# WOLFTVEE

Flat, intense Flutter streaming catalog — movies, series, live TV, search.

## Setup

```bash
cp .env.example .env
# Add your TMDB_API_KEY (and optional TRAKT_CLIENT_ID)
# Optional: PUBLIC_IPTV_TOKEN once your Public IPTV API key exists (see below)
flutter pub get
flutter run
```

## Catalog strategy (dual source, no duplicates)

| Role | Source | Why |
|------|--------|-----|
| **Primary playback** | Elo MAPI (`mapi.elochkaigolochla.com`) | Real HLS / iframe players in catalog |
| **Primary live TV** | iptv-org open catalog (+ optional Public IPTV + Elo) | Full playable channel directory; Sports first |
| **Secondary discovery** | Trakt trending → TMDB hydrate, or TMDB trending alone | Broader coverage + posters |
| **Dedupe** | Normalized `title + year + kind` | One card per title; Elo wins when both match |
| **Recency** | Elo `created_at` | “Latest uploads” rail prefers newest Elo items |
| **Gap-fill** | TMDB/Trakt-only titles | Shown under “More to explore” when Elo misses them |

### Not wired (by design)

- `vidsrc*` / `videasy` / `smashystream` embeds — third-party unauthorized stream hosts  
- FlixHQ scrapers, Mixdrop/Openload extractors, Real-Debrid / AllDebrid unlock APIs  
- Dead configs: `beetvapk.app` / `beetvapk.me` JSON  

Playback stays on **licensed Elo players** for VOD (m3u8 → media_kit, iframe → WebView). Live TV uses the IPTV directory (and Elo broadcasts when available). Titles that only exist on Trakt/TMDB can open trailers when TMDB has one; they do not get pirate embeds.

## Live TV — Public IPTV (`publiciptv.com`)

Your Public IPTV site is the intended Live TV brand/host. WOLFTVEE already reads:

| Env | Purpose |
|-----|---------|
| `PUBLIC_IPTV_BASE_URL` | Default `https://publiciptv.com` |
| `PUBLIC_IPTV_TOKEN` | Optional Bearer token for `GET /api/channels` |
| `IPTV_ORG_API_BASE` | Fallback full catalog while `/api/channels` is auth-gated |

### Important: there is no “API token” page on the website today

Even when you are signed in (profile avatar top-right, e.g. **im**):

- Clicking the avatar / visiting account URLs does **not** show an API key or developer token.
- Sidebar **Credits** are for site tools (AI / Image Generator), **not** Live TV unlock.
- Sign-in is free Google login for **user data** (favorites / playlists), not a paid unlock.

### You don’t need a token to play streams

When you open a channel and see **Choose Stream Source**, those `.m3u8` links are the playable feeds. Example (public, no login):

- https://publiciptv.com/channels/abcus

The page embeds stream objects like:

```json
{
  "channel_id": "abcus",
  "address": "https://….m3u8",
  "status_code": "200",
  "source": "iptvorg"
}
```

So:

1. **No API token** is required to get playable URLs from channel pages.
2. Public IPTV’s stream `source` is **`iptvorg`** — the same open catalog WOLFTVEE already uses for Live TV.
3. `GET /api/channels` is only the *bulk list* API (still 401 without a session). Playback does not depend on that token.
4. The site’s “mixed content / insecure HTTP” notice is a **browser** warning. The Flutter player can use `http://` and `https://` HLS URLs directly.

### Quick links (bookmark these)

| What | Link |
|------|------|
| Site home (channels UI) | https://publiciptv.com/ |
| Sign in (Google) | https://publiciptv.com/auth/signin |
| Login page | https://publiciptv.com/login |
| Account / Profile (after login) | https://publiciptv.com/user |
| Credits balance (after login) | https://publiciptv.com/user/credits |
| My Channels | https://publiciptv.com/user/channels |
| My Playlists | https://publiciptv.com/user/playlists |
| Example channel + stream picker | https://publiciptv.com/channels/abcus |
| Sports | https://publiciptv.com/sports |
| Tools | https://publiciptv.com/tools |
| Public categories API (no login) | https://publiciptv.com/api/categories |
| Public countries API (no login) | https://publiciptv.com/api/countries |
| Channel list API (**bulk list; auth → 401**) | https://publiciptv.com/api/channels |

**Credits ≠ API token.** Buying or holding credits does **not** produce `PUBLIC_IPTV_TOKEN`.

### Optional bulk-list auth (only if you want `/api/channels`)

1. Open [Sign in](https://publiciptv.com/auth/signin) and complete Google login.
2. In the browser, DevTools → **Network** → open  
   [https://publiciptv.com/api/channels](https://publiciptv.com/api/channels)  
   A logged-in **session cookie** may unlock that bulk list. That cookie is **not** a stable app API key.

### What to put in WOLFTVEE `.env`

```bash
PUBLIC_IPTV_BASE_URL=https://publiciptv.com
PUBLIC_IPTV_TOKEN=          # leave empty — not required for Live TV playback
IPTV_ORG_API_BASE=https://iptv-org.github.io/api
```

Live TV already works without `PUBLIC_IPTV_TOKEN` because it uses the same **iptvorg** stream catalog your channel pages show.

### Owner checklist (only if you want the app to call your host’s bulk API)

Do **one** of these on the Public IPTV backend:

1. Make [`GET /api/channels`](https://publiciptv.com/api/channels) public, **or**
2. Add `/api/public/channels`, **or**
3. Add a Bearer API key + a Settings page that shows the token (then set `PUBLIC_IPTV_TOKEN`).

Until then, leave the token empty — channel playback in WOLFTVEE does not need it.

## Elo endpoints

| Type | Endpoint |
|------|----------|
| Live | `GET /api/v1/new-broadcasts` |
| Movies | `GET /api/v1/catalog/hollywood` · `/bollywood` |
| Series | `GET /api/v1/catalog/serials` |
| Home | `GET /api/v1/catalog` |
| Images | `https://img.elochkaigolochla.com/...` |

## Features

- Dual-catalog merge with fingerprint dedupe
- Hunt Refresh
- Disk/memory cache
- Search across Elo + TMDB
- Live TV (IPTV directory + Elo broadcasts; Sports prioritized)
- In-app player only
- **Android TV / Fire Stick** D-pad + mouse focus (TV devices only — not phone/macOS/Windows)
- Wolf brand logo on splash, shell, and launcher icons

## Builds (no iOS)

```bash
./scripts/build_all.sh              # macOS + Android (+ Windows if present)
./scripts/build_all.sh android      # APK for phone + Fire Stick / Android TV
```

See [docs/BUILD.md](docs/BUILD.md) for sideload steps and platform details.

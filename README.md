# WOLFTVEE

Flat, intense Flutter streaming catalog — movies, series, live TV, search.

## Setup

```bash
cp .env.example .env
# Add your TMDB_API_KEY (and optional TRAKT_CLIENT_ID)
flutter pub get
flutter run
```

## Catalog strategy (dual source, no duplicates)

| Role | Source | Why |
|------|--------|-----|
| **Primary playback** | Elo MAPI (`mapi.elochkaigolochla.com`) | Real HLS / iframe players in catalog |
| **Primary live TV** | Elo `GET /new-broadcasts` | Only live channel API in this stack |
| **Secondary discovery** | Trakt trending → TMDB hydrate, or TMDB trending alone | Broader coverage + posters |
| **Dedupe** | Normalized `title + year + kind` | One card per title; Elo wins when both match |
| **Recency** | Elo `created_at` | “Latest uploads” rail prefers newest Elo items |
| **Gap-fill** | TMDB/Trakt-only titles | Shown under “More to explore” when Elo misses them |

### Not wired (by design)

- `vidsrc*` / `videasy` / `smashystream` embeds — third-party unauthorized stream hosts  
- FlixHQ scrapers, Mixdrop/Openload extractors, Real-Debrid / AllDebrid unlock APIs  
- Dead configs: `beetvapk.app` / `beetvapk.me` JSON  

Playback stays on **licensed Elo players** (m3u8 → media_kit, iframe → WebView). Titles that only exist on Trakt/TMDB can open trailers when TMDB has one; they do not get pirate embeds.

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
- Live TV from Elo
- In-app player only
- **Android TV / Fire Stick** D-pad + mouse focus (TV devices only — not phone/macOS/Windows)
- Wolf brand logo on splash, shell, and launcher icons

## Builds (no iOS)

```bash
./scripts/build_all.sh              # macOS + Android (+ Windows if present)
./scripts/build_all.sh android      # APK for phone + Fire Stick / Android TV
```

See [docs/BUILD.md](docs/BUILD.md) for sideload steps and platform details.

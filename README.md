# Vscous / Viscous — Bus tracker monorepo

This repository contains the **parent Flutter app** (`viscous_frontend/`) and the **Node.js API + scheduled jobs** (`viscous backend/`), which bridge Firebase (Firestore + Realtime Database) for live bus positions and route runtime.

## What “Scheduled sync completed” means

The backend job in `viscous backend/src/jobs/locationSync.job.js` runs on a timer (`LOCATION_SYNC_INTERVAL_MS`, default **6000 ms**). Each tick it calls `syncConfiguredRoute()`, which:

1. Reads the bus GPS from **Realtime Database** (`/{busId}`).
2. Reads/writes **Firestore** `route_runtime` (and `buses` when the payload changed enough to matter).
3. May send FCM notifications when the bus reaches certain stops.

A log like:

`Scheduled sync completed {"ok":true,"routeId":"...","busId":"...","stopIndex":1,"direction":-1,"status":"running"}`

means that run **finished successfully**: the configured route was processed, the bus id and indices reflect the tracker state at that moment, and `status` is the derived running/stop state from GPS freshness rules.

If you see a line such as `Scheduled sync complete` without `d`, it is the same job from the same file (`logger.info("Scheduled sync completed", result)`); wording can differ slightly if logs are truncated or the server build differs.

## Keeping Firestore reads/writes low (many users, ~20k budget)

Tuning is shared between **backend** and **clients**:

| Layer | What helps |
|--------|------------|
| **Backend** | `LOCATION_SYNC_INTERVAL_MS` — longer interval ⇒ fewer Realtime reads and fewer sync passes (writes still gated by `movementThresholdMeters` and `shouldWriteRuntime`). |
| **Backend** | `TRACKING_SNAPSHOT_CACHE_TTL_MS` (default **4000**) — parents on the **same route** share cached `GET /bus-location` snapshot data for that window, cutting repeated Firestore reads. Cache is cleared when a sync **writes** new runtime data. |
| **Backend** | Route and active-user queries are already cached (`ROUTE_CACHE_TTL_MS`, `USERS_CACHE_TTL_MS` in `busTracking.service.js`). |
| **App** | Longer polling (this app uses **12 s** auto-refresh) and pull-to-refresh throttling reduce HTTP/API load; each HTTP call still maps to backend Firestore reads. |

Rough order-of-magnitude: **50 users × one read every 12 s ≈ 250 reads/min** to Firestore **per route** if every request missed the cache. With a **4 s** snapshot cache, many of those requests hit the in-memory cache instead (one read per route per TTL window).

Set env vars in the backend `.env` (see `viscous backend/src/config/env.js`).

## Project layout

| Path | Role |
|------|------|
| `viscous_frontend/` | Flutter app (Riverpod, GoRouter, `flutter_map` map tab). |
| `viscous backend/` | Express API, Firebase Admin, location sync job. |

## Quick start

### Backend

```bash
cd "viscous backend"
npm install
# Configure Firebase + .env (see backend README)
npm start
```

### Flutter

```bash
cd viscous_frontend
flutter pub get
# Copy/configure .env (BASE_URL, etc.)
flutter run
```

More detail: `viscous_frontend/README.md` and `viscous backend/README.md`.

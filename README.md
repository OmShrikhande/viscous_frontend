# Viscous Bus Tracker Monorepo

Viscous is a parent-focused school bus tracking platform with a Flutter frontend and a Node.js backend.  
It provides live route visibility, ETA/status updates, and notification controls designed for high reliability.

## Repository Structure

| Path | Purpose |
|------|---------|
| `viscous_frontend/` | Flutter app (Riverpod, GoRouter, flutter_map, Firebase Messaging). |
| `viscous backend/` | Express API + Firebase Admin + scheduled location sync jobs. |

## App Highlights

- OTP-based authentication flow.
- Home, Map, and Profile experience optimized for quick parent decisions.
- Live bus position and stop progression.
- Smart status handling for stale/unchanged location data.
- Notification preferences and quiet-hours support.
- Confidence score/level surfaced in tracking state.

## Backend Tracking Flow

The scheduler in `viscous backend/src/jobs/locationSync.job.js` runs on `LOCATION_SYNC_INTERVAL_MS` (default `6000` ms) and executes `syncConfiguredRoute()`:

1. Reads bus GPS from Firebase Realtime Database (`/{busId}`).
2. Updates route runtime snapshots in Firestore (`route_runtime` + related state).
3. Triggers eligible FCM notifications (based on route progression and user preferences).

Log line example:

`Scheduled sync completed {"ok":true,"routeId":"...","busId":"...","stopIndex":1,"direction":-1,"status":"running"}`

This indicates the sync pass succeeded and status was computed from current runtime + freshness rules.

## Cost and Read/Write Optimization

- `LOCATION_SYNC_INTERVAL_MS`: reduces sync frequency.
- `TRACKING_SNAPSHOT_CACHE_TTL_MS` (default `4000`): reuses route snapshot for concurrent users.
- Route/user cache TTLs in `busTracking.service.js` reduce repeat Firestore reads.
- Frontend polling + pull-to-refresh throttling keeps API and Firestore pressure predictable.

## Quick Start

### Backend

```bash
cd "viscous backend"
npm install
npm start
```

Configure Firebase credentials and backend `.env` before running.

### Frontend

```bash
cd viscous_frontend
flutter pub get
flutter run
```

Configure `viscous_frontend/.env` (for example: `BASE_URL`, route/services keys, and Firebase-related values).

## Release Snapshot

- Latest local Android build command: `flutter build apk --release`
- Output artifact: `viscous_frontend/build/app/outputs/flutter-apk/app-release.apk`
- Build status: success
- APK size: `58.1 MB`

## Documentation

- Frontend details: `viscous_frontend/README.md`
- Backend details: `viscous backend/README.md`
- Phase 2 validation notes: `PHASE2_TESTING_REPORT.md`

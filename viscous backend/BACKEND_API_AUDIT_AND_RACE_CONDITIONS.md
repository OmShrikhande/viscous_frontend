# Backend API Audit and Race Condition Report

Date: 2026-05-01
Scope: `viscous backend` + frontend API integration points in `Vscous_frontend/lib/services`

## Roast (straight and direct)

- The backend is trying to run realtime transport logic with **single-process in-memory state** and no transaction boundaries. That is fragile and will break under scale, restarts, or multiple server instances.
- The scheduler is wired to one route from env, but env parsing is brittle enough that the route key can silently disappear. Result: sync loop runs and does almost nothing.
- Notification logic is ambitious, but delivery path depends on `users.fcmToken` that frontend does not upload. So "notification feature" currently behaves like a dry run in many real deployments.
- API integration in frontend is inconsistent (mixed localhost/10.0.2.2 fallbacks), so even before business logic, networking can fail by platform.

## Live API test results (executed)

Server: `http://localhost:3000`

1. `GET /` -> 200 OK
2. `GET /api/v1/health` -> 200 OK
3. `GET /api/v1/route/R-26` -> 200 OK (route found)
4. `GET /api/v1/location/current` -> 200 OK but payload had `latitude: null`, `longitude: null`
5. `POST /api/v1/location/sync` -> 200 OK but skipped with reason `"missing Route/ROUTE_NUMBER env"`
6. `POST /api/v1/auth/login` with `phone=1234567890` -> 200 OK, token + user returned
7. `GET /api/v1/location/bus-location` with auth token -> 200 OK

## Broken logic (must-fix)

### P1-1: Scheduler route env not reliably loaded
- File: `src/config/env.js`
- Symptom: sync endpoint returns `"missing Route/ROUTE_NUMBER env"` even when `.env` appears to contain `Route=...`.
- Why broken: `.env` format is effectively malformed by large multiline JSON value; parsing ends before route key.
- Impact: no reliable scheduled route sync.
- Fix:
  - Move service account JSON out of `.env` into a JSON file path env key.
  - Use only uppercase `ROUTE_NUMBER`.
  - Fail fast on startup if route sync is enabled and route number is missing.

### P1-2: Stop proximity fallback can produce wrong stop progression
- File: `src/services/busTracking.service.js`
- Current logic:
  - If bus is outside 100m, `stopIndex` falls back to previous runtime index or `0`.
- Impact:
  - On cold start with out-of-area location, system assumes stop `0`.
  - Can trigger incorrect notifications and wrong ETA state.
- Fix:
  - Keep `currentStopIndex = null` until first confirmed in-area stop.
  - Gate notifications behind confirmed progress state.

### P1-3: Empty route stops can crash sync
- File: `src/services/busTracking.service.js`
- `reduce` starts with `routeStops[0]`; if no stops exist, logic becomes invalid.
- Impact: sync crash for malformed/incomplete route records.
- Fix: guard `if (!routeStops.length) return skipped("route has no stops")`.

### P1-4: Public sync endpoint when internal key is empty
- File: `src/middlewares/internalApiGuard.js`
- If `INTERNAL_API_KEY` is empty, guard bypasses auth.
- Impact: any client can call sync endpoint, causing load and potential state churn.
- Fix: require key in production; reject startup without it.

### P1-5: Frontend does not push FCM token to backend users
- Frontend files: `lib/services/push_notification_service.dart` + no corresponding user token sync API usage
- Backend notification send requires `users.fcmToken`.
- Impact: stop notifications often never sent to real devices.
- Fix:
  - Add authenticated endpoint: `PATCH /api/v1/users/me/fcm-token`.
  - On login/app start, frontend uploads current FCM token.

## Race conditions and consistency risks

### RC-1: Global in-memory lock (`isSyncRunning`) is process-local only
- File: `src/services/busTracking.service.js`
- Works only in one Node process.
- In multi-instance deployment, two instances can sync same route concurrently.
- Fix:
  - Use Firestore lease/lock doc with TTL and compare-and-set semantics.
  - Or move to Cloud Scheduler + single worker semantics.

### RC-2: In-memory runtime state (`busRuntime`) lost on restart
- File: `src/services/busTracking.service.js`
- `lastChangeAt`, `lastNotifiedStop` reset on process restart.
- Impact: duplicate/missed notifications and wrong running/stopped state after reboot.
- Fix:
  - Persist runtime state in Firestore (`route_runtime`) and read it every cycle.
  - Keep in-memory cache as optimization only.

### RC-3: Non-transactional multi-write flow
- File: `src/services/busTracking.service.js`
- Writes happen across:
  - `buses/{busId}`
  - `route_runtime/{routeId}`
  - notification logs + FCM send
- Partial failure can leave inconsistent state.
- Fix:
  - Use Firestore transaction/batch for state docs.
  - Use outbox pattern for notifications (write event doc first, worker sends idempotently).

### RC-4: Notification dedupe is weak
- File: `src/services/busTracking.service.js`
- Dedupe relies on in-memory `lastNotifiedStop`.
- Multi-instance or restart can resend same stop alerts.
- Fix:
  - Persist sent events by `(routeId, stopIndex, eventType, userId)` key.
  - Skip sending if event already exists.

### RC-5: Running/stopped detection uses exact coordinate equality
- File: `src/services/busTracking.service.js`
- GPS jitter means tiny coordinate drift can keep status `running` forever.
- Fix:
  - Treat movement below threshold (e.g., <10m over 30s) as not moving.

## Frontend API integration issues

### FI-1: Base URL fallback inconsistency
- `lib/services/api_service.dart` -> fallback `10.0.2.2`
- `lib/services/auth_service.dart` -> fallback `localhost`
- `lib/services/location_service.dart` -> fallback `localhost`
- Impact: one API may work while others fail on emulator/device.
- Fix: centralize one `ApiConfig.baseUrl`.

### FI-2: Auth persistence bootstrap gap
- `authStateProvider` defaults false with no startup restore from saved token.
- Impact: user appears logged out after restart despite local storage containing login data.
- Fix: add app bootstrap to read token/login data and initialize auth provider.

### FI-3: Tracking state marks route started too eagerly
- In `lib/app_state.dart`, polling success marks `routeStarted: true` without robust backend state checks.
- Fix: derive route state strictly from backend status flags.

## Priority action plan

1. Normalize env strategy (service account file path + required `ROUTE_NUMBER` + strict startup validation).
2. Add Firestore-backed lease lock and persisted runtime dedupe keys.
3. Transactionalize state updates and implement notification outbox worker.
4. Add FCM token registration API and frontend upload flow.
5. Fix frontend base URL centralization and auth bootstrap.

## Quick verification checklist after fixes

- Sync runs with non-empty `ROUTE_NUMBER` and updates `route_runtime`.
- Same location for 30s sets `buses/{id}.status = stop`.
- Crossing a stop triggers exactly one notification event per user/event type.
- Restart server does not duplicate previous stop notifications.
- Android emulator can login + fetch route + fetch bus location using one shared base URL.

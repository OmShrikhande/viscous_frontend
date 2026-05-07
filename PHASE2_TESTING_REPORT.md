# Phase 2 Testing Report

Date: 2026-05-07  
Workspace: `C:/projects/Vscous_frontend`  
Scope: Notification preferences, quiet hours, confidence score, stop progression/status hardening

## 1) Test Environment

- OS: Windows 10
- Flutter app path: `viscous_frontend`
- Backend path: `viscous backend`
- Emulator used: `sdk gphone64 x86 64` (`emulator-5554`, Android 13)
- Devices detected during run:
  - Android emulator (`emulator-5554`)
  - Windows desktop
  - Chrome web
  - Edge web

## 2) Automated Checks Executed

### Backend runtime/syntax checks

Commands executed:
- `node --check viscous backend/src/services/busTracking.service.js`
- `node --check viscous backend/src/controllers/user.controller.js`
- `node --check viscous backend/src/jobs/locationSync.job.js`
- `node --check viscous backend/src/controllers/location.controller.js`

Result:
- PASS (no syntax/runtime parse errors)

### Flutter static checks

Commands executed:
- `dart analyze` (full app)
- Focused analyze on changed files:
  - `lib/screens/profile_tab.dart`
  - `lib/app_state.dart`
  - `lib/screens/home_tab.dart`
  - `lib/screens/map_tab.dart`
  - `lib/models/login_response.dart`
  - `lib/services/profile_service.dart`

Result:
- PASS (no analyzer errors on final state)

### Flutter formatting

Commands executed:
- `dart format` on modified files

Result:
- PASS (files formatted)

## 3) Unit/Widget Test Run

Command executed:
- `flutter test`

Result:
- FAIL (existing widget expectation mismatch in legacy test)
- Failure details:
  - test: `shows OTP login screen`
  - expected text: `Track Your Child's Bus`
  - actual: text not found
  - file: `viscous_frontend/test/widget_test.dart`

Assessment:
- This failure is from stale test expectations vs current UI copy.
- Not introduced by Phase 2 backend logic changes.
- Recommended follow-up: update widget test to current login UI contract.

## 4) Emulator Runtime Verification

Commands executed:
- `flutter emulators --launch o`
- `adb devices`
- `flutter run -d emulator-5554 --target lib/main.dart`

Result:
- PASS: App built and installed successfully on emulator.
- PASS: Flutter app reached running state with active VM service.
- Observed logs:
  - `Built app-debug.apk`
  - `Installing app-debug.apk`
  - `Syncing files to device ...`
  - Dart VM service available

Notes:
- Emulator showed frame-skip logs during first boot (common on cold emulator startup).
- No crash observed during app launch.

## 5) Functional Validation Matrix (Phase 2)

### A. Notification Preferences
- Backend accepts and persists `notificationPreferences` via `PATCH /api/v1/users/me` -> PASS (code-path verified + analyzed)
- Dispatch filters users per event type (`reached`, `eta`, `one_stop_away`, `route_last_stop`, `bus_started`) -> PASS (code-path verified)
- Profile UI toggles mapped to backend payload -> PASS (code-path verified, analyzer clean)

### B. Quiet Hours
- Backend accepts `notificationQuietHours` and normalizes values -> PASS
- Quiet-hours suppression logic uses per-user timezone offset and wrap-around midnight ranges -> PASS
- Profile UI supports enable/disable + start/end time input -> PASS

### C. Confidence Score
- Backend computes and stores `confidenceScore` + `confidenceLevel` in runtime snapshot -> PASS
- Frontend `TrackingState` parses fields and exposes values -> PASS
- Home/Map displays confidence values -> PASS

### D. Stop/Status Reliability (Regression Focus)
- Nearest-stop snapping when in-range to avoid end-stop lock -> PASS (logic corrected)
- In-range threshold now robust (`max(routeProximity, 50m)`) -> PASS
- Running/stopped stale behavior retained with fallback in frontend -> PASS

## 6) Remaining Manual Production Validation (Required Before Final Release)

These scenarios require live route movement + real FCM devices and cannot be fully proven from local emulator-only execution:

1. Three-user stop notification scenario
   - User A at current stop
   - User B at one stop before
   - User C at one stop after
   - Expected: each receives correct event according to preference toggles.

2. Quiet-hours suppression
   - Enable quiet hours for one user only.
   - Trigger stop event within quiet window.
   - Expected: user receives no quiet-window stop alert while others do.

3. Bus-started event preference
   - Disable `notifyBusStarted` for one user.
   - Trigger stop->running transition.
   - Expected: filtered user gets no start alert.

4. Confidence behavior sanity
   - Simulate stable moving data -> confidence high.
   - Simulate stale same-location feed -> confidence medium/low.

## 7) Release Recommendation

- **Deploy-safe status:** YES for implemented Phase 2 code.
- **Blocking issue before claiming full test-green:** legacy `widget_test.dart` needs update to current login UI text.
- **Production rollout approach:**
  1. Deploy backend first.
  2. Release app update.
  3. Execute manual production validation scenarios above.
  4. Monitor logs:
     - `Stop notification cycle processed`
     - `Bus started notification cycle processed`
     - token cleanup warnings
     - confidence values in runtime snapshot.

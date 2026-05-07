# Viscous Code Roast (With Love)

## The Roast

- The notification pipeline was acting confident while notifying almost nobody. Logs said "success", but recipient selection was underpowered (strict stop matching + narrow route lookup).
- Token handling was "single-device optimism": one `fcmToken` field in 2026 for users with multiple phones/logins is asking for silent delivery failures.
- Sync loop was a caffeine addict: fixed-interval polling with no adaptive backoff meant constant churn even when the bus stood still.
- Status semantics were too binary and trusting. "Data arrived" got conflated with "bus is running", which caused misleading UX on Home.
- There was good logging, but not enough outcome-level signal for delivery reliability (invalid token cleanup, route audience size drift, etc.).

## What Was Upgraded

- Multi-token support per user (`fcmTokens[]` + canonical `fcmToken`) for reliable multi-device delivery.
- Invalid token pruning after FCM send responses, reducing future failure noise.
- Route user targeting now supports both `routeId` and `routeNumber` storage patterns.
- Stop matching is tolerant of punctuation/case/format mismatch and numeric stop input.
- Scheduler now supports adaptive idle cooldown, reducing unnecessary sync load when bus remains stationary.
- Client added a safety fallback: stale + unchanged location can no longer display a false RUNNING state.

## My Views (Direct and Practical)

- **Good foundation, weak contracts:** the architecture is workable, but the data contracts between user profile, route identity, and tracking events were too loose.
- **Observability needs to be product-grade:** add counters for `attemptedUsers`, `matchedUsers`, `tokenCount`, `invalidTokenPruned`, and alert on unusual drops.
- **Status should be state-machine-driven:** replace ad-hoc booleans with explicit states (`idle`, `running`, `at_stop`, `offline`, `completed`) and clear transitions.
- **Move from polling to event-first where possible:** RTDB/Firestore triggers or pub/sub can reduce latency and infra cost compared to tight loops.
- **Treat notifications as a reliability feature, not UI feature:** delivery should be verified with retry, dead-letter metrics, and device/session visibility.

## Extraordinary Next Features (Recommended)

1. **Per-user notification preferences**
   - Toggle: current stop / one-stop-away / bus-started / terminal alerts.
2. **Quiet hours + escalation**
   - Non-urgent alerts muted at night; missed critical stop alerts escalate with stronger priority.
3. **Bus heartbeat confidence score**
   - Expose confidence based on freshness + movement + GPS jitter so users know if feed quality is degraded.
4. **Guaranteed catch-up notification**
   - If device was offline, send "missed while offline" digest when token reconnects.
5. **Operator anomaly dashboard**
   - Flag unusual dwell time, repeated same-coordinate streaks, route deviation, and token health.

## Immediate Operational Checklist

- Deploy backend changes to Render.
- Release app build with token-refresh + status fallback.
- Confirm users docs now include `fcmTokens`.
- Run one round-trip test with 3+ users on different stops and one user with app in background/locked.
- Inspect logs for:
  - `Stop notification cycle processed` with realistic `attemptedUsers`.
  - `Bus started notification cycle processed`.
  - `Invalid FCM tokens pruned` (initially expected on old devices/tokens).

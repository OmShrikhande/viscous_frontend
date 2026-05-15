import { firestoreDb, realtimeDb } from "../config/firebaseAdmin.js";
import { env } from "../config/env.js";
import { logger } from "../utils/logger.js";

const routeCache = new Map();
const usersCache = new Map();
/** routeId -> { payload, cachedAt } — shared across users on the same route (reduces read bursts). */
const trackingSnapshotCache = new Map();
let isSyncRunning = false;

const ROUTE_CACHE_TTL_MS = 60_000;
const USERS_CACHE_TTL_MS = 30_000;
const INVALID_FCM_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered"
]);
const DEFAULT_NOTIFICATION_PREFERENCES = {
  notifyReached: true,
  notifyEta: true,
  notifyOneStopAway: true,
  notifyRouteLastStop: true,
  notifyBusStarted: true
};

const toRadians = (degrees) => (degrees * Math.PI) / 180;

const distanceMeters = (lat1, lon1, lat2, lon2) => {
  const earthRadius = 6_371_000;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadius * c;
};

const normalizeStop = (stop, index) => ({
  index,
  name: stop.name ?? `Stop ${index + 1}`,
  latitude: Number(stop?.coordinates?.[0]),
  longitude: Number(stop?.coordinates?.[1]),
  coordinates: [Number(stop?.coordinates?.[0]), Number(stop?.coordinates?.[1])]
});

const normalizeStopLabel = (value) =>
  String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const resolveUserStopIndex = (routeStops, userStop) => {
  if (!userStop) return -1;
  const normalized = normalizeStopLabel(userStop);
  if (!normalized) return -1;

  const exactMatch = routeStops.findIndex((s) => normalizeStopLabel(s.name) === normalized);
  if (exactMatch >= 0) return exactMatch;

  // Accept minor naming differences (extra words / punctuation) from profile data.
  const fuzzyMatch = routeStops.findIndex((s) => {
    const stopName = normalizeStopLabel(s.name);
    return stopName.includes(normalized) || normalized.includes(stopName);
  });
  if (fuzzyMatch >= 0) return fuzzyMatch;

  // Support numeric stop value entered in user profile (1-based preferred).
  const parsed = Number(normalized);
  if (Number.isInteger(parsed)) {
    if (parsed >= 1 && parsed <= routeStops.length) return parsed - 1;
    if (parsed >= 0 && parsed < routeStops.length) return parsed;
  }

  return -1;
};

const buildOrderedStops = (routeStops, direction) => {
  if (direction === -1) {
    return [...routeStops].reverse();
  }
  return routeStops;
};

const computeDisplayIndex = (currentStopIndex, stopCount, direction) => {
  if (stopCount <= 0 || currentStopIndex < 0) return 0;
  if (direction === -1) {
    return stopCount - 1 - currentStopIndex;
  }
  return currentStopIndex;
};

const parseTimeToMinutes = (value) => {
  const text = String(value ?? "").trim();
  const match = /^(\d{1,2}):(\d{2})$/.exec(text);
  if (!match) return null;
  const hh = Number(match[1]);
  const mm = Number(match[2]);
  if (!Number.isInteger(hh) || !Number.isInteger(mm)) return null;
  if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return null;
  return hh * 60 + mm;
};

const isWithinQuietHours = (user, nowMs) => {
  const quiet = user?.notificationQuietHours;
  if (!quiet || quiet.enabled !== true) return false;
  const startMinutes = parseTimeToMinutes(quiet.start);
  const endMinutes = parseTimeToMinutes(quiet.end);
  if (startMinutes === null || endMinutes === null || startMinutes === endMinutes) return false;
  const offset = Number(quiet.timezoneOffsetMinutes ?? 330);
  const offsetMinutes = Number.isFinite(offset) ? Math.max(-720, Math.min(840, offset)) : 330;
  const utcMinutes = Math.floor(nowMs / 60_000) % 1_440;
  const localMinutes = (utcMinutes + offsetMinutes + 1_440) % 1_440;
  if (startMinutes < endMinutes) {
    return localMinutes >= startMinutes && localMinutes < endMinutes;
  }
  return localMinutes >= startMinutes || localMinutes < endMinutes;
};

const getUserNotificationPreferences = (user) => {
  const prefs = user?.notificationPreferences;
  if (!prefs || typeof prefs !== "object") return DEFAULT_NOTIFICATION_PREFERENCES;
  const pick = (key) => (typeof prefs[key] === "boolean" ? prefs[key] : DEFAULT_NOTIFICATION_PREFERENCES[key]);
  return {
    notifyReached: pick("notifyReached"),
    notifyEta: pick("notifyEta"),
    notifyOneStopAway: pick("notifyOneStopAway"),
    notifyRouteLastStop: pick("notifyRouteLastStop"),
    notifyBusStarted: pick("notifyBusStarted")
  };
};

const userAllowsEventNotification = (user, eventKey, nowMs) => {
  if (isWithinQuietHours(user, nowMs)) return false;
  const prefs = getUserNotificationPreferences(user);
  if (eventKey === "reached") return prefs.notifyReached;
  if (eventKey === "eta") return prefs.notifyEta;
  if (eventKey === "one_stop_away") return prefs.notifyOneStopAway;
  if (eventKey === "route_last_stop") return prefs.notifyRouteLastStop;
  if (eventKey === "bus_started") return prefs.notifyBusStarted;
  return true;
};

const computeTrackingConfidence = ({
  staleDurationMs,
  movedMeters,
  nearestStopDistanceMeters,
  withinRouteArea,
  isRunning
}) => {
  let score = 100;
  const stalePenalty = Math.min(45, (staleDurationMs / 1000) * 1.2);
  score -= stalePenalty;
  if (!withinRouteArea) score -= 20;
  if (isRunning && movedMeters < env.scheduler.movementThresholdMeters) score -= 15;
  score -= Math.min(15, Number(nearestStopDistanceMeters ?? 0) / 20);
  score = Math.max(5, Math.min(100, Math.round(score)));
  const level = score >= 75 ? "high" : score >= 45 ? "medium" : "low";
  return { score, level };
};

const getRouteByNumber = async (routeNumber) => {
  const cacheHit = routeCache.get(routeNumber);
  if (cacheHit && Date.now() - cacheHit.cachedAt < ROUTE_CACHE_TTL_MS) {
    return cacheHit.route;
  }

  const routeSnap = await firestoreDb
    .collection("routes")
    .where("routeNumber", "==", routeNumber)
    .limit(1)
    .get();

  if (routeSnap.empty) return null;
  const routeDoc = routeSnap.docs[0];
  const route = { id: routeDoc.id, ...routeDoc.data() };
  routeCache.set(routeNumber, { route, cachedAt: Date.now() });
  return route;
};

const getActiveUsersByRoute = async (route) => {
  const routeId = route.id;
  const routeNumber = route.routeNumber;
  const cacheKey = `${routeId}:${routeNumber ?? ""}`;
  const cacheHit = usersCache.get(cacheKey);
  if (cacheHit && Date.now() - cacheHit.cachedAt < USERS_CACHE_TTL_MS) {
    return cacheHit.users;
  }

  const activeByRouteIdSnap = await firestoreDb
    .collection("users")
    .where("route", "==", routeId)
    .where("status", "==", "active")
    .get();

  // Backward compatibility: some users store routeNumber instead of route document id.
  let activeByRouteNumberSnap = null;
  if (routeNumber) {
    activeByRouteNumberSnap = await firestoreDb
      .collection("users")
      .where("route", "==", routeNumber)
      .where("status", "==", "active")
      .get();
  }

  const merged = new Map();
  for (const doc of activeByRouteIdSnap.docs) {
    merged.set(doc.id, { id: doc.id, ...doc.data() });
  }
  for (const doc of activeByRouteNumberSnap?.docs ?? []) {
    if (!merged.has(doc.id)) {
      merged.set(doc.id, { id: doc.id, ...doc.data() });
    }
  }

  const users = Array.from(merged.values());
  usersCache.set(cacheKey, { users, cachedAt: Date.now() });
  return users;
};

const sendUsersNotification = async ({ routeId, title, body, users, data = {} }) => {
  if (!users.length) {
    return {
      attemptedUsers: 0,
      attemptedTokens: 0,
      successCount: 0,
      failureCount: 0,
      skipped: true,
      reason: "no_users"
    };
  }
  const tokenToUserIds = new Map();
  const tokens = [];
  for (const user of users) {
    const normalizedTokens = Array.from(
      new Set(
        [
          ...(Array.isArray(user.fcmTokens) ? user.fcmTokens : []),
          user.fcmToken
        ].filter((token) => typeof token === "string" && token.trim().length > 0)
      )
    );
    for (const token of normalizedTokens) {
      if (!tokenToUserIds.has(token)) {
        tokenToUserIds.set(token, new Set());
        tokens.push(token);
      }
      tokenToUserIds.get(token).add(user.id);
    }
  }
  if (!tokens.length) {
    logger.warn("Notification skipped: no FCM tokens", {
      routeId,
      title,
      users: users.map((u) => u.id)
    });
    return {
      attemptedUsers: users.length,
      attemptedTokens: 0,
      successCount: 0,
      failureCount: 0,
      skipped: true,
      reason: "no_tokens"
    };
  }

  try {
    const app = (await import("firebase-admin/app")).getApp();
    const messaging = (await import("firebase-admin/messaging")).getMessaging(app);
    const response = await messaging.sendEachForMulticast({
      notification: { title, body },
      data: {
        routeId,
        ...Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v ?? "")]))
      },
      android: {
        priority: "high",
        ttl: 1000 * 60 * 60 * 6
      },
      apns: {
        headers: {
          "apns-priority": "10"
        }
      },
      tokens
    });

    const invalidTokenOwners = new Map();
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = String(result.error?.code ?? "");
      if (!INVALID_FCM_CODES.has(code)) return;
      const token = tokens[index];
      const ownerIds = tokenToUserIds.get(token);
      if (!ownerIds) return;
      for (const userId of ownerIds) {
        if (!invalidTokenOwners.has(userId)) invalidTokenOwners.set(userId, new Set());
        invalidTokenOwners.get(userId).add(token);
      }
    });

    if (invalidTokenOwners.size > 0) {
      const cleanupBatch = firestoreDb.batch();
      for (const [userId, invalidTokens] of invalidTokenOwners.entries()) {
        const user = users.find((u) => u.id === userId);
        if (!user) continue;
        const cleaned = Array.from(
          new Set(
            [
              ...(Array.isArray(user.fcmTokens) ? user.fcmTokens : []),
              user.fcmToken
            ]
              .filter((token) => typeof token === "string" && token.trim().length > 0)
              .filter((token) => !invalidTokens.has(token))
          )
        );
        cleanupBatch.set(
          firestoreDb.collection("users").doc(userId),
          {
            fcmTokens: cleaned,
            fcmToken: cleaned[0] ?? null,
            fcmTokenUpdatedAt: new Date().toISOString()
          },
          { merge: true }
        );
      }
      await cleanupBatch.commit();
      logger.warn("Invalid FCM tokens pruned", {
        routeId,
        affectedUsers: invalidTokenOwners.size
      });
    }

    return {
      attemptedUsers: users.length,
      attemptedTokens: tokens.length,
      successCount: response.successCount,
      failureCount: response.failureCount,
      skipped: false
    };
  } catch (error) {
    logger.error("FCM send failed", { routeId, error: error.message });
    return {
      attemptedUsers: users.length,
      attemptedTokens: tokens.length,
      successCount: 0,
      failureCount: tokens.length,
      skipped: false,
      reason: "fcm_error"
    };
  }
};

/**
 * Acquires the route's distributed lock AND returns the current runtime data
 * in a single Firestore transaction. The lock lives on the `route_runtime` doc
 * itself (no separate `route_sync_locks` collection) — saves one read + one
 * write per sync cycle vs. the previous design.
 *
 * Returns { acquired, runtimeData, runtimeRef } so the caller can reuse the
 * runtime payload without a second read.
 */
const acquireRouteLockAndRuntime = async (routeId) => {
  const runtimeRef = firestoreDb.collection("route_runtime").doc(routeId);
  const now = Date.now();
  // Hold the lock just long enough to cover one cycle plus a small buffer.
  const lockUntilMs = now + Math.max(env.scheduler.selfCallIntervalMs + 1_000, 7_000);

  let acquired = false;
  let runtimeData = {};

  await firestoreDb.runTransaction(async (tx) => {
    const doc = await tx.get(runtimeRef);
    const data = doc.exists ? doc.data() : {};
    const currentLockUntil = Number(data?.lockUntilMs ?? 0);
    if (currentLockUntil > now) {
      acquired = false;
      runtimeData = data;
      return;
    }
    acquired = true;
    runtimeData = data;
    tx.set(runtimeRef, { lockUntilMs }, { merge: true });
  });

  return { acquired, runtimeData, runtimeRef };
};

const updateRoundTripState = ({ routeStops, runtimeData, nearestStopIndex, withinRouteArea }) => {
  const stopCount = routeStops.length;
  let currentStopIndex = Number.isInteger(runtimeData.currentStopIndex) ? runtimeData.currentStopIndex : 0;
  let direction = runtimeData.direction === -1 ? -1 : 1;
  let roundsCompleted = Number(runtimeData.roundsCompleted ?? 0);

  if (withinRouteArea) {
    // Snap to nearest in-range stop so runtime state cannot get stuck
    // at an endpoint when GPS already moved near a middle stop.
    // Prevent snapping to the end of the route if the daily reset just happened 
    // and the bus hasn't started its daily trip yet.
    if (runtimeData.hasStartedDailyTrip !== false || nearestStopIndex === 0) {
      currentStopIndex = nearestStopIndex;
    }
  }

  if (currentStopIndex >= stopCount - 1 && direction === 1) {
    direction = -1;
  } else if (currentStopIndex <= 0 && direction === -1) {
    direction = 1;
    roundsCompleted += 1;
  }

  const nextStopIndex = direction === 1
    ? Math.min(currentStopIndex + 1, stopCount - 1)
    : Math.max(currentStopIndex - 1, 0);

  return { currentStopIndex, nextStopIndex, direction, roundsCompleted };
};

const shouldWriteRuntime = (previous, next) => {
  if (!previous) return true;
  const moved = distanceMeters(
    Number(previous.latitude ?? 0),
    Number(previous.longitude ?? 0),
    Number(next.latitude ?? 0),
    Number(next.longitude ?? 0)
  );
  if (moved >= env.scheduler.movementThresholdMeters) return true;
  if (previous.currentStopIndex !== next.currentStopIndex) return true;
  if (previous.direction !== next.direction) return true;
  if (previous.status !== next.status) return true;
  if (previous.lastResetDate !== next.lastResetDate) return true;
  if (previous.hasStartedDailyTrip !== next.hasStartedDailyTrip) return true;
  return false;
};

const buildSnapshotPayload = (runtimeData, routeStops, routeMeta) => {
  const direction = runtimeData.direction === -1 ? -1 : 1;
  const orderedStops = buildOrderedStops(routeStops, direction);
  const currentStopIndex = Number(runtimeData.currentStopIndex ?? 0);
  const displayIndex = computeDisplayIndex(currentStopIndex, routeStops.length, direction);

  return {
    ...runtimeData,
    routeMeta,
    routeStops,
    orderedStops,
    currentDisplayIndex: displayIndex
  };
};

const fetchSnapshotBaseFromFirestore = async (routeId) => {
  const runtimeDoc = await firestoreDb.collection("route_runtime").doc(routeId).get();
  const runtimeData = runtimeDoc.exists ? runtimeDoc.data() : {};
  const runtimeStops = Array.isArray(runtimeData.routeStops) ? runtimeData.routeStops : [];
  let routeStops = runtimeStops;
  let routeMeta = runtimeData.routeMeta;

  if (!routeStops.length || !routeMeta) {
    const routeDoc = await firestoreDb.collection("routes").doc(routeId).get();
    if (!routeDoc.exists) {
      throw new Error("Route not found for current user");
    }
    const route = { id: routeDoc.id, ...routeDoc.data() };
    routeStops = (route.stops ?? []).map(normalizeStop);
    routeMeta = {
      id: route.id,
      routeNumber: route.routeNumber,
      busId: route.busId,
      from: route.from,
      to: route.to,
      college: route.college
    };
  }

  return buildSnapshotPayload(runtimeData, routeStops, routeMeta);
};

export const getTrackingSnapshotForUser = async ({ routeId, userStop }) => {
  const ttl = env.trackingSnapshotCacheTtlMs;
  const now = Date.now();
  const cached = trackingSnapshotCache.get(routeId);
  let base =
    cached && now - cached.cachedAt < ttl ? cached.payload : null;

  if (!base) {
    base = await fetchSnapshotBaseFromFirestore(routeId);
    trackingSnapshotCache.set(routeId, { payload: base, cachedAt: now });
  }

  const routeStops = base.routeStops ?? [];
  // Strip lock metadata from response — it's an internal field.
  const { lockUntilMs, ...publicBase } = base;
  return {
    ...publicBase,
    userStop,
    userStopIndex: resolveUserStopIndex(routeStops, userStop)
  };
};

export const syncConfiguredRoute = async () => {
  if (isSyncRunning) {
    return { skipped: true, reason: "sync already running" };
  }
  isSyncRunning = true;

  let acquiredRuntimeRef = null;
  try {
    const routeNumber = env.scheduler.routeNumber;
    if (!routeNumber) {
      return { skipped: true, reason: "missing ROUTE_NUMBER env" };
    }
    const route = await getRouteByNumber(routeNumber);
    if (!route) {
      return { skipped: true, reason: `route not found: ${routeNumber}` };
    }
    if (!route.busId) {
      return { skipped: true, reason: `route ${routeNumber} has no busId` };
    }

    const routeStops = (route.stops ?? []).map(normalizeStop);
    if (!routeStops.length) {
      return { skipped: true, reason: "route has no stops" };
    }

    // Single transaction: acquire lock + read runtime data (was 2 separate ops).
    const { acquired, runtimeData, runtimeRef } = await acquireRouteLockAndRuntime(route.id);
    if (!acquired) {
      return { skipped: true, reason: "route sync lock busy" };
    }
    acquiredRuntimeRef = runtimeRef;

    // Apply Daily Reset if needed (Home -> College at start of day)
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(Date.now() + istOffset);
    const istHour = istNow.getUTCHours();
    const istDate = istNow.toISOString().split("T")[0];

    let effectiveRuntimeData = runtimeData;
    if (istHour >= 4 && runtimeData.lastResetDate !== istDate) {
      logger.info("Applying daily route reset", { routeId: route.id, istDate });
      
      const resetPayload = {
        direction: 1,
        currentStopIndex: 0,
        roundsCompleted: 0,
        lastResetDate: istDate,
        lastNotifiedKey: "",
        status: "stop",
        busStatus: "stop",
        hasStartedDailyTrip: false,
        latitude: null,
        longitude: null,
        speedKmh: 0,
        staleTicks: 0
      };

      // 1. Immediately save the clean reset state to Firestore
      await acquiredRuntimeRef.set(resetPayload, { merge: true });
      
      // 2. Delete the stale realtime GPS data to prevent snapping to yesterday's location
      await realtimeDb.ref(`/${route.busId}`).remove();
      
      return { 
        ok: true, 
        reason: "Daily reset applied and realtime data cleared",
        routeId: route.id,
        direction: 1,
        stopIndex: 0
      };
    }

    const realtimeSnapshot = await realtimeDb.ref(`/${route.busId}`).get();
    const realtimeData = realtimeSnapshot.val();
    if (!realtimeData) {
      return { skipped: true, reason: `missing realtime location for ${route.busId}` };
    }

    const latitude = Number(realtimeData.latitude);
    const longitude = Number(realtimeData.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return { skipped: true, reason: "invalid realtime coordinates" };
    }

    const now = Date.now();

    const prevLat = Number(effectiveRuntimeData.latitude ?? latitude);
    const prevLng = Number(effectiveRuntimeData.longitude ?? longitude);
    const movedMeters = distanceMeters(prevLat, prevLng, latitude, longitude);
    const lastChangeAtMs = Number(effectiveRuntimeData.lastChangeAtMs ?? now);
    const hasMoved = movedMeters >= env.scheduler.movementThresholdMeters;
    
    if (hasMoved) {
      effectiveRuntimeData.hasStartedDailyTrip = true;
    }

    const effectiveLastChangeAt = hasMoved ? now : lastChangeAtMs;
    const staleTicks = hasMoved ? 0 : Number(effectiveRuntimeData.staleTicks ?? 0) + 1;
    const staleDurationMs = staleTicks * env.scheduler.selfCallIntervalMs;
    const reachedStaleThreshold = staleDurationMs >= env.scheduler.staleLocationMs;
    const previousStopIndex = Number(effectiveRuntimeData.currentStopIndex ?? 0);
    const isRunning = !reachedStaleThreshold;
    const lastUpdatedMs = effectiveRuntimeData.updatedAt ? new Date(effectiveRuntimeData.updatedAt).getTime() : now;
    const elapsedSeconds = Math.max((now - lastUpdatedMs) / 1000, 1);

    // Smoothed speed (km/h): blend instantaneous reading with previous so a single
    // GPS jitter doesn't whip the gauge around.
    const instantSpeedKmh = Math.min((movedMeters / elapsedSeconds) * 3.6, 120);
    const prevSpeedKmh = Number(effectiveRuntimeData.speedKmh ?? 0);
    const smoothedSpeedKmh = isRunning
      ? Number((prevSpeedKmh * 0.55 + instantSpeedKmh * 0.45).toFixed(1))
      : 0;

    const nearestStop = routeStops.reduce(
      (acc, stop) => {
        const meters = distanceMeters(latitude, longitude, stop.latitude, stop.longitude);
        return meters < acc.meters ? { stop, meters } : acc;
      },
      { stop: routeStops[0], meters: Number.POSITIVE_INFINITY }
    );
    const exactStopMatch =
      routeStops[nearestStop.stop.index].latitude === latitude &&
      routeStops[nearestStop.stop.index].longitude === longitude;
    const effectiveRouteProximityMeters = Math.max(env.scheduler.routeProximityMeters, 50);
    const withinRouteArea = exactStopMatch || nearestStop.meters <= effectiveRouteProximityMeters;

    const roundTripState = updateRoundTripState({
      routeStops,
      runtimeData: effectiveRuntimeData,
      nearestStopIndex: nearestStop.stop.index,
      withinRouteArea
    });

    const currentStop = routeStops[roundTripState.currentStopIndex] ?? null;
    const nextStop = routeStops[roundTripState.nextStopIndex] ?? null;
    const displayIndex = computeDisplayIndex(
      roundTripState.currentStopIndex,
      routeStops.length,
      roundTripState.direction
    );

    // ETA to next stop using current bus position + smoothed speed.
    // Fallback to a sane minimum (~1 min) so UI never shows 0 while bus is en route.
    const distanceToNextMeters = nextStop
      ? distanceMeters(latitude, longitude, nextStop.latitude, nextStop.longitude)
      : 0;
    const etaSpeedKmh = Math.max(smoothedSpeedKmh, 8); // assume 8 km/h floor for stop-and-go
    const etaToNextSeconds =
      !nextStop || roundTripState.currentStopIndex === roundTripState.nextStopIndex
        ? 0
        : Math.round((distanceToNextMeters / 1000) / etaSpeedKmh * 3600);
    const etaToNextMinutes = etaToNextSeconds === 0
      ? 0
      : Math.max(1, Math.min(60, Math.round(etaToNextSeconds / 60)));

    const nextPayload = {
      routeId: route.id,
      routeNumber: route.routeNumber,
      busId: route.busId,
      status: isRunning ? "running" : "stop",
      busStatus: isRunning ? "running" : "stop",
      latitude,
      longitude,
      speedKmh: smoothedSpeedKmh,
      nearestStopDistanceMeters: Math.round(nearestStop.meters),
      distanceToNextStopMeters: Math.round(distanceToNextMeters),
      etaToNextSeconds,
      etaToNextMinutes,
      effectiveRouteProximityMeters,
      withinRouteArea,
      direction: roundTripState.direction,
      roundsCompleted: roundTripState.roundsCompleted,
      routeMeta: {
        id: route.id,
        routeNumber: route.routeNumber,
        busId: route.busId,
        from: route.from,
        to: route.to,
        college: route.college
      },
      routeStops,
      currentStopIndex: roundTripState.currentStopIndex,
      nextStopIndex: roundTripState.nextStopIndex,
      currentDisplayIndex: displayIndex,
      currentStop: currentStop?.name ?? null,
      nextStop: nextStop?.name ?? null,
      isAtLastStop: roundTripState.currentStopIndex === routeStops.length - 1,
      lastChangeAtMs: effectiveLastChangeAt,
      staleTicks,
      updatedAt: new Date().toISOString()
    };
    const confidence = computeTrackingConfidence({
      staleDurationMs,
      movedMeters,
      nearestStopDistanceMeters: Math.round(nearestStop.meters),
      withinRouteArea,
      isRunning
    });
    nextPayload.confidenceScore = confidence.score;
    nextPayload.confidenceLevel = confidence.level;
    const stationaryAtSameStop = previousStopIndex === roundTripState.currentStopIndex;

    // ── Run notification logic BEFORE the single batched write so we can fold
    //    the lastNotifiedKey update into the same Firestore commit. ──
    const notificationKey = `${roundTripState.direction}:${roundTripState.currentStopIndex}`;
    const previousNotificationKey = effectiveRuntimeData.lastNotifiedKey ?? "";
    const previousBusStatus = String(effectiveRuntimeData.status ?? effectiveRuntimeData.busStatus ?? "").toLowerCase();
    const currentBusStatus = nextPayload.status;
    let notifiedKeyChanged = false;

    if (currentBusStatus === "running" && previousBusStatus && previousBusStatus !== "running") {
      const allUsers = await getActiveUsersByRoute(route);
      const notifiableUsers = allUsers.filter((u) =>
        userAllowsEventNotification(u, "bus_started", now)
      );
      const runningResult = await sendUsersNotification({
        routeId: route.id,
        users: notifiableUsers,
        title: "Bus is on the way",
        body: `Bus ${route.busId} is now running on route ${route.routeNumber}.`,
        data: {
          type: "bus_started",
          stopIndex: roundTripState.currentStopIndex,
          direction: roundTripState.direction
        }
      });
      logger.info("Bus started notification cycle processed", {
        routeId: route.id,
        attemptedUsers: runningResult.attemptedUsers,
        attemptedTokens: runningResult.attemptedTokens,
        successCount: runningResult.successCount,
        failureCount: runningResult.failureCount
      });
    }

    if (withinRouteArea && notificationKey !== previousNotificationKey) {
      const users = await getActiveUsersByRoute(route);
      const stopIndex = roundTripState.currentStopIndex;
      const nowStop = routeStops[stopIndex];
      const userIndexMap = new Map(
        users.map((u) => [u.id, resolveUserStopIndex(routeStops, u.userstop)])
      );

      const eventBuckets = {
        reached: [],
        eta: [],
        one_stop_away: [],
        route_last_stop: []
      };

      if (stopIndex === routeStops.length - 1) {
        eventBuckets.route_last_stop = users;
      } else {
        for (const user of users) {
          const userStopIndex = userIndexMap.get(user.id) ?? -1;
          if (userStopIndex === stopIndex) {
            eventBuckets.reached.push(user);
          } else if (userStopIndex === stopIndex - 1) {
            eventBuckets.eta.push(user);
          } else if (userStopIndex === stopIndex + 1) {
            eventBuckets.one_stop_away.push(user);
          }
        }
      }

      const orderedEvents = stopIndex === routeStops.length - 1
        ? [
            {
              key: "route_last_stop",
              users: eventBuckets.route_last_stop,
              title: "Bus reached last stop",
              body: `Bus reached last stop: ${nowStop.name}.`
            }
          ]
        : [
            {
              key: "reached",
              users: eventBuckets.reached,
              title: "Bus reached your stop",
              body: `Bus has reached ${nowStop.name}.`
            },
            {
              key: "eta",
              users: eventBuckets.eta,
              title: "Bus is reaching soon",
              body: `ETA ~${etaToNextMinutes || 1} min. Next stop: ${nextStop?.name ?? nowStop.name}.`
            },
            {
              key: "one_stop_away",
              users: eventBuckets.one_stop_away,
              title: "Bus is one stop away",
              body: `Bus is one stop away from your location.`
            }
          ];

      let sentSuccessTotal = 0;
      let sentFailureTotal = 0;
      let attemptedUsersTotal = 0;
      let attemptedTokensTotal = 0;

      for (const event of orderedEvents) {
        if (!event.users.length) continue;
        const notifiableUsers = event.users.filter((u) =>
          userAllowsEventNotification(u, event.key, now)
        );
        if (!notifiableUsers.length) continue;
        const result = await sendUsersNotification({
          routeId: route.id,
          users: notifiableUsers,
          title: event.title,
          body: event.body,
          data: { type: event.key, stopIndex, direction: roundTripState.direction }
        });
        sentSuccessTotal += result.successCount;
        sentFailureTotal += result.failureCount;
        attemptedUsersTotal += result.attemptedUsers;
        attemptedTokensTotal += result.attemptedTokens;
      }

      notifiedKeyChanged = true;
      logger.info("Stop notification cycle processed", {
        routeId: route.id,
        stopIndex,
        direction: roundTripState.direction,
        attemptedUsers: attemptedUsersTotal,
        attemptedTokens: attemptedTokensTotal,
        successCount: sentSuccessTotal,
        failureCount: sentFailureTotal
      });
    }

    // ── Single combined write per cycle: state + lock release + (optional)
    //    bus status doc + (optional) lastNotifiedKey. ──
    const shouldWriteState = shouldWriteRuntime(effectiveRuntimeData, nextPayload);
    const statusChanged = previousBusStatus !== currentBusStatus;
    const writePayload = {
      lockUntilMs: 0 // always release lock
    };
    if (shouldWriteState) {
      Object.assign(writePayload, nextPayload);
    }
    if (notifiedKeyChanged) {
      writePayload.lastNotifiedKey = notificationKey;
    }

    // Always at least 1 write to release the lock; coalesces with state when present.
    if (statusChanged) {
      // Only touch buses/{busId} when status actually flipped (was: every cycle).
      const batch = firestoreDb.batch();
      batch.set(runtimeRef, writePayload, { merge: true });
      batch.set(
        firestoreDb.collection("buses").doc(route.busId),
        { status: nextPayload.status, updatedAt: nextPayload.updatedAt },
        { merge: true }
      );
      await batch.commit();
    } else {
      await runtimeRef.set(writePayload, { merge: true });
    }
    if (shouldWriteState || notifiedKeyChanged) {
      trackingSnapshotCache.delete(route.id);
    }
    acquiredRuntimeRef = null; // already released above

    const shouldUseIdleCooldown =
      !hasMoved &&
      reachedStaleThreshold &&
      stationaryAtSameStop &&
      env.scheduler.idlePollingCooldownMs > env.scheduler.selfCallIntervalMs &&
      staleDurationMs >= env.scheduler.idlePollingStartMs;

    return {
      ok: true,
      routeId: route.id,
      busId: route.busId,
      stopIndex: roundTripState.currentStopIndex,
      direction: roundTripState.direction,
      status: nextPayload.status,
      cooldownMs: shouldUseIdleCooldown ? env.scheduler.idlePollingCooldownMs : 0
    };
  } finally {
    // Best-effort lock release if we crashed mid-cycle.
    if (acquiredRuntimeRef) {
      try {
        await acquiredRuntimeRef.set({ lockUntilMs: 0 }, { merge: true });
      } catch (error) {
        logger.error("Failed to release route lock after error", { error: error.message });
      }
    }
    isSyncRunning = false;
  }
};

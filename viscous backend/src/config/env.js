import dotenv from "dotenv";

dotenv.config();

const hasBaseFirebase = (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_DATABASE_URL) ||
  (process.env.FIREBASE_PROJECT_ID_A && process.env.FIREBASE_DATABASE_URL_A);

if (!hasBaseFirebase) {
  throw new Error("Missing required Firebase environment variables (either FIREBASE_PROJECT_ID/FIREBASE_DATABASE_URL or the _A suffix equivalents)");
}
if (!process.env.PORT) {
  throw new Error("Missing required environment variable: PORT");
}
if (!process.env.JWT_SECRET) {
  throw new Error("Missing required environment variable: JWT_SECRET");
}
if (process.env.NODE_ENV === "production" && !process.env.INTERNAL_API_KEY) {
  throw new Error("Missing required environment variable: INTERNAL_API_KEY in production mode");
}

export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: Number(process.env.PORT ?? 3000),
  firebase: {
    projectIdA: process.env.FIREBASE_PROJECT_ID_A || process.env.FIREBASE_PROJECT_ID,
    databaseURLA: process.env.FIREBASE_DATABASE_URL_A || process.env.FIREBASE_DATABASE_URL,
    serviceAccountJsonA: process.env.FIREBASE_SERVICE_ACCOUNT_JSON_A || process.env.FIREBASE_SERVICE_ACCOUNT_JSON_A,
    projectIdB: process.env.FIREBASE_PROJECT_ID_B,
    databaseURLB: process.env.FIREBASE_DATABASE_URL_B,
    serviceAccountJsonB: process.env.FIREBASE_SERVICE_ACCOUNT_JSON_B
  },
  scheduler: {
    // 12s active sync (was 6s) → halves Firestore writes without hurting UX.
    selfCallIntervalMs: Number(process.env.LOCATION_SYNC_INTERVAL_MS ?? 12_000),
    staleLocationMs: Number(process.env.STALE_LOCATION_MS ?? 45_000),
    // Aggressive idle cooldown when bus is stationary at a stop — saves ~80% writes overnight.
    idlePollingStartMs: Number(process.env.IDLE_POLLING_START_MS ?? 90_000),
    idlePollingCooldownMs: Number(process.env.IDLE_POLLING_COOLDOWN_MS ?? 60_000),
    routeProximityMeters: Number(process.env.ROUTE_PROXIMITY_METERS ?? 100),
    movementThresholdMeters: Number(process.env.MOVEMENT_THRESHOLD_METERS ?? 10),
    internalApiKey: process.env.INTERNAL_API_KEY ?? ""
  },
  /** Short TTL cache for GET /bus-location so many parents on one route share Firestore reads. */
  trackingSnapshotCacheTtlMs: Number(process.env.TRACKING_SNAPSHOT_CACHE_TTL_MS ?? 10_000)
};

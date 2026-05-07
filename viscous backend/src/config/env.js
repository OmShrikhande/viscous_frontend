import dotenv from "dotenv";
  
dotenv.config();
  
const requiredEnvVars = [
  "FIREBASE_DATABASE_URL",
  "FIREBASE_PROJECT_ID",
  "PORT"
];
  
for (const envKey of requiredEnvVars) {  
  if (!process.env[envKey]) {  
    throw new Error(`Missing required environment variable: ${envKey}`);  
  }  
}  
  
export const env = {
  nodeEnv: process.env.NODE_ENV ?? "development",
  port: Number(process.env.PORT ?? 3000),
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    databaseURL: process.env.FIREBASE_DATABASE_URL,
    serviceAccountJson: process.env.FIREBASE_SERVICE_ACCOUNT_JSON
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
    internalApiKey: process.env.INTERNAL_API_KEY ?? "",
    routeNumber: process.env.ROUTE_NUMBER ?? process.env.Route ?? ""
  },
  /** Short TTL cache for GET /bus-location so many parents on one route share Firestore reads. */
  trackingSnapshotCacheTtlMs: Number(process.env.TRACKING_SNAPSHOT_CACHE_TTL_MS ?? 10_000)
};

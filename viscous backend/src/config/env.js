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
    selfCallIntervalMs: Number(process.env.LOCATION_SYNC_INTERVAL_MS ?? 6_000),
    staleLocationMs: Number(process.env.STALE_LOCATION_MS ?? 30_000),
    routeProximityMeters: Number(process.env.ROUTE_PROXIMITY_METERS ?? 100),
    movementThresholdMeters: Number(process.env.MOVEMENT_THRESHOLD_METERS ?? 10),
    internalApiKey: process.env.INTERNAL_API_KEY ?? "",
    routeNumber: process.env.ROUTE_NUMBER ?? process.env.Route ?? ""
  }
};

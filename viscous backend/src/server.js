import app from "./app.js";
import { env } from "./config/env.js";
import { verifyConnections } from "./config/firebaseAdmin.js";
import { startLocationSyncJob } from "./jobs/locationSync.job.js";
import { logger } from "./utils/logger.js";

app.listen(env.port, async () => {
  logger.info(`Server running on https://viscous-frontend.onrender.com`);
  await verifyConnections();
  startLocationSyncJob();
});

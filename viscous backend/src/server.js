import app from "./app.js";
import { env } from "./config/env.js";
import { startLocationSyncJob } from "./jobs/locationSync.job.js";
import { logger } from "./utils/logger.js";

app.listen(env.port, () => {
  logger.info(`Server running on http://localhost:${env.port}`);
  startLocationSyncJob();
});

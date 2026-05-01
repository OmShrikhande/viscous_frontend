import { env } from "../config/env.js";
import { syncConfiguredRoute } from "../services/busTracking.service.js";
import { logger } from "../utils/logger.js";

const skipLogTracker = new Map();

const shouldLogSkip = (reason) => {
  if (reason === "route sync lock busy") {
    return false;
  }

  const now = Date.now();
  const last = skipLogTracker.get(reason) ?? 0;
  if (now - last < 60_000) {
    return false;
  }
  skipLogTracker.set(reason, now);
  return true;
};

const runSync = async () => {
  try {
    const result = await syncConfiguredRoute();
    if (result.skipped) {
      if (shouldLogSkip(result.reason)) {
        logger.warn("Scheduled sync skipped", { reason: result.reason });
      }
      return;
    }
    logger.info("Scheduled sync completed", result);
  } catch (error) {
    logger.error("Scheduled sync failed", { message: error.message });
  }
};

export const startLocationSyncJob = () => {
  setInterval(() => {
    void runSync();
  }, env.scheduler.selfCallIntervalMs);

  setTimeout(() => {
    void runSync();
  }, 10_000);
};

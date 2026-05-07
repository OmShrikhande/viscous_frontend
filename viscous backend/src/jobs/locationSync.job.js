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
      return env.scheduler.selfCallIntervalMs;
    }
    logger.info("Scheduled sync completed", result);
    const cooldownMs = Number(result.cooldownMs ?? 0);
    if (cooldownMs > env.scheduler.selfCallIntervalMs) {
      logger.info("Idle cooldown applied for sync loop", { cooldownMs });
      return cooldownMs;
    }
    return env.scheduler.selfCallIntervalMs;
  } catch (error) {
    logger.error("Scheduled sync failed", { message: error.message });
    return env.scheduler.selfCallIntervalMs;
  }
};

export const startLocationSyncJob = () => {
  const scheduleNext = (delayMs) => {
    setTimeout(async () => {
      const nextDelay = await runSync();
      scheduleNext(nextDelay);
    }, delayMs);
  };

  scheduleNext(10_000);
};

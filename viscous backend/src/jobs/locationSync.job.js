import { env } from "../config/env.js";
import { syncAllRoutes } from "../services/busTracking.service.js";
import { logger } from "../utils/logger.js";

const skipLogTracker = new Map();

const shouldLogSkip = (reason) => {
  if (reason === "route sync lock busy" || reason === "sync already running for route") {
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
    const result = await syncAllRoutes();
    if (result.skipped) {
      if (shouldLogSkip(result.reason)) {
        logger.warn("Scheduled sync skipped", { reason: result.reason });
      }
      return env.scheduler.selfCallIntervalMs;
    }

    // Determine the next scheduling delay based on all routes' cooldown preferences.
    // If any route is active (returns cooldownMs: 0), we must sync at the active interval.
    // Otherwise, we take the minimum of the idle cooldowns.
    let nextDelay = env.scheduler.selfCallIntervalMs;
    if (result.routes && result.routes.length > 0) {
      const activeRoutes = result.routes.filter(r => r.ok && !r.cooldownMs && !r.skipped);
      if (activeRoutes.length === 0) {
        // All successfully synced routes are idle. We can apply a cooldown.
        const idleCooldowns = result.routes
          .map(r => Number(r.cooldownMs ?? 0))
          .filter(c => c > env.scheduler.selfCallIntervalMs);
        if (idleCooldowns.length > 0) {
          nextDelay = Math.min(...idleCooldowns);
          logger.info("Idle cooldown applied for all sync loops", { cooldownMs: nextDelay });
        }
      }
    }

    return nextDelay;
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

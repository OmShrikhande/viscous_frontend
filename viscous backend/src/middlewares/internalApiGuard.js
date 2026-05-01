import { env } from "../config/env.js";

export const internalApiGuard = (req, res, next) => {
  if (!env.scheduler.internalApiKey) {
    if (env.nodeEnv === "production") {
      return res.status(500).json({
        ok: false,
        message: "INTERNAL_API_KEY is required in production."
      });
    }
    return next();
  }

  const incomingKey = req.headers["x-internal-api-key"];

  if (incomingKey !== env.scheduler.internalApiKey) {
    return res.status(401).json({
      ok: false,
      message: "Unauthorized internal API request."
    });
  }

  return next();
};

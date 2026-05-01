import { Router } from "express";
import {
  getCurrentLocation,
  syncLocation,
  getBusLocationByUser
} from "../controllers/location.controller.js";
import { internalApiGuard } from "../middlewares/internalApiGuard.js";
import { authenticateToken } from "../middlewares/auth.middleware.js";

const locationRouter = Router();

locationRouter.get("/current", getCurrentLocation);
locationRouter.post("/sync", internalApiGuard, syncLocation);
locationRouter.get("/bus-location", authenticateToken, getBusLocationByUser);

export default locationRouter;

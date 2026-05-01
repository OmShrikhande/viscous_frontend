import { Router } from "express";
import { getRoute } from "../controllers/route.controller.js";

const router = Router();

router.get("/:routeNumber", getRoute);

export default router;

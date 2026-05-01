import { Router } from "express";
import { authenticateToken } from "../middlewares/auth.middleware.js";
import { getMyProfile, updateMyProfile, upsertFcmToken } from "../controllers/user.controller.js";

const router = Router();

router.get("/me", authenticateToken, getMyProfile);
router.patch("/me", authenticateToken, updateMyProfile);
router.patch("/me/fcm-token", authenticateToken, upsertFcmToken);

export default router;

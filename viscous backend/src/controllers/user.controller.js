import { firestoreDb } from "../config/firebaseAdmin.js";

const normalizeNotificationPreferences = (value) => {
  const src = value && typeof value === "object" ? value : {};
  const pickBool = (key, fallback = true) =>
    typeof src[key] === "boolean" ? src[key] : fallback;
  return {
    notifyReached: pickBool("notifyReached", true),
    notifyEta: pickBool("notifyEta", true),
    notifyOneStopAway: pickBool("notifyOneStopAway", true),
    notifyRouteLastStop: pickBool("notifyRouteLastStop", true),
    notifyBusStarted: pickBool("notifyBusStarted", true)
  };
};

const normalizeQuietHours = (value) => {
  const src = value && typeof value === "object" ? value : {};
  const start = String(src.start ?? "22:00").trim();
  const end = String(src.end ?? "06:00").trim();
  const timezoneOffsetMinutes = Number(src.timezoneOffsetMinutes ?? 330);
  return {
    enabled: typeof src.enabled === "boolean" ? src.enabled : false,
    start,
    end,
    timezoneOffsetMinutes: Number.isFinite(timezoneOffsetMinutes)
      ? Math.max(-720, Math.min(840, timezoneOffsetMinutes))
      : 330
  };
};

export const upsertFcmToken = async (req, res) => {
  try {
    const userId = req.user?.userId;
    const fcmToken = String(req.body?.fcmToken ?? "").trim();

    if (!userId) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }
    if (!fcmToken) {
      return res.status(400).json({ success: false, message: "fcmToken is required" });
    }

    const userRef = firestoreDb.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const existingTokens = Array.isArray(userData?.fcmTokens)
      ? userData.fcmTokens.filter((t) => typeof t === "string" && t.trim().length > 0)
      : [];
    const mergedTokens = [
      fcmToken,
      ...existingTokens.filter((token) => token !== fcmToken)
    ].slice(0, 5);

    await userRef.set(
      {
        fcmToken,
        fcmTokens: mergedTokens,
        fcmTokenUpdatedAt: new Date().toISOString()
      },
      { merge: true }
    );

    return res.status(200).json({ success: true, message: "FCM token updated" });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message ?? "Failed to update FCM token"
    });
  }
};

export const getMyProfile = async (req, res) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    const userDoc = await firestoreDb.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    return res.status(200).json({
      success: true,
      data: { id: userDoc.id, ...userDoc.data() }
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message ?? "Failed to fetch profile"
    });
  }
};

export const updateMyProfile = async (req, res) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }

    const allowedFields = ["name", "email", "userstop", "phone"];
    const payload = {};
    for (const field of allowedFields) {
      if (typeof req.body?.[field] === "string") {
        payload[field] = req.body[field].trim();
      }
    }
    if (req.body?.notificationPreferences !== undefined) {
      payload.notificationPreferences = normalizeNotificationPreferences(
        req.body.notificationPreferences
      );
    }
    if (req.body?.notificationQuietHours !== undefined) {
      payload.notificationQuietHours = normalizeQuietHours(
        req.body.notificationQuietHours
      );
    }
    payload.updatedAt = new Date().toISOString();

    await firestoreDb.collection("users").doc(userId).set(payload, { merge: true });
    const updatedDoc = await firestoreDb.collection("users").doc(userId).get();

    return res.status(200).json({
      success: true,
      message: "Profile updated",
      data: { id: updatedDoc.id, ...updatedDoc.data() }
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message ?? "Failed to update profile"
    });
  }
};

import { firestoreDb } from "../config/firebaseAdmin.js";

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

    await firestoreDb.collection("users").doc(userId).set(
      {
        fcmToken,
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

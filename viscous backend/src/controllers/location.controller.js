import { getRealtimeLocation } from "../services/location.service.js";
import { getTrackingSnapshotForUser, syncConfiguredRoute } from "../services/busTracking.service.js";

export const getCurrentLocation = async (_req, res, next) => {
  try {
    const location = await getRealtimeLocation();

    res.status(200).json({
      ok: true,
      source: "realtime-db",
      data: location
    });
  } catch (error) {
    next(error);
  }
};

export const syncLocation = async (_req, res, next) => {
  try {
    const result = await syncConfiguredRoute();

    res.status(200).json({
      ok: true,
      message: "Location synced from Realtime DB to Firestore.",
      data: result
    });
  } catch (error) {
    next(error);
  }
};

export const getBusLocationByUser = async (req, res, next) => {
  try {
    const user = req.user;

    if (!user || !user.route) {
      return res.status(400).json({
        success: false,
        message: 'User route not found in token'
      });
    }

    const locationData = await getTrackingSnapshotForUser({
      routeId: user.route,
      userStop: user.userstop
    });

    res.json({
      success: true,
      data: locationData
    });

  } catch (error) {
    console.error('Error getting bus location:', error);
    res.status(500).json({
      success: false,
      message: error.message || 'Failed to get bus location'
    });
  }
};

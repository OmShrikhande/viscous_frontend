import { getRealtimeLocation } from "../services/location.service.js";
import { 
  getTrackingSnapshotForUser, 
  syncAllRoutes, 
  syncSingleRoute, 
  getRouteByNumber 
} from "../services/busTracking.service.js";
import { dbA, dbB } from "../config/firebaseAdmin.js";

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

export const syncLocation = async (req, res, next) => {
  try {
    const { routeNumber, routeId } = req.body;
    let result;

    if (routeId) {
      // Find route in A or B
      let route = null;
      let doc = await dbA.firestoreDb.collection("routes").doc(routeId).get();
      if (doc.exists) {
        route = { id: doc.id, fleet: 'A', ...doc.data() };
      } else if (dbB !== dbA) {
        doc = await dbB.firestoreDb.collection("routes").doc(routeId).get();
        if (doc.exists) {
          route = { id: doc.id, fleet: 'B', ...doc.data() };
        }
      }

      if (!route) {
        return res.status(404).json({ ok: false, message: `Route ID ${routeId} not found` });
      }
      result = await syncSingleRoute(route);
    } else if (routeNumber) {
      const route = await getRouteByNumber(routeNumber);
      if (!route) {
        return res.status(404).json({ ok: false, message: `Route number ${routeNumber} not found` });
      }
      result = await syncSingleRoute(route);
    } else {
      // Default: sync all routes
      result = await syncAllRoutes();
    }

    res.status(200).json({
      ok: true,
      message: "Location sync executed successfully.",
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
      userStop: user.userstop,
      fleet: user.fleet
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

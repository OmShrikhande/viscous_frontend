import { getDbForFleet, realtimeDb } from "../config/firebaseAdmin.js";

// Cache to store previous positions for speed calculation
const positionCache = new Map();
const BUS_LOCATION_KEYS = {
  latitude: "latitude",
  longitude: "longitude"
};

/**
 * Fetch the current GPS location for a bus from the correct fleet's Realtime Database.
 * @param {string} busKey - The bus identifier (e.g. 'MH40BG2205')
 * @param {string} [fleet='A'] - The fleet identifier ('A' or 'B')
 */
export const getBusLocation = async (busKey, fleet = 'A') => {
  try {
    const db = getDbForFleet(fleet);
    // Fetch current location from realtime database under the bus key node
    const busPath = `/${busKey}`;
    const snapshot = await db.realtimeDb.ref(busPath).get();
    const locationData = snapshot.val();

    if (!locationData) {
      throw new Error(`No location data found at Realtime DB path ${busPath}`);
    }

    const latitude = Number(locationData[BUS_LOCATION_KEYS.latitude]);
    const longitude = Number(locationData[BUS_LOCATION_KEYS.longitude]);
    const timestamp = Date.now();

    // Calculate speed
    const speedKmh = calculateSpeed(busKey, latitude, longitude, timestamp);

    // Update cache with current position
    positionCache.set(busKey, {
      latitude,
      longitude,
      timestamp
    });

    return {
      latitude,
      longitude,
      speedKmh,
      timestamp,
      busKey,
      isStale: false
    };
  } catch (error) {
    console.error(`Error fetching location for bus ${busKey}:`, error);
    throw error;
  }
};

/**
 * Find the busId for a given route number by searching both Firebase projects.
 * @param {string} routeNumber - The route number (e.g. 'R-3')
 * @returns {{ busId: string, fleet: string }}
 */
export const getBusIdFromRoute = async (routeNumber) => {
  try {
    const { dbA, dbB } = await import("../config/firebaseAdmin.js");

    // Search Project A first
    let querySnapshot = await dbA.firestoreDb.collection('routes')
      .where('routeNumber', '==', routeNumber).limit(1).get();
    let fleet = 'A';

    if (querySnapshot.empty && dbB !== dbA) {
      querySnapshot = await dbB.firestoreDb.collection('routes')
        .where('routeNumber', '==', routeNumber).limit(1).get();
      fleet = 'B';
    }

    if (querySnapshot.empty) {
      throw new Error(`No route found with routeNumber: ${routeNumber}`);
    }

    const routeDoc = querySnapshot.docs[0];
    const routeData = routeDoc.data();

    if (!routeData.busId) {
      throw new Error(`Route ${routeNumber} does not have a busId`);
    }

    return { busId: routeData.busId, fleet };
  } catch (error) {
    console.error(`Error finding busId for route ${routeNumber}:`, error);
    throw error;
  }
};

function calculateSpeed(busKey, currentLat, currentLng, currentTimestamp) {
  const previousPosition = positionCache.get(busKey);

  if (!previousPosition) {
    // No previous position, can't calculate speed
    return 0;
  }

  const timeDiffSeconds = (currentTimestamp - previousPosition.timestamp) / 1000;

  if (timeDiffSeconds <= 0) {
    return 0;
  }

  // Calculate distance using Haversine formula (approximate)
  const distanceKm = calculateDistance(
    previousPosition.latitude,
    previousPosition.longitude,
    currentLat,
    currentLng
  );

  // Calculate speed in km/h
  const speedKmh = (distanceKm / timeDiffSeconds) * 3600;

  // Cap at reasonable speed (e.g., 100 km/h max for buses)
  return Math.min(speedKmh, 100);
}

function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // Earth's radius in km
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);

  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLng/2) * Math.sin(dLng/2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}
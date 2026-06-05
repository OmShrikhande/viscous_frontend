import { firestoreDb, realtimeDb } from "./src/config/firebaseAdmin.js";

async function resetStaleRoutes() {
  console.log("Analyzing route_runtime collection for stale routes...");
  const snapshot = await firestoreDb.collection("route_runtime").get();
  
  if (snapshot.empty) {
    console.log("No routes found in route_runtime.");
    process.exit(0);
  }

  const batch = firestoreDb.batch();
  let updatedCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    
    const stops = data.routeStops || [];
    const currentStopIndex = data.currentStopIndex ?? 0;
    const nextStopIndex = data.nextStopIndex;
    
    const expectedNextIndex = stops.length > 1 ? 1 : 0;
    
    // Check if route needs resetting (e.g. daily trip hasn't started and next stop is stale)
    if (data.hasStartedDailyTrip === false || (currentStopIndex === 0 && nextStopIndex !== expectedNextIndex)) {
      console.log(`Resetting route: ${data.routeNumber || doc.id} (Bus: ${data.busId})`);
      
      const resetData = {
        direction: 1,
        currentStopIndex: 0,
        nextStopIndex: expectedNextIndex,
        currentStop: stops[0]?.name ?? null,
        nextStop: stops[expectedNextIndex]?.name ?? null,
        distanceToNextStopMeters: 0,
        etaToNextSeconds: 0,
        etaToNextMinutes: 0,
        isAtLastStop: false,
        nearestStopDistanceMeters: 0,
        confidenceScore: 100,
        confidenceLevel: "high"
      };
      
      batch.update(doc.ref, resetData);
      
      // Also clear realtime DB location
      if (data.busId) {
        await realtimeDb.ref(`/${data.busId}`).remove();
        console.log(`  Cleared realtime DB for bus: ${data.busId}`);
      }
      
      updatedCount++;
    } else {
      console.log(`Route ${data.routeNumber || doc.id} looks fine (current: ${currentStopIndex}, next: ${nextStopIndex}). Skipping.`);
    }
  }

  if (updatedCount > 0) {
    await batch.commit();
    console.log(`\nSuccessfully reset ${updatedCount} stale route(s).`);
  } else {
    console.log("\nNo stale routes needed resetting.");
  }

  process.exit(0);
}

resetStaleRoutes().catch(err => {
  console.error("Error resetting routes:", err);
  process.exit(1);
});

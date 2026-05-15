import { firestoreDb } from "./src/config/firebaseAdmin.js";

async function forceReset() {
  const snapshot = await firestoreDb.collection("route_runtime").get();
  const batch = firestoreDb.batch();
  snapshot.docs.forEach(doc => {
    batch.update(doc.ref, { lastResetDate: null });
  });
  await batch.commit();
  console.log("lastResetDate cleared for all routes.");
  process.exit(0);
}

forceReset();

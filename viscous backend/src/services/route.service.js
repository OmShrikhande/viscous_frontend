import { dbA, dbB } from "../config/firebaseAdmin.js";

export const getRouteByNumber = async (routeNumber) => {
  // Search Project A first
  let snapshot = await dbA.firestoreDb.collection("routes").where("routeNumber", "==", routeNumber).limit(1).get();
  let fleet = 'A';

  // If not found in Project A and Project B is configured and different, search Project B
  if (snapshot.empty && dbB !== dbA) {
    snapshot = await dbB.firestoreDb.collection("routes").where("routeNumber", "==", routeNumber).limit(1).get();
    fleet = 'B';
  }
  
  if (snapshot.empty) {
    return null;
  }
  
  const doc = snapshot.docs[0];
  return { id: doc.id, fleet, ...doc.data() };
};

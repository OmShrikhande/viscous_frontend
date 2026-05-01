import { firestoreDb } from "../config/firebaseAdmin.js";

export const getRouteByNumber = async (routeNumber) => {
  const routesRef = firestoreDb.collection("routes");
  const snapshot = await routesRef.where("routeNumber", "==", routeNumber).limit(1).get();
  
  if (snapshot.empty) {
    return null;
  }
  
  const doc = snapshot.docs[0];
  return { id: doc.id, ...doc.data() };
};

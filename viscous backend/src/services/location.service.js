import { firestoreDb, realtimeDb } from "../config/firebaseAdmin.js";  
import { getIstDate, getIstTime } from "../utils/istDateTime.js";  
  
const LOCATION_KEYS = {  
  latitude: "latitude",  
  longitude: "longitude"  
};  
  
export const getRealtimeLocation = async () => {  
  const snapshot = await realtimeDb.ref("/location").get();  
  const source = snapshot.val() ?? {};  
  
  const latitude = Number(source[LOCATION_KEYS.latitude]);  
  const longitude = Number(source[LOCATION_KEYS.longitude]);  
  
  return { latitude, longitude };
};

export const fetchAndPersistLocation = async () => {
  const location = await getRealtimeLocation();
  const date = getIstDate();
  const time = getIstTime();

  const docRef = firestoreDb.collection("locations").doc();
  const payload = {
    ...location,
    date,
    time,
    timestamp: new Date().toISOString()
  };

  await docRef.set(payload);
  return payload;
};
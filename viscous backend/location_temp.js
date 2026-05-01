import { firestoreDb, realtimeDb } from \"../config/firebaseAdmin.js\";  
import { getIstDate, getIstTime } from \"../utils/istDateTime.js\";  
  
const LOCATION_KEYS = {  
  latitude: \"latitiude\",  
  longitude: \"longitude\"  
};  
  
export const getRealtimeLocation = async () => {  
  const snapshot = await realtimeDb.ref(\"/\").get();  
  const source = snapshot.val() ?? {};  
  
  const latitude = Number(source[LOCATION_KEYS.latitude]);  
  const longitude = Number(source[LOCATION_KEYS.longitude]);  
  

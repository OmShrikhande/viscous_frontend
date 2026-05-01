import { applicationDefault, cert, initializeApp } from "firebase-admin/app";
import { getDatabase } from "firebase-admin/database";
import { getFirestore } from "firebase-admin/firestore";
import { env } from "./env.js";

const getCredential = () => {
  if (env.firebase.serviceAccountJson) {
    const serviceAccount = JSON.parse(env.firebase.serviceAccountJson);
    return cert(serviceAccount);
  }

  return applicationDefault();
};

const app = initializeApp({
  credential: getCredential(),
  databaseURL: env.firebase.databaseURL,
  projectId: env.firebase.projectId
});

export const realtimeDb = getDatabase(app);
export const firestoreDb = getFirestore(app);

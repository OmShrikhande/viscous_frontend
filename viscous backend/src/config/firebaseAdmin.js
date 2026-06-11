import { applicationDefault, cert, initializeApp } from "firebase-admin/app";
import { getDatabase } from "firebase-admin/database";
import { getFirestore } from "firebase-admin/firestore";
import { env } from "./env.js";
import { logger } from "../utils/logger.js";

const getCredential = (json) => {
  if (json) {
    const serviceAccount = JSON.parse(json);
    return cert(serviceAccount);
  }

  return applicationDefault();
};

// Initialize App A (Primary/Default)
const appA = initializeApp({
  credential: getCredential(env.firebase.serviceAccountJsonA),
  databaseURL: env.firebase.databaseURLA,
  projectId: env.firebase.projectIdA
});

// Export default instances (pointing to Project A) for backward compatibility
export const realtimeDb = getDatabase(appA);
export const firestoreDb = getFirestore(appA);
export { appA };

export const dbA = {
  realtimeDb,
  firestoreDb
};

// Initialize App B (Secondary) if B has at least a projectId or databaseURL configured
let appB = null;
if (env.firebase.projectIdB || env.firebase.databaseURLB) {
  appB = initializeApp({
    credential: getCredential(env.firebase.serviceAccountJsonB),
    databaseURL: env.firebase.databaseURLB,
    projectId: env.firebase.projectIdB
  }, "appB");
}

export const dbB = appB ? {
  realtimeDb: getDatabase(appB),
  firestoreDb: getFirestore(appB)
} : dbA;

export { appB };

/**
 * Returns database references for the requested fleet/project ('A' or 'B')
 * @param {string} fleet - 'A' or 'B'
 * @returns {{realtimeDb: any, firestoreDb: any}}
 */
export const getDbForFleet = (fleet) => {
  return fleet === "B" ? dbB : dbA;
};

/**
 * Verifies connectivity to all configured Firebase projects by doing a lightweight
 * Firestore ping (listCollections). Logs success or failure per project at startup.
 */
export const verifyConnections = async () => {
  // ── Project A ──
  try {
    await dbA.firestoreDb.listCollections();
    logger.info("Firebase Project A connected", {
      projectId: env.firebase.projectIdA,
      databaseURL: env.firebase.databaseURLA
    });
  } catch (err) {
    logger.error("Firebase Project A connection FAILED", {
      projectId: env.firebase.projectIdA,
      error: err.message
    });
  }

  // ── Project B (only if configured separately) ──
  if (dbB !== dbA) {
    try {
      await dbB.firestoreDb.listCollections();
      logger.info("Firebase Project B connected", {
        projectId: env.firebase.projectIdB,
        databaseURL: env.firebase.databaseURLB
      });
    } catch (err) {
      logger.error("Firebase Project B connection FAILED", {
        projectId: env.firebase.projectIdB,
        error: err.message
      });
    }
  } else {
    logger.info("Firebase Project B not configured — using Project A as fallback");
  }
};


/**
 * Deploy from the directory that contains firebase.json (often repo root):
 *   firebase deploy --only functions
 *
 * Firestore layout (same as the Flutter app):
 *   notification/{dateId}           — document fields: title, body, message, …
 *   notification/{dateId}/items/{id} — optional sub-documents for multiple notices per day
 *
 * The app subscribes to FCM topic: viscous_broadcast
 */
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const TOPIC = "viscous_broadcast";

function pickTitle(data) {
  return String(data.title || data.heading || data.subject || "Viscous").slice(0, 200);
}

function pickBody(data) {
  return String(data.body || data.message || data.description || "You have a new notification.").slice(
    0,
    500
  );
}

function hasMessageFields(data) {
  return ["title", "heading", "subject", "body", "message", "description"].some((k) => {
    const v = data[k];
    return v != null && String(v).trim().length > 0;
  });
}

exports.onNotificationDateCreated = onDocumentCreated("notification/{dateId}", async (event) => {
  const data = event.data?.data() || {};
  if (!hasMessageFields(data)) return;
  const title = pickTitle(data);
  const body = pickBody(data);
  await getMessaging().send({
    topic: TOPIC,
    notification: { title, body },
    data: { dateId: String(event.params.dateId || "") },
  });
});

exports.onNotificationItemCreated = onDocumentCreated(
  "notification/{dateId}/items/{itemId}",
  async (event) => {
    const data = event.data?.data() || {};
    if (!hasMessageFields(data)) return;
    const title = pickTitle(data);
    const body = pickBody(data);
    await getMessaging().send({
      topic: TOPIC,
      notification: { title, body },
      data: {
        dateId: String(event.params.dateId || ""),
        itemId: String(event.params.itemId || ""),
      },
    });
  }
);

/**
 * Removes the "sent" field from all documents in daily_items collection.
 * Run from functions dir: node scripts/remove-sent-field.js
 * Requires: gcloud auth application-default login
 *   (or GOOGLE_APPLICATION_CREDENTIALS)
 */
const fs = require("fs");
const path = require("path");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

let projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
if (!projectId) {
  try {
    const rcPath = path.join(__dirname, "../../.firebaserc");
    const firebaserc = JSON.parse(fs.readFileSync(rcPath, "utf8"));
    projectId = firebaserc && firebaserc.projects &&
        firebaserc.projects.default;
  } catch (_) {
    // ignore
  }
}
if (!projectId) {
  projectId = "periodically-notification";
}

initializeApp({projectId});
const db = getFirestore();

/**
 * Removes the sent field from all daily_items documents.
 */
async function main() {
  const snapshot = await db.collection("daily_items").get();
  const batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    if ("sent" in data) {
      batch.update(doc.ref, {sent: FieldValue.delete()});
      count++;
    }
  }

  if (count === 0) {
    console.log("No documents have 'sent' field to remove.");
    return;
  }

  await batch.commit();
  console.log(`Removed 'sent' field from ${count} document(s).`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

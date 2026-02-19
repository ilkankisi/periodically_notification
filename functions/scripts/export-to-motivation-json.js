/**
 * Exports daily_items from Firestore to motivation.json format.
 * Run: node scripts/export-to-motivation-json.js
 * Output: writes to ../../assets/data/motivation.json
 */
const fs = require("fs");
const path = require("path");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

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
 * Exports daily_items to motivation.json format.
 */
async function main() {
  const snapshot = await db.collection("daily_items").get();
  const limit = 2;
  const items = [];
  const sorted = snapshot.docs.sort((a, b) => {
    return (a.data().order || 0) - (b.data().order || 0);
  });
  for (let i = 0; i < Math.min(limit, sorted.length); i++) {
    const doc = sorted[i];
    const d = doc.data();
    const sentAt = d.sentAt ? (d.sentAt.toDate ? d.sentAt.toDate().toISOString() : d.sentAt) : null;
    items.push({
      id: doc.id,
      title: d.title || "",
      body: d.body || "",
      order: d.order,
      sentAt,
      image: null,
      imageUrl: d.imageUrl || null,
    });
  }
  const outPath = path.join(__dirname, "../../assets/data/motivation.json");
  fs.writeFileSync(outPath, JSON.stringify(items, null, 2), "utf8");
  console.log(`Exported ${items.length} items to ${outPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

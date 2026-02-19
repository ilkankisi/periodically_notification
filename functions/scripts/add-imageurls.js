/**
 * Adds imageUrl (Storage download URL) to daily_items documents.
 * Run from functions dir: node scripts/add-imageurls.js
 * Requires: gcloud auth application-default login
 *
 * Mapping: scripts/image-url-mapping.json (order -> filename)
 * Edit the mapping file to change which image goes to which order.
 */
const fs = require("fs");
const path = require("path");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");

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

const bucketName = projectId + ".firebasestorage.app";
initializeApp({projectId, storageBucket: bucketName});

const db = getFirestore();
const bucket = getStorage().bucket(bucketName);

/**
 * Returns public download URL using metadata token (no service account needed).
 * @param {string} filePath Path to file in Storage (e.g. IMG_5234.jpg)
 * @return {Promise<string>} Download URL
 */
async function getDownloadUrl(filePath) {
  const file = bucket.file(filePath);
  const [metadata] = await file.getMetadata();
  let token = metadata.metadata &&
      metadata.metadata.firebaseStorageDownloadTokens;
  if (!token && metadata.metadata) {
    token = metadata.metadata.firebasestoragedownloadtokens;
  }
  if (!token) {
    throw new Error("No download token in metadata. Use service account key: " +
        "GOOGLE_APPLICATION_CREDENTIALS");
  }
  const encoded = encodeURIComponent(filePath);
  return "https://firebasestorage.googleapis.com/v0/b/" +
      bucketName + "/o/" + encoded + "?alt=media&token=" + token;
}

/**
 * Updates daily_items documents with imageUrl from Storage.
 */
async function main() {
  const mappingPath = path.join(__dirname, "image-url-mapping.json");
  const mapping = JSON.parse(fs.readFileSync(mappingPath, "utf8"));

  const snapshot = await db.collection("daily_items").get();
  const docsByOrder = {};
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const order = data.order;
    if (order != null) {
      docsByOrder[String(order)] = doc;
    }
  }

  let updated = 0;
  for (const orderStr of Object.keys(mapping)) {
    const filename = mapping[orderStr];
    const docRef = docsByOrder[orderStr];
    if (!docRef) {
      console.warn(`No document with order ${orderStr}, skipping ${filename}`);
      continue;
    }
    try {
      const url = await getDownloadUrl(filename);
      await docRef.ref.update({imageUrl: url});
      console.log(`Updated order ${orderStr} (${filename})`);
      updated++;
    } catch (err) {
      console.error(`Failed ${filename}:`, err.message);
    }
  }
  console.log(`Done. Updated ${updated} document(s).`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

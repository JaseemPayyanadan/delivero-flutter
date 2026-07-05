#!/usr/bin/env node
/**
 * Export ALL Firestore data from a project to local JSON files.
 *
 * Usage:
 *   node scripts/firestore-export.js
 *
 * Requires a service-account key (read access) for the source project.
 * Point KEY_PATH below at it, or set the env var:
 *   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/key.json node scripts/firestore-export.js
 *
 * Output:
 *   firestore-export/<collection>.json   (one file per top-level collection)
 * Each file contains every document, including nested subcollections, with
 * Firestore-specific types (Timestamp, GeoPoint, DocumentReference, Bytes)
 * preserved in a self-describing, re-importable form (see encodeValue).
 */

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp, GeoPoint, DocumentReference } = require('firebase-admin/firestore');

// --- Config -----------------------------------------------------------------
const KEY_PATH =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, 'delivero-prod-key.json');
const OUT_DIR = path.join(__dirname, '..', 'firestore-export');
// ----------------------------------------------------------------------------

if (!fs.existsSync(KEY_PATH)) {
  console.error(`\n  Service-account key not found at:\n    ${KEY_PATH}\n`);
  console.error('  Download it from Firebase Console > Project settings >');
  console.error('  Service accounts > Generate new private key (project: delivero-prod),');
  console.error('  then save it to that path, or set GOOGLE_APPLICATION_CREDENTIALS.\n');
  process.exit(1);
}

const serviceAccount = require(KEY_PATH);
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const stats = { collections: 0, documents: 0 };

/** Convert a Firestore field value into JSON-safe, self-describing form. */
function encodeValue(value) {
  if (value === null || value === undefined) return null;

  if (value instanceof Timestamp) {
    return { __type__: 'timestamp', value: value.toDate().toISOString() };
  }
  if (value instanceof GeoPoint) {
    return { __type__: 'geopoint', latitude: value.latitude, longitude: value.longitude };
  }
  if (value instanceof DocumentReference) {
    return { __type__: 'reference', path: value.path };
  }
  if (Buffer.isBuffer(value)) {
    return { __type__: 'bytes', value: value.toString('base64') };
  }
  if (Array.isArray(value)) {
    return value.map(encodeValue);
  }
  if (typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = encodeValue(v);
    return out;
  }
  return value; // string | number | boolean
}

/** Recursively export a single document, including its subcollections. */
async function exportDoc(docSnap) {
  stats.documents += 1;
  const record = { __id__: docSnap.id, data: {} };
  const raw = docSnap.data() || {};
  for (const [k, v] of Object.entries(raw)) record.data[k] = encodeValue(v);

  const subcols = await docSnap.ref.listCollections();
  if (subcols.length > 0) {
    record.__subcollections__ = {};
    for (const sub of subcols) {
      record.__subcollections__[sub.id] = await exportCollection(sub);
    }
  }
  return record;
}

/** Export every document in a collection reference. */
async function exportCollection(colRef) {
  const snap = await colRef.get();
  const docs = [];
  for (const doc of snap.docs) {
    docs.push(await exportDoc(doc));
  }
  return docs;
}

async function main() {
  console.log(`\nExporting Firestore from project: ${serviceAccount.project_id}`);
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const topCollections = await db.listCollections();
  if (topCollections.length === 0) {
    console.log('No top-level collections found. Nothing to export.');
    return;
  }

  for (const col of topCollections) {
    process.stdout.write(`  ${col.id} ... `);
    const docs = await exportCollection(col);
    const file = path.join(OUT_DIR, `${col.id}.json`);
    fs.writeFileSync(file, JSON.stringify(docs, null, 2));
    stats.collections += 1;
    console.log(`${docs.length} top-level docs -> ${path.relative(process.cwd(), file)}`);
  }

  console.log(
    `\nDone. ${stats.collections} top-level collections, ` +
      `${stats.documents} documents total (incl. subcollections).`
  );
  console.log(`Output: ${path.relative(process.cwd(), OUT_DIR)}/\n`);
}

main().catch((err) => {
  console.error('\nExport failed:', err.message);
  process.exit(1);
});

#!/usr/bin/env node
/**
 * Import the local Firestore JSON dump (from firestore-export.js) into a
 * target project. Writes every document by its original ID, recreating
 * nested subcollections and restoring Firestore types.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/dev-key.json \
 *     node scripts/firestore-import.js
 *
 * Requires a service-account key with WRITE access to the TARGET project
 * (delivero-48322 / dev). Writing a doc by ID overwrites any existing doc
 * with that ID; dev-only docs not present in the dump are left untouched.
 */

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const {
  getFirestore,
  Timestamp,
  GeoPoint,
} = require('firebase-admin/firestore');

// --- Config -----------------------------------------------------------------
const KEY_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const IN_DIR = path.join(__dirname, '..', 'firestore-export');
const EXPECTED_PROJECT = 'delivero-48322'; // dev — safety guard
// ----------------------------------------------------------------------------

if (!KEY_PATH || !fs.existsSync(KEY_PATH)) {
  console.error('\n  Set GOOGLE_APPLICATION_CREDENTIALS to the dev service-account key.\n');
  process.exit(1);
}

const serviceAccount = require(KEY_PATH);
if (serviceAccount.project_id !== EXPECTED_PROJECT) {
  console.error(
    `\n  Safety stop: key is for "${serviceAccount.project_id}", expected "${EXPECTED_PROJECT}".\n` +
      '  This script only writes to the dev project. Aborting.\n'
  );
  process.exit(1);
}

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const stats = { documents: 0 };

/** Reverse of encodeValue in firestore-export.js. */
function decodeValue(value) {
  if (value === null || value === undefined) return null;

  if (Array.isArray(value)) return value.map(decodeValue);

  if (typeof value === 'object') {
    switch (value.__type__) {
      case 'timestamp':
        return Timestamp.fromDate(new Date(value.value));
      case 'geopoint':
        return new GeoPoint(value.latitude, value.longitude);
      case 'reference':
        return db.doc(value.path);
      case 'bytes':
        return Buffer.from(value.value, 'base64');
      default: {
        const out = {};
        for (const [k, v] of Object.entries(value)) out[k] = decodeValue(v);
        return out;
      }
    }
  }
  return value; // string | number | boolean
}

/** Write one exported record into colRef, recursing into subcollections. */
async function importDoc(colRef, record) {
  const data = {};
  for (const [k, v] of Object.entries(record.data || {})) data[k] = decodeValue(v);

  const docRef = colRef.doc(record.__id__);
  await docRef.set(data);
  stats.documents += 1;

  const subs = record.__subcollections__ || {};
  for (const [subName, subDocs] of Object.entries(subs)) {
    const subCol = docRef.collection(subName);
    for (const subRecord of subDocs) {
      await importDoc(subCol, subRecord);
    }
  }
}

async function main() {
  if (!fs.existsSync(IN_DIR)) {
    console.error(`\n  No export found at ${IN_DIR}. Run firestore-export.js first.\n`);
    process.exit(1);
  }

  const files = fs.readdirSync(IN_DIR).filter((f) => f.endsWith('.json'));
  if (files.length === 0) {
    console.error('  No .json files to import.');
    process.exit(1);
  }

  console.log(`\nImporting into project: ${serviceAccount.project_id} (dev)\n`);

  for (const file of files) {
    const colName = path.basename(file, '.json');
    const records = JSON.parse(fs.readFileSync(path.join(IN_DIR, file), 'utf8'));
    process.stdout.write(`  ${colName} ... `);
    const colRef = db.collection(colName);
    for (const record of records) {
      await importDoc(colRef, record);
    }
    console.log(`${records.length} top-level docs written`);
  }

  console.log(`\nDone. ${stats.documents} documents written (incl. subcollections).\n`);
}

main().catch((err) => {
  console.error('\nImport failed:', err.message);
  process.exit(1);
});

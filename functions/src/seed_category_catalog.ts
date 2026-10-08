import {readFileSync} from "node:fs";
import {join} from "node:path";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

// This seed is development-only. Pin both values so it never depends on ADC or
// accidentally writes to a real Firebase project when invoked outside the CLI.
const projectId = "demo-clearbudget";
process.env.GCLOUD_PROJECT = projectId;
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:59180";

const app = initializeApp({projectId});

type CatalogCategory = {
  id: string;
  [key: string]: unknown;
};

const categories = JSON.parse(
  readFileSync(join(__dirname, "..", "category_catalog.json"), "utf8"),
) as CatalogCategory[];

const db = getFirestore(app);
const batch = db.batch();
for (const category of categories) {
  batch.set(db.doc(`categoryCatalog/${category.id}`), category);
}

batch.commit().then(() => {
  console.log(`Seeded ${categories.length} category catalog entries.`);
}).catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});

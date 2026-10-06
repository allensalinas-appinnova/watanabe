import {readFileSync} from "node:fs";
import {join} from "node:path";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

initializeApp();

type CatalogCategory = {
  id: string;
  [key: string]: unknown;
};

const categories = JSON.parse(
  readFileSync(join(__dirname, "..", "category_catalog.json"), "utf8"),
) as CatalogCategory[];

const db = getFirestore();
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

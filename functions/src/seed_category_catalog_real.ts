import {readFileSync} from "node:fs";
import {join} from "node:path";
import {deleteApp, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

// Intentionally pinned to the newly created real project. The regular
// seed_category_catalog.ts remains emulator-only.
const projectId = "lumiomoney";

if (process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error("Refusing to seed the real catalog while an emulator host is configured.");
}

type CatalogCategory = {
  id: string;
  [key: string]: unknown;
};

const categories = JSON.parse(
  readFileSync(join(__dirname, "..", "category_catalog.json"), "utf8"),
) as CatalogCategory[];

async function main(): Promise<void> {
  const app = initializeApp({projectId}, "real-category-catalog-seed");
  try {
    const db = getFirestore(app);
    const createdCount = await db.runTransaction(async (transaction) => {
      const refs = categories.map((category) =>
        db.doc(`categoryCatalog/${category.id}`),
      );
      const snapshots = await Promise.all(refs.map((ref) => transaction.get(ref)));
      let count = 0;

      snapshots.forEach((snapshot, index) => {
        if (!snapshot.exists) {
          transaction.create(refs[index], categories[index]);
          count++;
        }
      });

      return count;
    });

    console.log(
      `Firebase project ${projectId}: created ${createdCount} missing catalog entries; existing entries were preserved.`,
    );
  } finally {
    await deleteApp(app);
  }
}

main().catch((error: unknown) => {
  const code = error && typeof error === "object" && "code" in error ?
    String(error.code) : "seed_failed";
  console.error(`Category catalog seed failed (${code}). Check ADC and Firestore IAM access.`);
  process.exitCode = 1;
});

import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {fileURLToPath} from "node:url";
import test from "node:test";

const currentDirectory = fileURLToPath(new URL(".", import.meta.url));
const catalog = JSON.parse(
  readFileSync(join(currentDirectory, "..", "category_catalog.json"), "utf8"),
);

test("version 3 default expense categories have stable ids and localized labels", () => {
  const ids = catalog.map((category) => category.id);
  assert.equal(new Set(ids).size, ids.length, "catalog ids must be unique");

  const expected = {
    sports: {es: "Deportes", pt: "Esportes", en: "Sports"},
    hobbies: {es: "Pasatiempos", pt: "Passatempos", en: "Hobbies"},
    subscriptions: {es: "Suscripciones", pt: "Assinaturas", en: "Subscriptions"},
  };

  for (const [id, labels] of Object.entries(expected)) {
    const category = catalog.find((entry) => entry.id === id);
    assert.ok(category, `${id} should be available in the default catalog`);
    assert.equal(category.type, "expense");
    assert.equal(category.catalogVersion, 3);
    assert.deepEqual(category.labels, labels);
    assert.equal(category.isActive, true);
    assert.ok(category.supportedCountries.includes("CO"));
  }

  assert.equal(catalog.some((category) => ["family", "children", "parents"].includes(category.id)), false);
});

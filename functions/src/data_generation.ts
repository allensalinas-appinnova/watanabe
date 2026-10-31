import {Timestamp, type DocumentSnapshot} from "firebase-admin/firestore";

/**
 * Checks whether a document belongs to the profile's current data generation.
 * Missing generations remain compatible with pre-generation profiles (0). After
 * a reset, they are accepted only when Firestore proves the document was
 * created after that reset completed.
 */
export function belongsToDataGeneration(
  snapshot: DocumentSnapshot,
  generation: number,
  resetCompletedAt: unknown,
): boolean {
  const data = snapshot.data();
  if (!data) return false;

  if (data.dataGeneration !== undefined) {
    return typeof data.dataGeneration === "number" &&
      Number.isSafeInteger(data.dataGeneration) && data.dataGeneration === generation;
  }
  if (generation === 0) return true;
  if (!(resetCompletedAt instanceof Timestamp)) return false;
  const createTime = snapshot.createTime;
  return createTime !== undefined && createTime.toMillis() > resetCompletedAt.toMillis();
}

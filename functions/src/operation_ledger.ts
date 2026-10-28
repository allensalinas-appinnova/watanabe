import {type DocumentReference, type Firestore, type Transaction} from "firebase-admin/firestore";
import {calculateProjectionDeltas, type Operation} from "./projection_model";

/** Keeps account-ledger rows in lockstep with the current confirmed operation. */
export async function prepareOperationLedgerWrites(
  transaction: Transaction,
  root: DocumentReference,
  operationId: string,
  current: Operation | undefined,
): Promise<() => void> {
  const operationRef = root.collection("operations").doc(operationId);
  const rootEntriesRef = root.collection("ledgerEntries");
  const nestedEntriesRef = operationRef.collection("entries");
  const [rootEntries, nestedEntries] = await Promise.all([
    transaction.get(rootEntriesRef.where("operationId", "==", operationId)),
    transaction.get(nestedEntriesRef),
  ]);
  const existingIds = new Set([
    ...rootEntries.docs.map((document) => document.id),
    ...nestedEntries.docs.map((document) => document.id),
  ]);
  const deltas = current?.status === "confirmed" ? [...calculateProjectionDeltas(undefined, current).accounts] : [];
  const selectedIds = [...existingIds].sort().slice(0, deltas.length);
  while (selectedIds.length < deltas.length) selectedIds.push(`${operationId}_entry_${selectedIds.length}`);
  const timestamp = current?.occurredAt;
  const generation = current?.dataGeneration ?? 0;
  const desired = deltas.map(([accountId, deltaMinor], index) => ({
    id: selectedIds[index],
    data: {
      operationId,
      accountId,
      deltaMinor,
      currency: current!.currency,
      ...(timestamp !== undefined ? {occurredAt: timestamp} : {}),
      dataGeneration: generation,
    },
  }));
  const desiredIds = new Set(desired.map((entry) => entry.id));
  return () => {
    for (const entry of desired) {
      transaction.set(rootEntriesRef.doc(entry.id), entry.data);
      transaction.set(nestedEntriesRef.doc(entry.id), entry.data);
    }
    for (const id of existingIds) {
      if (desiredIds.has(id)) continue;
      transaction.delete(rootEntriesRef.doc(id));
      transaction.delete(nestedEntriesRef.doc(id));
    }
  };
}

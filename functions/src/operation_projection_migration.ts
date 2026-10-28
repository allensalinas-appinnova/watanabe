import {randomUUID} from "node:crypto";
import {FieldPath, FieldValue, type Firestore, type QueryDocumentSnapshot} from "firebase-admin/firestore";
import {auditProjections} from "./projection_audit";
import {operationProjectionDigest, validId} from "./projection_model";

export class OperationProjectionMigrationError extends Error {
  constructor(readonly issue: string, readonly status: "unauthenticated" | "failed-precondition" | "unavailable" = "failed-precondition") {
    super(issue);
    this.name = "OperationProjectionMigrationError";
  }
}

/**
 * Marks legacy operation snapshots as projected only after a full read-only
 * audit confirms that every financial projection agrees with the source ledger.
 */
export async function ensureOperationProjectionVersion(db: Firestore, uid: string | undefined): Promise<void> {
  if (!uid || !validId(uid)) throw new OperationProjectionMigrationError("authentication-required", "unauthenticated");
  const root = db.doc(`users/${uid}`);
  const first = (await root.get()).data();
  if (!first || first.resetStatus === "resetting") throw new OperationProjectionMigrationError("user-reset-in-progress");
  if (first.operationProjectionVersion === 1) return;
  const migrationToken = randomUUID();

  const acquired = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(root);
    const profile = snapshot.data();
    if (!profile || profile.resetStatus === "resetting") throw new OperationProjectionMigrationError("user-reset-in-progress");
    if (profile.operationProjectionVersion === 1) return false;
    if (profile.operationProjectionMigration === "running") {
      const started = profile.operationProjectionMigrationStartedAt;
      const startedAt = started && typeof started.toMillis === "function" ? started.toMillis() : 0;
      if (startedAt > Date.now() - 5 * 60 * 1000) {
        throw new OperationProjectionMigrationError("operation-projection-migration-in-progress", "unavailable");
      }
    }
    transaction.update(root, {
      operationProjectionMigration: "running",
      operationProjectionMigrationToken: migrationToken,
      operationProjectionMigrationStartedAt: FieldValue.serverTimestamp(),
      operationProjectionMigrationIssue: FieldValue.delete(),
    });
    return true;
  });
  if (!acquired) return;

  try {
    const report = await auditProjections(db, uid);
    if (!report.complete || report.differences.length > 0) {
      throw new OperationProjectionMigrationError("operation-projection-reconciliation-required");
    }

    const writer = db.bulkWriter();
    const operations = root.collection("operations");
    let cursor: QueryDocumentSnapshot | undefined;
    for (;;) {
      let query = operations.orderBy(FieldPath.documentId()).limit(400);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const document of page.docs) {
        const digest = operationProjectionDigest(document.data());
        writer.update(document.ref, {
          operationProjectionDigest: digest,
          appliedProjectionDigest: digest,
          projectionUpdatedAt: FieldValue.serverTimestamp(),
        });
      }
      if (page.size < 400) break;
      cursor = page.docs.at(-1);
    }
    await writer.close();
    await db.runTransaction(async (transaction) => {
      const profile = (await transaction.get(root)).data();
      if (!profile || profile.resetStatus === "resetting" || profile.operationProjectionMigration !== "running" ||
          profile.operationProjectionMigrationToken !== migrationToken) {
        throw new OperationProjectionMigrationError("operation-projection-migration-interrupted");
      }
      transaction.update(root, {
        operationProjectionVersion: 1,
        operationProjectionMigration: "ready",
        operationProjectionMigrationToken: FieldValue.delete(),
        operationProjectionMigrationStartedAt: FieldValue.delete(),
        operationProjectionMigrationIssue: FieldValue.delete(),
      });
    });
  } catch (error) {
    await db.runTransaction(async (transaction) => {
      const profile = (await transaction.get(root)).data();
      if (profile?.operationProjectionMigration !== "running" || profile.operationProjectionMigrationToken !== migrationToken) return;
      transaction.update(root, {
        operationProjectionMigration: "idle",
        operationProjectionMigrationToken: FieldValue.delete(),
        operationProjectionMigrationStartedAt: FieldValue.delete(),
        operationProjectionMigrationIssue: error instanceof OperationProjectionMigrationError ? error.issue : "migration-failed",
      });
    }).catch(() => undefined);
    if (error instanceof OperationProjectionMigrationError) throw error;
    throw new OperationProjectionMigrationError("operation-projection-migration-failed");
  }
}

import {createHash} from "node:crypto";
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {compareProjections, readAuditSnapshotInTransaction, type ProjectionDifference} from "./projection_audit";
import {validId} from "./projection_model";

export type ProjectionRepairPlan = {
  requestId: string;
  expectedGeneration: number;
  expectedFingerprint: string;
  legacyAdjustmentId: string;
  expectedDifferences: ProjectionDifference[];
  operator: string;
  reason: string;
};

function canonicalDifferences(differences: ProjectionDifference[]): string {
  return JSON.stringify(differences.map(({document, field, expected, actual}) =>
    ({document, field, expected, actual})).sort((a, b) =>
    `${a.document}/${a.field}`.localeCompare(`${b.document}/${b.field}`)));
}

/**
 * Operator-only repair, deliberately not exported as a callable or run at login.
 * Archives a misclassified technical repair and fixes reviewed summary fields.
 * Never changes accounts, operations, ledger entries or projection-version gates.
 */
export async function reconcileProjectionRepair(db: Firestore, uid: string, plan: ProjectionRepairPlan) {
  if (!validId(uid) || !validId(plan.requestId) || !validId(plan.legacyAdjustmentId) ||
      !Number.isSafeInteger(plan.expectedGeneration) || plan.expectedGeneration < 0 ||
      !/^[a-f0-9]{64}$/.test(plan.expectedFingerprint) ||
      typeof plan.operator !== "string" || !plan.operator.trim() || plan.operator.length > 128 ||
      typeof plan.reason !== "string" || !plan.reason.trim() || plan.reason.length > 500 ||
      !Array.isArray(plan.expectedDifferences) || plan.expectedDifferences.length === 0) {
    throw new Error("invalid_repair_plan");
  }
  const digest = createHash("sha256").update(JSON.stringify({
    ...plan, expectedDifferences: canonicalDifferences(plan.expectedDifferences),
  })).digest("hex");
  const root = db.doc(`users/${uid}`);
  const receiptRef = root.collection("projectionRepairs").doc(plan.requestId);
  const adjustmentRef = root.collection("balanceAdjustments").doc(plan.legacyAdjustmentId);
  return db.runTransaction(async (transaction) => {
    const receipt = await transaction.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data()?.digest !== digest) throw new Error("repair_request_conflict");
      return receipt.data()!.result as {requestId: string; correctedFields: number};
    }
    const profile = (await transaction.get(root)).data();
    if (!profile || profile.resetStatus === "resetting" || profile.operationProjectionMigration === "running") {
      throw new Error("repair_user_unavailable");
    }
    if ((profile.dataGeneration ?? 0) !== plan.expectedGeneration) throw new Error("repair_stale_generation");
    const adjustment = await transaction.get(adjustmentRef);
    if (!adjustment.exists) throw new Error("repair_adjustment_missing");
    const snapshot = await readAuditSnapshotInTransaction(transaction, root);
    if (snapshot.fingerprint !== plan.expectedFingerprint) throw new Error("repair_snapshot_changed");
    const before = compareProjections(snapshot);
    if (!before.complete) throw new Error("repair_incomplete_audit");
    // Only the operator may classify this particular record as a technical
    // repair; neither its name nor its free-text reason is used to guess that.
    const balances = new Map(snapshot.accounts);
    const adjustments = snapshot.balanceAdjustments.get(plan.legacyAdjustmentId)?.adjustments;
    if (!Array.isArray(adjustments) || adjustments.length === 0 || adjustments.some((row) =>
      balances.get(row.accountId)?.currentBalanceMinor !== row.targetBalanceMinor)) {
      throw new Error("repair_balance_changed");
    }
    const financialAdjustments = new Map(snapshot.balanceAdjustments);
    financialAdjustments.delete(plan.legacyAdjustmentId);
    const withoutTechnicalRepair = {...snapshot, balanceAdjustments: financialAdjustments};
    const reviewed = compareProjections(withoutTechnicalRepair);
    if (!reviewed.complete || canonicalDifferences(reviewed.differences) !== canonicalDifferences(plan.expectedDifferences)) {
      throw new Error("repair_unreviewed_differences");
    }
    const summaries = new Map<string, Record<string, unknown>>();
    for (const difference of reviewed.differences) {
      const summaryId = /^monthlySummaries\/(\d{4}-(?:0[1-9]|1[0-2])_[A-Z]{3})$/.exec(difference.document)?.[1];
      if (!summaryId || typeof difference.expected !== "number" || !Number.isSafeInteger(difference.expected) ||
          !(difference.field === "expenseMinor" || difference.field.startsWith("byCategory."))) {
        throw new Error("repair_requires_separate_approval");
      }
      const summary = summaries.get(summaryId) ?? {
        ...snapshot.summaries.get(summaryId),
        byCategory: {...(snapshot.summaries.get(summaryId)?.byCategory as Record<string, number> ?? {})},
      };
      if (difference.field === "expenseMinor") summary.expenseMinor = difference.expected;
      else (summary.byCategory as Record<string, number>)[difference.field.slice("byCategory.".length)] = difference.expected;
      summaries.set(summaryId, summary);
    }
    const finalSummaries = new Map(snapshot.summaries);
    for (const [id, value] of summaries) finalSummaries.set(id, value);
    const after = compareProjections({...withoutTechnicalRepair, summaries: finalSummaries});
    if (!after.complete || after.differences.length > 0) throw new Error("repair_does_not_reconcile");
    const result = {requestId: plan.requestId, correctedFields: reviewed.differences.length};
    for (const [id, value] of summaries) transaction.update(root.collection("monthlySummaries").doc(id), {
      expenseMinor: value.expenseMinor, byCategory: value.byCategory, updatedAt: FieldValue.serverTimestamp(),
    });
    // Preserve the original event verbatim, but outside the financial ledger:
    // it fixed a cache, not a genuine increase in the user's money.
    transaction.create(receiptRef, {
      kind: "projection-only", digest, dataGeneration: plan.expectedGeneration,
      operator: plan.operator, reason: plan.reason, sourcePath: adjustmentRef.path,
      originalAdjustment: adjustment.data(), sourceRemovedFromFinancialAdjustments: true,
      before, correctedDifferences: reviewed.differences, after,
      preservedAccountBalances: Object.fromEntries([...snapshot.accounts].map(([id, account]) => [id, account.currentBalanceMinor])),
      result, createdAt: FieldValue.serverTimestamp(),
    });
    transaction.delete(adjustmentRef);
    return result;
  });
}

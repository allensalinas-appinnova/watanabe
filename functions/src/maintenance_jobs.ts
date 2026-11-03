import {randomUUID} from "node:crypto";
import {FieldPath, Timestamp, type Firestore, type Transaction} from "firebase-admin/firestore";

export type JobLease = {id: string; runId: string; cutoff: Timestamp; assert: (tx: Transaction) => Promise<void>};
/** One owner, bounded user pages, and a durable cursor; callbacks publish only complete user results. */
export async function runUserMaintenance(db: Firestore, id: string,
  process: (uid: string, lease: JobLease, deadline: number) => Promise<boolean>, budgetMs = 360000, cutoff = Timestamp.now()) {
  const ref = db.doc(`maintenanceJobs/${id}`), worker = randomUUID(), deadline = Date.now() + budgetMs;
  const start = await db.runTransaction(async tx => {
    const row = await tx.get(ref), d = row.data() ?? {};
    if ((d.leaseUntil?.toMillis() ?? 0) > Date.now()) return null;
    const next = d.status === "running" ? d : {runId: randomUUID(), cursor: null, cutoff};
    tx.set(ref, {...next, worker, status: "running", leaseUntil: Timestamp.fromMillis(Date.now() + 540000),
      expiresAt: Timestamp.fromMillis(Date.now() + 90 * 86400000)});
    return next;
  });
  if (!start) return;
  const lease: JobLease = {id, runId: start.runId, cutoff: start.cutoff, assert: async tx => {
    const row = await tx.get(ref);
    if (row.get("worker") !== worker || row.get("runId") !== start.runId || row.get("leaseUntil").toMillis() < Date.now()) throw Error("maintenance-lease-lost");
  }};
  let cursor = start.cursor as string | null;
  try {
    while (Date.now() < deadline) {
      let query = db.collection("resourceUsage").orderBy(FieldPath.documentId()).limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      if (page.empty) {
        await db.runTransaction(async tx => { await lease.assert(tx); tx.update(ref, {status: "complete", cursor: null, completedAt: Timestamp.now(), leaseUntil: Timestamp.fromMillis(0)}); });
        return;
      }
      for (const user of page.docs) {
        if (Date.now() >= deadline) return;
        if (!(await db.doc(`accountDeletions/${user.id}`).get()).exists && !await process(user.id, lease, deadline)) return;
        cursor = user.id;
        await db.runTransaction(async tx => {
          await lease.assert(tx);
          const deleting = await tx.get(db.doc(`accountDeletions/${user.id}`));
          if (!deleting.exists) tx.update(ref, {cursor});
        });
      }
    }
  } finally {
    await db.runTransaction(async tx => {
      const row = await tx.get(ref); if (row.get("worker") === worker) tx.update(ref, {leaseUntil: Timestamp.fromMillis(0)});
    });
  }
}

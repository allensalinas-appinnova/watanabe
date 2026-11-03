import {createHash, randomUUID} from "node:crypto";
import {getAuth, type Auth} from "firebase-admin/auth";
import {FieldValue, Timestamp, type Firestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {getFunctions} from "firebase-admin/functions";
import {onTaskDispatched} from "firebase-functions/v2/tasks";
import {onSchedule} from "firebase-functions/v2/scheduler";

const retentionMs = 90 * 86400000;
export async function assertAccountActive(db: Firestore, uid: string) {
  if ((await db.doc(`accountDeletions/${uid}`).get()).exists) {
    throw new HttpsError("failed-precondition", "account-deletion-requested");
  }
}

/** Persists acceptance before revocation; never treats an email as ownership. */
export async function acceptAccountDeletion(db: Firestore, uid: string | undefined,
  token: Record<string, any> | undefined, value: unknown, now = new Date()) {
  if (!uid) throw new HttpsError("unauthenticated", "session-expired");
  const p = value as Record<string, unknown>;
  if (!p || typeof p !== "object" || Object.keys(p).some(k => !["requestId", "expectedOwnerUid", "expectedGeneration", "confirmed"].includes(k)) ||
    typeof p.requestId !== "string" || !/^[\w-]{8,128}$/.test(p.requestId) ||
    !Number.isSafeInteger(p.expectedGeneration) || Number(p.expectedGeneration) < 0 || p.confirmed !== true) {
    throw new HttpsError("invalid-argument", "account-deletion-invalid");
  }
  if (p.expectedOwnerUid !== uid) throw new HttpsError("permission-denied", "account-deletion-owner-mismatch");
  const requestDigest = createHash("sha256").update(JSON.stringify([p.requestId, p.expectedGeneration, true])).digest("hex");
  return db.runTransaction(async tx => {
    const marker = db.doc(`accountDeletions/${uid}`), profile = db.doc(`users/${uid}`);
    const [prior, user] = await Promise.all([tx.get(marker), tx.get(profile)]);
    if (prior.exists) {
      if (prior.get("requestId") !== p.requestId || prior.get("requestDigest") !== requestDigest) throw new HttpsError("already-exists", "account-deletion-requested");
      return {status: "accepted", requestId: p.requestId};
    }
    if (token?.firebase?.sign_in_provider !== "anonymous" &&
        (typeof token?.auth_time !== "number" || now.getTime() / 1000 - token.auth_time > 300 || token.auth_time > now.getTime() / 1000 + 60)) {
      throw new HttpsError("unauthenticated", "requires-recent-login");
    }
    if ((user.get("dataGeneration") ?? 0) !== p.expectedGeneration || user.get("resetStatus") === "resetting") {
      throw new HttpsError("failed-precondition", "account-deletion-generation-conflict");
    }
    tx.create(marker, {requestDigest, requestId: p.requestId, status: "requested", stage: "block", attempts: 0,
      createdAt: Timestamp.fromDate(now)});
    // Existing command transactions read this profile, so acceptance invalidates in-flight generations.
    tx.set(profile, {resetStatus: "resetting", dataGeneration: Number(p.expectedGeneration) + 1,
      updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    return {status: "accepted", requestId: p.requestId};
  });
}

type Dependencies = {auth?: Pick<Auth, "updateUser" | "revokeRefreshTokens" | "deleteUser">;
  deleteFiles?: (uid: string) => Promise<void>; bucketName?: string; afterStage?: (stage: string) => Promise<void>};

/** Checkpointed worker: every destructive step is safe to repeat after a lost response. */
export async function completeAccountDeletion(db: Firestore, uid: string, deps: Dependencies = {}) {
  const ref = db.doc(`accountDeletions/${uid}`), worker = randomUUID(), auth = deps.auth ?? getAuth();
  const claimed = await db.runTransaction(async tx => {
    const row = await tx.get(ref);
    if (!row.exists || row.get("status") === "complete" || (row.get("leaseUntil")?.toMillis() ?? 0) > Date.now()) return false;
    tx.update(ref, {worker, status: "working", leaseUntil: Timestamp.fromMillis(Date.now() + 600000), attempts: FieldValue.increment(1)});
    return true;
  });
  if (!claimed) return;
  async function checkpoint(stage: string) {
    await db.runTransaction(async tx => {
      const row = await tx.get(ref);
      if (row.get("worker") !== worker) throw new Error("deletion-lease-lost");
      tx.update(ref, {stage, leaseUntil: Timestamp.fromMillis(Date.now() + 600000)});
    });
    await deps.afterStage?.(stage);
  }
  async function ignoreMissing(action: () => Promise<unknown>) {
    try { await action(); } catch (e: any) { if (e?.code !== "auth/user-not-found") throw e; }
  }
  try {
    await ignoreMissing(() => auth.updateUser(uid, {disabled: true}));
    await ignoreMissing(() => auth.revokeRefreshTokens(uid));
    await checkpoint("files");
    await (deps.deleteFiles ?? (async id => {
      const bucket = getStorage().bucket(deps.bucketName);
      let pageToken: string | undefined;
      do {
        const [files, next] = await bucket.getFiles({prefix: `users/${id}/`, maxResults: 250, autoPaginate: false, pageToken});
        for (const file of files) {
          try { const [m] = await file.getMetadata(); await file.delete({ifGenerationMatch: m.generation}); }
          catch (e: any) { if (e?.code !== 404) throw e; }
        }
        pageToken = next?.pageToken;
      } while (pageToken);
    }))(uid);
    await checkpoint("documents");
    await db.runTransaction(async tx => {
      const marker = await tx.get(ref);
      if (marker.get("anonymized") === true) return;
      const costs = await tx.get(db.collection(`resourceUsage/${uid}/costs`));
      for (const cost of costs.docs) {
        const subtotal = cost.get("knownSubtotalUsd");
        if (typeof subtotal === "number" && Number.isFinite(subtotal)) {
          tx.set(db.doc(`anonymousUsageTotals/${cost.id}`), {knownSubtotalUsd: FieldValue.increment(subtotal),
            expiresAt: Timestamp.fromMillis(Date.now() + 400 * 86400000)}, {merge: true});
        }
      }
      tx.update(ref, {anonymized: true});
    });
    const writer = db.bulkWriter();
    writer.onWriteError(error => [2, 4, 10, 13, 14].includes(error.code) && error.failedAttempts < 5);
    try {
      await db.recursiveDelete(db.doc(`users/${uid}`), writer);
      await db.recursiveDelete(db.doc(`resourceUsage/${uid}`), writer);
    } finally { await writer.close(); }
    // Administrative audit is operational data but target/actor identifiers must not survive deletion.
    for (const field of ["targetUid", "actorUid"]) {
      while (true) {
        const rows = await db.collection("adminAudit").where(field, "==", uid).limit(250).get();
        if (rows.empty) break;
        const batch = db.batch(); for (const row of rows.docs) batch.update(row.ref, {[field]: FieldValue.delete()});
        await batch.commit();
      }
    }
    // Invalidate jobs whose technical cursor still identifies this deleted UID.
    // A concurrent checkpoint reads the marker and cannot put the UID back.
    const jobs = await db.collection("maintenanceJobs").where("cursor", "==", uid).get();
    for (const job of jobs.docs) await db.runTransaction(async tx => {
      const current = await tx.get(job.ref);
      if (current.get("cursor") === uid) tx.update(job.ref, {
        cursor: null, worker: null, runId: randomUUID(), leaseUntil: Timestamp.fromMillis(0),
      });
    });
    await db.doc(`adminOperators/${uid}`).delete();
    await checkpoint("identity");
    await ignoreMissing(() => auth.deleteUser(uid));
    await db.runTransaction(async tx => {
      const row = await tx.get(ref); if (row.get("worker") !== worker) return;
      // Minimal temporary marker; no email, amounts, file references or per-user usage.
      tx.set(ref, {requestDigest: row.get("requestDigest"), requestId: row.get("requestId"), status: "complete", completedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(Date.now() + retentionMs)});
    });
  } catch (error) {
    await db.runTransaction(async tx => {
      const row = await tx.get(ref);
      if (row.get("worker") === worker) tx.update(ref, {status: "failed", leaseUntil: FieldValue.delete(), issue: "account-deletion-incomplete"});
    });
    throw error;
  }
}

export const requestAccountDeletion = onCall({region: "us-central1", enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true"},
  async request => {
    const db = getFirestoreForDeletion();
    if (!request.auth) throw new HttpsError("unauthenticated", "session-expired");
    if (process.env.FUNCTIONS_EMULATOR !== "true" && (await db.doc("servicePolicies/accountLifecycle").get()).get("deletionEnabled") !== true) {
      throw new HttpsError("failed-precondition", "account-deletion-not-enabled");
    }
    const accepted = await acceptAccountDeletion(db, request.auth.uid, request.auth.token, request.data);
    // Explicit durable dispatch complements the persisted outbox/trigger. An enqueue
    // failure must not misreport an already accepted deletion as rejected.
    try {
      const id = createHash("sha256").update(JSON.stringify([request.auth.uid, accepted.requestId])).digest("hex");
      await getFunctions().taskQueue("processAccountDeletionTask").enqueue(
        {uid: request.auth.uid, requestId: accepted.requestId}, {id, dispatchDeadlineSeconds: 540});
    } catch (error: any) {
      if (error?.code !== "functions/task-already-exists") console.warn(JSON.stringify({issue: "account-deletion-dispatch-delayed"}));
    }
    return accepted;
  });
// Resolve lazily: index initializes the default Admin app during module loading.
import {getFirestore as getFirestoreForDeletion} from "firebase-admin/firestore";
export const processAccountDeletion = onDocumentWritten({document: "accountDeletions/{uid}", region: "us-central1", timeoutSeconds: 540, memory: "1GiB", retry: true},
  event => {
    const before = event.data?.before.data(), after = event.data?.after.data();
    if (after?.status !== "requested" || before?.status === "requested") return;
    return completeAccountDeletion(getFirestoreForDeletion(), event.params.uid).catch(() => { throw new Error("account-deletion-incomplete"); });
  });
export const retryAccountDeletions = onSchedule({region: "us-central1", schedule: "every 15 minutes", timeoutSeconds: 540, memory: "1GiB"}, async () => {
  const db = getFirestoreForDeletion();
  const rows = await db.collection("accountDeletions").where("status", "in", ["requested", "working", "failed"]).limit(100).get();
  for (const row of rows.docs) await completeAccountDeletion(db, row.id).catch(() => console.error('account-deletion-incomplete'));
});

/** Internal IAM-authenticated queue; UID comes exclusively from server-enqueued work. */
export const processAccountDeletionTask = onTaskDispatched({region: "us-central1",
  invoker: process.env.FUNCTIONS_EMULATOR === "true" ? "private" : ["609783556202-compute@developer.gserviceaccount.com"], timeoutSeconds: 540,
  memory: "1GiB", retryConfig: {maxAttempts: 10, minBackoffSeconds: 10}, rateLimits: {maxConcurrentDispatches: 2}}, async request => {
  const data = request.data as {uid?: unknown; requestId?: unknown};
  if (typeof data?.uid !== "string" || typeof data?.requestId !== "string") throw Error("deletion-task-invalid");
  const db = getFirestoreForDeletion(), marker = await db.doc(`accountDeletions/${data.uid}`).get();
  if (!marker.exists || marker.get("requestId") !== data.requestId || marker.get("status") === "complete") return;
  await completeAccountDeletion(db, data.uid).catch(() => { throw new Error("account-deletion-incomplete"); });
});

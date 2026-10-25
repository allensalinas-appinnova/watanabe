import {randomUUID} from "node:crypto";
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {validId} from "./projection_model";

type ResetCommand = {requestId: string; expectedGeneration: number; confirmed: true};
type ResetResult = {requestId: string; dataGeneration: number; status: "complete"};

export class UserDataResetError extends Error {
  constructor(readonly issue: string, readonly status: "unauthenticated" | "invalid-argument" | "failed-precondition") {
    super(issue);
    this.name = "UserDataResetError";
  }
}

function parse(payload: unknown): ResetCommand {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new UserDataResetError("reset-invalid-command", "invalid-argument");
  }
  const data = payload as Record<string, unknown>;
  if (Object.keys(data).some((key) => !["requestId", "expectedGeneration", "confirmed"].includes(key)) ||
      !validId(data.requestId) || !/^[A-Za-z0-9_-]{8,128}$/.test(data.requestId) ||
      !Number.isSafeInteger(data.expectedGeneration) || Number(data.expectedGeneration) < 0 ||
      data.confirmed !== true) {
    throw new UserDataResetError("reset-invalid-command", "invalid-argument");
  }
  return {requestId: data.requestId as string, expectedGeneration: data.expectedGeneration as number, confirmed: true};
}

/**
 * Invalidates all old-generation writes before recursively deleting user data.
 * A retry with the same requestId resumes a partial deletion safely.
 */
export async function executeUserDataReset(
  db: Firestore,
  uid: string | undefined,
  payload: unknown,
): Promise<ResetResult> {
  if (!uid || !validId(uid)) throw new UserDataResetError("reset-session-expired", "unauthenticated");
  const command = parse(payload);
  const workerToken = randomUUID();
  const root = db.doc(`users/${uid}`);
  const start = await db.runTransaction(async (tx) => {
    const profile = await tx.get(root);
    if (!profile.exists) throw new UserDataResetError("reset-profile-missing", "failed-precondition");
    const data = profile.data()!;
    const generation = Number.isSafeInteger(data.dataGeneration) ? data.dataGeneration as number : 0;
    const status = data.resetStatus ?? "ready";
    if (data.resetRequestId === command.requestId && status === "ready" &&
        data.resetPreviousGeneration === command.expectedGeneration) {
      return {generation, completed: true};
    }
    if (status === "resetting") {
      if (data.resetRequestId !== command.requestId ||
          data.resetPreviousGeneration !== command.expectedGeneration) {
        throw new UserDataResetError("reset-already-in-progress", "failed-precondition");
      }
      if (typeof data.resetLeaseUntil === "number" && data.resetLeaseUntil > Date.now()) {
        throw new UserDataResetError("reset-already-in-progress", "failed-precondition");
      }
      tx.update(root, {resetWorkerToken: workerToken, resetLeaseUntil: Date.now() + 120_000});
      return {generation, completed: false};
    }
    if (generation !== command.expectedGeneration) {
      throw new UserDataResetError("reset-generation-conflict", "failed-precondition");
    }
    const nextGeneration = generation + 1;
    tx.update(root, {
      dataGeneration: nextGeneration,
      resetStatus: "resetting",
      resetRequestId: command.requestId,
      resetPreviousGeneration: generation,
      resetWorkerToken: workerToken,
      resetLeaseUntil: Date.now() + 120_000,
      resetStartedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {generation: nextGeneration, completed: false};
  });

  if (start.completed) return {requestId: command.requestId, dataGeneration: start.generation, status: "complete"};

  // User data lives only under users/{uid}; the shared categoryCatalog is outside
  // this document and is intentionally preserved. recursiveDelete includes
  // arbitrarily nested operation entries and budget items.
  let renewing = false;
  let leaseLost = false;
  const heartbeat = setInterval(() => {
    if (renewing || leaseLost) return;
    renewing = true;
    void db.runTransaction(async (tx) => {
      const profile = (await tx.get(root)).data();
      if (profile?.resetStatus !== "resetting" || profile.resetWorkerToken !== workerToken) {
        leaseLost = true;
        return;
      }
      tx.update(root, {resetLeaseUntil: Date.now() + 120_000});
    }).catch(() => { leaseLost = true; }).finally(() => { renewing = false; });
  }, 30_000);
  heartbeat.unref?.();
  try {
    const collections = await root.listCollections();
    for (const collection of collections) {
      if (leaseLost) throw new UserDataResetError("reset-lease-lost", "failed-precondition");
      await db.recursiveDelete(collection);
    }

    await db.runTransaction(async (tx) => {
      const profile = (await tx.get(root)).data();
      if (profile?.resetStatus !== "resetting" || profile.resetWorkerToken !== workerToken) {
        throw new UserDataResetError("reset-lease-lost", "failed-precondition");
      }
      tx.set(root, {
        dataGeneration: start.generation,
        resetStatus: "ready",
        resetRequestId: command.requestId,
        resetPreviousGeneration: command.expectedGeneration,
        resetCompletedAt: FieldValue.serverTimestamp(),
        onboardingStatus: "not_started",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return {requestId: command.requestId, dataGeneration: start.generation, status: "complete"};
  } catch (error) {
    await db.runTransaction(async (tx) => {
      const profile = (await tx.get(root)).data();
      if (profile?.resetStatus === "resetting" && profile.resetWorkerToken === workerToken) {
        tx.update(root, {resetWorkerToken: FieldValue.delete(), resetLeaseUntil: FieldValue.delete()});
      }
    }).catch(() => {});
    throw error;
  } finally {
    clearInterval(heartbeat);
  }
}

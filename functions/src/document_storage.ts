import {randomUUID} from "node:crypto";
import {FieldValue, Timestamp, type Firestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {HttpsError} from "firebase-functions/v2/https";
import {readyProfile, trackDocumentObject} from "./document_imports";
import {eventId, recordUsage, recordStorageTime, releaseAnalysis, type Data} from "./resource_usage";

/** Claim deletion first: financial approval cannot race a cleanup that already won. */
export async function discardDocument(db: Firestore, uid: string, importId: string, generation?: number, expired = false) {
  const root = db.doc(`users/${uid}`), ref = root.collection("documentImports").doc(importId);
  const data = await db.runTransaction(async tx => {
    if (generation !== undefined) await readyProfile(tx, root, generation);
    const row = await tx.get(ref); const d = row.data();
    if (!d || ["approved", "discarded", "expired"].includes(d.status) || (expired && (d.expiresAt?.toMillis() ?? Infinity) > Date.now())) return null;
    if (d.status === "analyzing" && d.leaseUntil?.toMillis() > Date.now()) throw new HttpsError("failed-precondition", "document-analysis-running");
    tx.update(ref, {status: "deleting", updatedAt: FieldValue.serverTimestamp()});
    return d;
  });
  if (!data) return;
  const file = getStorage().bucket().file(data.storagePath);
  const [exists] = await file.exists();
  if (exists) {
    const [metadata] = await file.getMetadata();
    await file.delete({ifGenerationMatch: metadata.generation});
    await trackDocumentObject(db, metadata, true);
  }
  await db.runTransaction(async tx => {
    const row = await tx.get(ref); if (!row.exists || row.get("status") !== "deleting") return;
    const d = row.data()!;
    const delta: Data = {attachmentReservedBytes: FieldValue.increment(-d.size), updatedAt: FieldValue.serverTimestamp()};
    if (!d.storageUploaded) { delta.reservedBytes = FieldValue.increment(-d.size); delta.reservedFiles = FieldValue.increment(-1); }
    tx.set(db.doc(`resourceUsage/${uid}`), delta, {merge: true});
    tx.update(ref, {status: expired ? "expired" : "discarded", extraction: FieldValue.delete(), expiresAt: FieldValue.delete(), updatedAt: FieldValue.serverTimestamp()});
  });
}

export async function deleteAttachment(db: Firestore, uid: string, p: Data) {
  const root = db.doc(`users/${uid}`);
  if (typeof p.attachmentId !== "string" || !/^[\w-]{8,100}$/.test(p.attachmentId)) throw new HttpsError("invalid-argument", "attachment-invalid");
  const ref = root.collection("attachments").doc(p.attachmentId);
  const d = await db.runTransaction(async tx => {
    await readyProfile(tx, root, p.expectedGeneration);
    const s = await tx.get(ref);
    if (!s.exists || s.get("status") === "deleted") return null;
    if (s.get("dataGeneration") !== p.expectedGeneration) throw new HttpsError("failed-precondition", "stale-data-generation");
    tx.update(ref, {status: "deleting", updatedAt: FieldValue.serverTimestamp()});
    return s.data()!;
  });
  if (!d) return {status: "deleted"};
  const file = getStorage().bucket().file(d.storagePath);
  const [exists] = await file.exists();
  if (exists) {
    const [m] = await file.getMetadata();
    await file.delete({ifGenerationMatch: m.generation});
    await trackDocumentObject(db, m, true);
  }
  if (!exists && d.objectGeneration) {
    await trackDocumentObject(db, {name: d.storagePath, generation: d.objectGeneration, size: d.size}, true);
  }
  await ref.update({status: "deleted", version: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp()});
  return {status: "deleted"};
}

export async function readAttachment(db: Firestore, uid: string, p: Data) {
  if (typeof p.attachmentId !== "string" || !/^[\w-]{8,100}$/.test(p.attachmentId)) throw new HttpsError("invalid-argument", "attachment-invalid");
  const root = db.doc(`users/${uid}`);
  const [profile, attachment] = await Promise.all([root.get(), root.collection("attachments").doc(p.attachmentId).get()]);
  if (!profile.exists || profile.get("resetStatus") === "resetting" || !attachment.exists || attachment.get("status") !== "active" ||
    attachment.get("dataGeneration") !== (profile.get("dataGeneration") ?? 0)) throw new HttpsError("not-found", "attachment-unavailable");
  const file = getStorage().bucket().file(attachment.get("storagePath"), {generation: attachment.get("objectGeneration")});
  const [bytes] = await file.download();
  await recordUsage(db, uid, `download:${randomUUID()}`, "storage", {downloads: 1, servedBytes: bytes.length});
  return {contentType: attachment.get("contentType"), data: bytes.toString("base64")};
}

export async function cleanupExpiredDocuments(db: Firestore) {
  const abandoned = await db.collectionGroup("analysisReservations").where("leaseUntil", "<=", Timestamp.now()).limit(200).get();
  for (const row of abandoned.docs) {
    if (row.get("state") === "charged") await releaseAnalysis(db, row.ref.parent.parent!.id, row.get("importId"), row.id);
  }
  const rows = await db.collectionGroup("documentImports").where("expiresAt", "<=", Timestamp.now()).limit(200).get();
  for (const row of rows.docs) await discardDocument(db, row.ref.parent.parent!.id, row.id, undefined, true).catch(() => {});
  const deleting = await db.collectionGroup("attachments").where("status", "==", "deleting").limit(200).get();
  for (const row of deleting.docs) {
    const uid = row.ref.parent.parent!.id;
    const profile = await db.doc(`users/${uid}`).get();
    if (profile.exists && profile.get("resetStatus") !== "resetting") await deleteAttachment(db, uid,
      {attachmentId: row.id, expectedGeneration: profile.get("dataGeneration") ?? 0}).catch(() => {});
  }
}

/** Called while resetStatus=resetting; all prefixes use the owning UID and old generations. */
export async function deleteUserDocuments(db: Firestore, uid: string, beforeGeneration: number) {
  const bucket = getStorage().bucket();
  const [files] = await bucket.getFiles({prefix: `users/${uid}/`});
  for (const file of files) {
    const m = /^users\/[^/]+\/documentImports\/(\d+)\//.exec(file.name);
    if (m && Number(m[1]) >= beforeGeneration) continue;
    const [metadata] = await file.getMetadata();
    await file.delete({ifGenerationMatch: metadata.generation});
    await trackDocumentObject(db, metadata, true);
  }
  // Remaining reservations are for data that reset is about to remove, never usage quotas.
  await db.doc(`resourceUsage/${uid}`).set({reservedBytes: 0, reservedFiles: 0, attachmentReservedBytes: 0,
    updatedAt: FieldValue.serverTimestamp()}, {merge: true});
}

export async function inventoryDocumentStorage(db: Firestore) {
  const bucket = getStorage().bucket();
  const [files] = await bucket.getFiles({prefix: "users/"});
  const present = new Set<string>();
  for (const file of files) {
    if (!/^users\/[^/]+\/documentImports\//.test(file.name)) continue;
    const [m] = await file.getMetadata();
    present.add(eventId(`${m.name}:${m.generation}`));
    await trackDocumentObject(db, m, false);
    const [, uid, , generation, id] = file.name.split("/");
    const [p, proposal] = await Promise.all([db.doc(`users/${uid}`).get(), db.doc(`users/${uid}/documentImports/${id}`).get()]);
    if (!p.exists || !proposal.exists || ["discarded", "expired", "deleting"].includes(proposal.get("status")) || (p.get("dataGeneration") ?? 0) !== Number(generation)) {
      await file.delete({ifGenerationMatch: m.generation}); await trackDocumentObject(db, m, true);
    }
  }
  const subjects = await db.collection("resourceUsage").get();
  for (const subject of subjects.docs) {
    const objects = await subject.ref.collection("objects").get();
    let attachmentBytes = 0, attachmentFiles = 0, temporaryBytes = 0, temporaryFiles = 0;
    for (const object of objects.docs) {
      const d = object.data();
      if (d.deleted) continue;
      if (!present.has(object.id)) { await trackDocumentObject(db, {name: d.storagePath, generation: d.objectGeneration, size: d.bytes}, true); continue; }
      if (d.retained) { attachmentBytes += d.bytes; attachmentFiles++; } else { temporaryBytes += d.bytes; temporaryFiles++; }
    }
    // Inventory is a reconciliation diagnostic, never a blind overwrite racing uploads.
    const latest = await subject.ref.get();
    const observed = attachmentBytes + temporaryBytes;
    const accounted = (latest.get("attachmentBytes") ?? 0) + (latest.get("temporaryBytes") ?? 0);
    const now = Date.now();
    await recordStorageTime(db, subject.id);
    await subject.ref.set({inventoryAt: Timestamp.fromMillis(now), inventoryObservedBytes: observed,
      inventoryDifferenceBytes: observed - accounted, inventoryQuality: observed === accounted ? "measured" : "pending",
      inventoryAttachmentFiles: attachmentFiles, inventoryTemporaryFiles: temporaryFiles}, {merge: true});
  }
}

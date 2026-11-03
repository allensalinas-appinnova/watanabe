import {Timestamp, FieldValue, type Firestore} from "firebase-admin/firestore";
import {eventId, type Data} from "./resource_usage";

export type StorageCapacityScope = {bucket: string; region: string; storageClass: string};

/** Location is deployment-verified; class must come from the object's provider metadata. */
export function storageCapacityScope(metadata: {bucket?: string; storageClass?: string}): StorageCapacityScope | null {
  if (!process.env.RESOURCE_STORAGE_BUCKET || metadata.bucket !== process.env.RESOURCE_STORAGE_BUCKET ||
      !process.env.RESOURCE_STORAGE_LOCATION || typeof metadata.storageClass !== "string" || !/^[A-Z_]{1,40}$/.test(metadata.storageClass)) return null;
  return {bucket: metadata.bucket, region: process.env.RESOURCE_STORAGE_LOCATION, storageClass: metadata.storageClass};
}

/** Bounded chunks prevent long outages from exceeding Firestore's transaction write limit. */
export function capacityDaySegments(from: number, until: number, bytes: number) {
  if (!Number.isFinite(from) || !Number.isFinite(until) || !Number.isSafeInteger(bytes) || bytes < 0 || until < from) throw new Error("capacity-interval-invalid");
  const end = Math.min(until, from + 31 * 86400000), segments = [];
  for (let cursor = from; cursor < end;) {
    const date = new Date(cursor); const next = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + 1);
    const to = Math.min(end, next);
    segments.push({from: cursor, until: to, day: date.toISOString().slice(0, 10), byteHours: bytes * (to - cursor) / 3600000});
    cursor = to;
  }
  return {segments, through: end};
}

/** Metering only: never changes occupied bytes, reservations, files, imports or financial records. */
export async function observeStorageCapacity(db: Firestore, uid: string, objectId: string, scope: StorageCapacityScope | null, now = new Date()) {
  const root = db.doc(`resourceUsage/${uid}`), meter = root.collection("storageCapacityMeters").doc(objectId);
  const objectRef = root.collection("objects").doc(objectId), at = now.getTime();
  if (!Number.isFinite(at)) throw new Error("capacity-time-invalid");
  // A large gap is resumable: persist each completed chunk and leave the rest for the next observation.
  for (let chunk = 0; chunk < 8; chunk++) {
    const more = await db.runTransaction(async tx => {
      if ((await tx.get(db.doc(`accountDeletions/${uid}`))).exists) return false;
    const [object, checkpoint] = await Promise.all([tx.get(objectRef), tx.get(meter)]);
      if (!object.exists || checkpoint.get("closed") === true) return false;
      const bytes = object.get("bytes"); if (!Number.isSafeInteger(bytes) || bytes < 0) throw new Error("capacity-bytes-invalid");
      const deleted = object.get("deleted") === true;
      // Missing deletion metadata can reuse the last observed scope, never a bucket's default class.
      const current = deleted && scope === null ? checkpoint.get("scope") ?? null : scope;
      const baseline: Data = {bytes, scope: current, throughAt: Timestamp.fromMillis(at), closed: deleted, updatedAt: Timestamp.fromMillis(at),
        ...(deleted ? {expiresAt: Timestamp.fromMillis(at + 90 * 86400000)} : {})};
      if (!checkpoint.exists) {
        if (!deleted) {
          tx.create(meter, {...baseline, startedAt: Timestamp.fromMillis(at)});
          tx.set(root, {storageCapacityObservedAt: Timestamp.fromMillis(at)}, {merge: true});
        }
        return false;
      }
      const from = checkpoint.get("throughAt").toMillis(); if (at <= from) return false;
      const previousScope = checkpoint.get("scope");
      const same = previousScope && current && previousScope.bucket === current.bucket && previousScope.region === current.region &&
        previousScope.storageClass === current.storageClass && checkpoint.get("bytes") === bytes;
      const {segments, through} = capacityDaySegments(from, at, checkpoint.get("bytes"));
      const periods: Record<string, number> = {};
      for (const segment of segments) {
        const id = eventId(`${uid}:capacity:${objectId}:${segment.from}:${segment.until}`);
        tx.create(root.collection("events").doc(id), {service: "storage", units: {byteHours: segment.byteHours},
          quality: same ? "estimated" : "pending", costSource: "object-capacity-observation",
          ...(same ? {region: current.region, storageClass: current.storageClass} : {}),
          intervalFrom: Timestamp.fromMillis(segment.from), intervalUntil: Timestamp.fromMillis(segment.until),
          createdAt: Timestamp.fromMillis(segment.from), expiresAt: Timestamp.fromMillis(at + 90 * 86400000)});
        for (const period of [`day_${segment.day}`, `month_${segment.day.slice(0, 7)}`]) periods[period] = (periods[period] ?? 0) + segment.byteHours;
      }
      for (const [period, hours] of Object.entries(periods)) tx.set(root.collection("periods").doc(period), {
        [same ? "storage_classifiedByteHours" : "storage_unclassifiedByteHours"]: FieldValue.increment(hours),
        updatedAt: Timestamp.fromMillis(at), expiresAt: Timestamp.fromMillis(at + 400 * 86400000),
      }, {merge: true});
      const finished = through === at;
      tx.set(meter, finished ? baseline : {throughAt: Timestamp.fromMillis(through), updatedAt: Timestamp.fromMillis(at)}, {merge: true});
      if (finished) tx.set(root, {storageCapacityObservedAt: Timestamp.fromMillis(at)}, {merge: true});
      return !finished;
    });
    if (!more) return;
  }
}

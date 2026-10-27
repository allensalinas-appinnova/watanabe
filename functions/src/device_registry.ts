import {FieldValue, Firestore, Timestamp} from "firebase-admin/firestore";

const DAY_MS = 24 * 60 * 60 * 1000;
const RETENTION_DAYS = 90;
const INSTALLATION_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PLATFORMS = new Set(["android", "ios", "web"]);

export class DeviceRegistryError extends Error {
  constructor(readonly status: "unauthenticated" | "invalid-argument", readonly issue: string) {
    super(issue);
  }
}

/** Records a pseudonymous app installation without collecting hardware identity. */
export async function executeDeviceRegistryCommand(
  db: Firestore,
  uid: string | undefined,
  data: unknown,
  now: Date = new Date(),
): Promise<{status: "registered" | "removed"; installationId: string}> {
  if (!uid) throw new DeviceRegistryError("unauthenticated", "authentication-required");
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new DeviceRegistryError("invalid-argument", "invalid-payload");
  }
  const input = data as Record<string, unknown>;
  if (input.action === "remove") {
    validateId(input.installationId);
    await db.doc(`users/${uid}/devices/${input.installationId}`).delete();
    return {status: "removed", installationId: input.installationId};
  }
  if (input.action !== "register") throw new DeviceRegistryError("invalid-argument", "invalid-action");
  validateId(input.installationId);
  if (typeof input.platform !== "string" || !PLATFORMS.has(input.platform)) {
    throw new DeviceRegistryError("invalid-argument", "invalid-platform");
  }

  const ref = db.doc(`users/${uid}/devices/${input.installationId}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const existing = snapshot.data();
    const lastSeenAt = existing?.lastSeenAt;
    const shouldRefresh = !lastSeenAt ||
      !(lastSeenAt instanceof Timestamp) ||
      now.getTime() - lastSeenAt.toMillis() >= DAY_MS;
    if (snapshot.exists && !shouldRefresh) return;
    const expiresAt = Timestamp.fromMillis(now.getTime() + RETENTION_DAYS * DAY_MS);
    transaction.set(ref, {
      installationId: input.installationId,
      platform: input.platform,
      createdAt: existing?.createdAt ?? FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
      expiresAt,
    }, {merge: true});
  });
  return {status: "registered", installationId: input.installationId};
}

function validateId(value: unknown): asserts value is string {
  if (typeof value !== "string" || !INSTALLATION_ID.test(value)) {
    throw new DeviceRegistryError("invalid-argument", "invalid-installation-id");
  }
}

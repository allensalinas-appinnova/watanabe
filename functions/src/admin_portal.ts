import {getAuth, type UserRecord} from "firebase-admin/auth";
import {FieldValue, Firestore, Timestamp, getFirestore} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {defineString} from "firebase-functions/params";

const ownerEmailParam = defineString("ADMIN_OWNER_EMAIL", {default: ""});
const excludedUidsParam = defineString("ADMIN_EXCLUDED_TEST_UIDS_JSON", {default: "[]"});
const authReaderServiceAccountParam = defineString("ADMIN_AUTH_READER_SERVICE_ACCOUNT", {default: ""});
const PAGE_SIZE = 50;
const MAX_CURSOR_LENGTH = 2048;

type Operator = {uid: string; email: string; role: "owner" | "support" | "analyst"; status: "active"};
type AuthContext = CallableRequest<unknown>["auth"];

export class AdminPortalError extends Error {
  constructor(readonly code: "unauthenticated" | "permission-denied" | "invalid-argument" | "not-found", readonly issue: string) {
    super(issue);
  }
}

function normalizedEmail(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function excludedUids(): Set<string> {
  try {
    const values: unknown = JSON.parse(excludedUidsParam.value());
    if (Array.isArray(values) && values.every((value) => typeof value === "string" && value.length <= 128)) {
      return new Set(values as string[]);
    }
  } catch { /* Invalid exclusion configuration is ignored, not used to block the dashboard. */ }
  return new Set();
}

function verifiedGoogleOperator(auth: AuthContext): {uid: string; email: string} {
  if (!auth) throw new AdminPortalError("unauthenticated", "authentication-required");
  const claims = auth.token as Record<string, unknown>;
  const firebase = claims.firebase as Record<string, unknown> | undefined;
  const email = normalizedEmail(claims.email);
  if (firebase?.sign_in_provider !== "google.com" || claims.email_verified !== true || !email) {
    throw new AdminPortalError("permission-denied", "verified-google-account-required");
  }
  return {uid: auth.uid, email};
}

export async function bootstrapAdminOperator(db: Firestore, auth: AuthContext, ownerEmail: string): Promise<{role: string}> {
  const identity = verifiedGoogleOperator(auth);
  const ref = db.doc(`adminOperators/${identity.uid}`);
  const current = await ref.get();
  if (current.exists) {
    const data = current.data();
    if (data?.email !== identity.email || data?.status !== "active" ||
        !["owner", "support", "analyst"].includes(data.role)) {
      throw new AdminPortalError("permission-denied", "operator-disabled");
    }
    return {role: data.role as string};
  }
  if (!ownerEmail || identity.email !== normalizedEmail(ownerEmail)) {
    throw new AdminPortalError("permission-denied", "not-an-authorized-operator");
  }
  const result = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    if (existing.exists) {
      const data = existing.data();
      if (data?.email !== identity.email || data?.status !== "active") {
        throw new AdminPortalError("permission-denied", "operator-disabled");
      }
      return data.role as string;
    }
    transaction.create(ref, {uid: identity.uid, email: identity.email, role: "owner", status: "active", createdAt: FieldValue.serverTimestamp()});
    return "owner";
  });
  return {role: result};
}

export async function requireAdminOperator(db: Firestore, auth: AuthContext): Promise<Operator> {
  const identity = verifiedGoogleOperator(auth);
  const snapshot = await db.doc(`adminOperators/${identity.uid}`).get();
  const operator = snapshot.data();
  if (!operator || operator.status !== "active" || operator.email !== identity.email ||
      !["owner", "support", "analyst"].includes(operator.role)) {
    throw new AdminPortalError("permission-denied", "admin-access-required");
  }
  return {uid: identity.uid, email: identity.email, role: operator.role as Operator["role"], status: "active"};
}

async function writeAudit(db: Firestore, operator: Operator, action: string, targetUid?: string): Promise<void> {
  await db.collection("adminAudit").add({
    actorUid: operator.uid,
    actorRole: operator.role,
    action,
    ...(targetUid ? {targetUid} : {}),
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 180 * 24 * 60 * 60 * 1000),
  });
}

function authUserSummary(user: UserRecord) {
  return {
    uid: user.uid,
    email: user.email ?? null,
    emailVerified: user.emailVerified,
    disabled: user.disabled,
    providers: user.providerData.map((provider) => provider.providerId),
    createdAt: user.metadata.creationTime ?? null,
    lastSignInAt: user.metadata.lastSignInTime ?? null,
  };
}

export async function listAdminUsers(db: Firestore, auth: AuthContext, pageToken?: unknown) {
  const operator = await requireAdminOperator(db, auth);
  if (pageToken !== undefined && (typeof pageToken !== "string" || pageToken.length > MAX_CURSOR_LENGTH)) {
    throw new AdminPortalError("invalid-argument", "invalid-page-token");
  }
  const page = await getAuth().listUsers(PAGE_SIZE, pageToken as string | undefined);
  const users = await Promise.all(page.users.map(async (user) => {
    const profile = await db.doc(`users/${user.uid}`).get();
    const data = profile.data();
    return {
      ...authUserSummary(user),
      hasProfile: profile.exists,
      onboardingStatus: data?.onboardingStatus ?? null,
      resetStatus: data?.resetStatus ?? null,
    };
  }));
  await writeAudit(db, operator, "users.list");
  return {users, nextPageToken: page.pageToken ?? null};
}

export async function lookupAdminUser(db: Firestore, auth: AuthContext, query: unknown) {
  const operator = await requireAdminOperator(db, auth);
  if (typeof query !== "string" || query.trim().length < 3 || query.trim().length > 320) {
    throw new AdminPortalError("invalid-argument", "query-must-be-exact-email-or-uid");
  }
  const normalized = query.trim();
  let user: UserRecord;
  try {
    user = normalized.includes("@") ? await getAuth().getUserByEmail(normalized) : await getAuth().getUser(normalized);
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") throw new AdminPortalError("not-found", "user-not-found");
    throw error;
  }
  const [profile, devicesSnapshot] = await Promise.all([
    db.doc(`users/${user.uid}`).get(),
    db.collection(`users/${user.uid}/devices`).orderBy("lastSeenAt", "desc").limit(100).get(),
  ]);
  const profileData = profile.data();
  const devices = devicesSnapshot.docs.map((doc) => {
    const data = doc.data();
    const lastSeenAt = data.lastSeenAt instanceof Timestamp ? data.lastSeenAt.toDate().toISOString() : null;
    const active = data.expiresAt instanceof Timestamp && data.expiresAt.toMillis() > Date.now();
    return {
      id: doc.id,
      platform: typeof data.platform === "string" ? data.platform : "unknown",
      appVersion: typeof data.appVersion === "string" ? data.appVersion : null,
      buildNumber: typeof data.buildNumber === "string" ? data.buildNumber : null,
      createdAt: data.createdAt instanceof Timestamp ? data.createdAt.toDate().toISOString() : null,
      lastSeenAt,
      active,
    };
  });
  await writeAudit(db, operator, "user.lookup", user.uid);
  return {
    user: authUserSummary(user),
    profile: {
      exists: profile.exists,
      onboardingStatus: profileData?.onboardingStatus ?? null,
      resetStatus: profileData?.resetStatus ?? null,
      dataGeneration: typeof profileData?.dataGeneration === "number" ? profileData.dataGeneration : 0,
    },
    devices,
    activeDeviceCount: devices.filter((device) => device.active).length,
  };
}

export async function getAdminOverview(db: Firestore, auth: AuthContext) {
  const operator = await requireAdminOperator(db, auth);
  const snapshot = await db.collection("adminDailyMetrics").doc("latest").get();
  await writeAudit(db, operator, "overview.read");
  if (!snapshot.exists) return {available: false, metrics: null};
  const data = snapshot.data()!;
  return {
    available: true,
    generatedAt: data.generatedAt instanceof Timestamp ? data.generatedAt.toDate().toISOString() : null,
    metrics: data.metrics,
  };
}

export async function listAdminAudit(db: Firestore, auth: AuthContext, pageToken?: unknown) {
  const operator = await requireAdminOperator(db, auth);
  if (pageToken !== undefined && (typeof pageToken !== "string" || pageToken.length > MAX_CURSOR_LENGTH)) {
    throw new AdminPortalError("invalid-argument", "invalid-page-token");
  }
  let query = db.collection("adminAudit").orderBy("createdAt", "desc").limit(50);
  if (pageToken) {
    const cursor = await db.doc(`adminAudit/${pageToken}`).get();
    if (!cursor.exists) throw new AdminPortalError("invalid-argument", "invalid-audit-cursor");
    query = query.startAfter(cursor);
  }
  const result = await query.get();
  await writeAudit(db, operator, "audit.list");
  return {
    events: result.docs.map((doc) => {
      const data = doc.data();
      return {id: doc.id, actorUid: data.actorUid, actorRole: data.actorRole, action: data.action,
        targetUid: data.targetUid ?? null,
        createdAt: data.createdAt instanceof Timestamp ? data.createdAt.toDate().toISOString() : null};
    }),
    nextPageToken: result.docs.length === 50 ? result.docs[result.docs.length - 1].id : null,
  };
}

async function collectAuthUsers() {
  const result: UserRecord[] = [];
  let pageToken: string | undefined;
  do {
    const page = await getAuth().listUsers(1000, pageToken);
    result.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return result;
}

export async function refreshAdminMetrics(db: Firestore, now = new Date()) {
  const exclusions = excludedUids();
  const operators = await db.collection("adminOperators").get();
  for (const operator of operators.docs) exclusions.add(operator.id);
  const authUsers = (await collectAuthUsers()).filter((user) =>
    !exclusions.has(user.uid) && user.providerData.length > 0);
  const registeredUids = new Set(authUsers.map((user) => user.uid));
  const profiles = await db.collection("users").get();
  let profileCount = 0;
  let onboardingCompleteCount = 0;
  for (const profile of profiles.docs) {
    if (exclusions.has(profile.id) || !registeredUids.has(profile.id)) continue;
    const data = profile.data();
    if (data.resetStatus === "resetting") continue;
    profileCount++;
    if (data.onboardingStatus === "complete") onboardingCompleteCount++;
  }
  const activeDevices = await db.collectionGroup("devices")
    .where("expiresAt", ">", Timestamp.fromDate(now)).get();
  const platforms: Record<string, number> = {};
  const versions: Record<string, number> = {};
  let activeDeviceCount = 0;
  for (const device of activeDevices.docs) {
    const uid = device.ref.parent.parent?.id;
    if (!uid || exclusions.has(uid)) continue;
    activeDeviceCount++;
    const data = device.data();
    const platform = typeof data.platform === "string" ? data.platform : "unknown";
    const version = typeof data.appVersion === "string" ? data.appVersion : "unknown";
    const build = typeof data.buildNumber === "string" ? data.buildNumber : "unknown";
    platforms[platform] = (platforms[platform] ?? 0) + 1;
    const versionAndBuild = `${version}|${build}`;
    versions[versionAndBuild] = (versions[versionAndBuild] ?? 0) + 1;
  }
  const metrics = {
    authUserCount: authUsers.length,
    profileCount,
    onboardingCompleteCount,
    activeDeviceCount,
    devicesByPlatform: platforms,
    devicesByAppVersion: versions,
  };
  const generatedAt = Timestamp.fromDate(now);
  const batch = db.batch();
  const expiresAt = Timestamp.fromMillis(now.getTime() + 400 * 24 * 60 * 60 * 1000);
  batch.set(db.collection("adminDailyMetrics").doc("latest"), {generatedAt, expiresAt, metrics});
  batch.set(db.collection("adminDailyMetrics").doc(now.toISOString().slice(0, 10)), {generatedAt, expiresAt, metrics});
  await batch.commit();
  return metrics;
}

function onCallableError(error: unknown): never {
  if (error instanceof AdminPortalError) throw new HttpsError(error.code, error.issue);
  throw new HttpsError("internal", "admin-portal-request-failed");
}

export const bootstrapAdmin = onCall({region: "us-central1"}, async (request) => {
  try { return await bootstrapAdminOperator(getFirestore(), request.auth, ownerEmailParam.value()); }
  catch (error) { return onCallableError(error); }
});

export const adminListUsers = onCall({region: "us-central1", maxInstances: 3, serviceAccount: authReaderServiceAccountParam}, async (request) => {
  try { return await listAdminUsers(getFirestore(), request.auth, request.data?.pageToken); }
  catch (error) { return onCallableError(error); }
});

export const adminLookupUser = onCall({region: "us-central1", maxInstances: 3, serviceAccount: authReaderServiceAccountParam}, async (request) => {
  try { return await lookupAdminUser(getFirestore(), request.auth, request.data?.query); }
  catch (error) { return onCallableError(error); }
});

export const adminOverview = onCall({region: "us-central1", maxInstances: 3}, async (request) => {
  try { return await getAdminOverview(getFirestore(), request.auth); }
  catch (error) { return onCallableError(error); }
});

export const adminListAudit = onCall({region: "us-central1", maxInstances: 3}, async (request) => {
  try { return await listAdminAudit(getFirestore(), request.auth, request.data?.pageToken); }
  catch (error) { return onCallableError(error); }
});

export const refreshAdminDailyMetrics = onSchedule({
  schedule: "0 3 * * *",
  timeZone: "America/Bogota",
  region: "us-central1",
  timeoutSeconds: 540,
  memory: "1GiB",
  maxInstances: 1,
}, async () => {
  await refreshAdminMetrics(getFirestore());
});

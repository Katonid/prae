import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger, setGlobalOptions } from "firebase-functions/v2";

import {
  ALARM_TYPES,
  CODE_ALPHABET,
  CODE_LENGTH,
  CODE_VALID_DAYS,
  DEFAULT_INSTRUCTIONS,
  REGION,
  RETENTION_DAYS,
  type AlarmType,
} from "./model";
import { sendData, tokensOf } from "./messaging";

initializeApp();

// Frankfurt for everything: the data belongs to a German school, and a function in
// us-central1 talking to a European Firestore pays the round trip on every alarm.
setGlobalOptions({ region: REGION, maxInstances: 10 });

const db = getFirestore();

/* ---------- helpers ---------- */

function requireUid(auth: { uid: string } | undefined): string {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Nicht angemeldet.");
  return auth.uid;
}

function requireString(value: unknown, field: string, maxLength = 200): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} fehlt.`);
  }
  const trimmed = value.trim();
  if (trimmed.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} ist zu lang.`);
  }
  return trimmed;
}

async function requireMember(groupId: string, uid: string): Promise<void> {
  const member = await db.doc(`groups/${groupId}/members/${uid}`).get();
  if (!member.exists) throw new HttpsError("permission-denied", "Kein Mitglied dieser Gruppe.");
}

async function requireAdmin(groupId: string, uid: string): Promise<FirebaseFirestore.DocumentSnapshot> {
  const group = await db.doc(`groups/${groupId}`).get();
  if (!group.exists) throw new HttpsError("not-found", "Gruppe nicht gefunden.");
  const adminIds: string[] = group.get("adminIds") ?? [];
  if (!adminIds.includes(uid)) throw new HttpsError("permission-denied", "Nur für die Verwaltung.");
  return group;
}

function newCode(): string {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i += 1) {
    out += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  }
  return out;
}

function millisOf(value: unknown): number {
  if (value instanceof Timestamp) return value.toMillis();
  if (typeof value === "number") return value;
  return 0;
}

/* ---------- group lifecycle ---------- */

/**
 * Creates a group and makes the caller its admin.
 *
 * Anyone may create a group. That is deliberate: groups are reachable only through an
 * invite code, so a stranger's group touches nobody, and the alternative - the first
 * admin being entered by hand in the Firebase console - would leave the school unable to
 * start without a developer.
 */
export const createGroup = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const name = requireString(request.data?.name, "Name der Gruppe", 100);
  const displayName = requireString(request.data?.displayName, "Anzeigename", 60);

  const now = Date.now();
  const code = {
    code: newCode(),
    createdAt: now,
    expiresAt: now + CODE_VALID_DAYS * 24 * 60 * 60 * 1000,
    revoked: false,
  };

  const groupRef = db.collection("groups").doc();
  await groupRef.set({
    name,
    locations: [],
    instructions: DEFAULT_INSTRUCTIONS,
    adminIds: [uid],
    inviteCodes: [code],
    // Mirrored as plain strings because array-contains cannot match a map, and joinGroup
    // has to find a group by its code without knowing the group id.
    inviteCodeValues: [code.code],
    createdAt: FieldValue.serverTimestamp(),
  });

  await groupRef.collection("members").doc(uid).set({
    displayName,
    role: "admin",
    fcmToken: "",
    platform: "",
    deviceModel: "",
    appVersion: "",
    appVersionCode: 0,
    permissionState: {},
    lastSeen: FieldValue.serverTimestamp(),
  });

  logger.info("group created", { groupId: groupRef.id });
  return { groupId: groupRef.id, groupName: name, role: "admin", inviteCode: code.code };
});

/** Checks an invite code and creates the member document. */
export const joinGroup = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const code = requireString(request.data?.code, "Einladungscode", 12).toUpperCase();
  const displayName = requireString(request.data?.displayName, "Anzeigename", 60);

  const found = await db.collection("groups").where("inviteCodeValues", "array-contains", code).limit(1).get();
  if (found.empty) throw new HttpsError("not-found", "Code unbekannt oder abgelaufen.");

  const group = found.docs[0];
  const entries: { code: string; expiresAt: number; revoked: boolean }[] = group.get("inviteCodes") ?? [];
  const entry = entries.find((item) => item.code === code);
  if (!entry || entry.revoked || entry.expiresAt <= Date.now()) {
    throw new HttpsError("not-found", "Code unbekannt oder abgelaufen.");
  }

  const memberRef = group.ref.collection("members").doc(uid);
  const existing = await memberRef.get();
  await memberRef.set(
    {
      displayName,
      // Re-joining must never quietly demote an admin who reinstalled the app.
      role: existing.exists ? existing.get("role") ?? "member" : "member",
      lastSeen: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    groupId: group.id,
    groupName: group.get("name") ?? "",
    role: existing.exists ? existing.get("role") ?? "member" : "member",
  };
});

/* ---------- the alarm path ---------- */

export const triggerAlarm = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const groupId = requireString(request.data?.groupId, "Gruppe", 64);
  const type = requireString(request.data?.type, "Alarmart", 20) as AlarmType;
  const location = typeof request.data?.location === "string" ? request.data.location.trim().slice(0, 120) : "";

  if (!ALARM_TYPES.includes(type)) throw new HttpsError("invalid-argument", "Unbekannte Alarmart.");
  await requireMember(groupId, uid);

  const groupRef = db.doc(`groups/${groupId}`);
  const group = await groupRef.get();
  if (!group.exists) throw new HttpsError("not-found", "Gruppe nicht gefunden.");

  // A drill is something the school runs, not something one person sets off in a corridor.
  const adminIds: string[] = group.get("adminIds") ?? [];
  if (type === "test" && !adminIds.includes(uid)) {
    throw new HttpsError("permission-denied", "Probealarme darf nur die Verwaltung auslösen.");
  }

  // One alarm per type. A second amok alarm two seconds after the first tells nobody
  // anything new and makes every phone in the building start over.
  const running = await groupRef
    .collection("alarms")
    .where("status", "==", "active")
    .where("type", "==", type)
    .limit(1)
    .get();
  if (!running.empty) {
    throw new HttpsError("already-exists", "Ein Alarm dieser Art läuft bereits.");
  }

  const member = await db.doc(`groups/${groupId}/members/${uid}`).get();
  const triggeredByName: string = member.get("displayName") ?? "";
  const instructions: Record<string, string> = group.get("instructions") ?? {};
  const instruction = instructions[type] ?? DEFAULT_INSTRUCTIONS[type];

  const createdAt = Date.now();
  const alarmRef = groupRef.collection("alarms").doc();
  await alarmRef.set({
    type,
    triggeredBy: uid,
    triggeredByName,
    location,
    createdAt: FieldValue.serverTimestamp(),
    status: "active",
    instruction,
  });

  const tokens = await tokensOf(groupId);
  await sendData(groupId, tokens, {
    kind: "alarm",
    groupId,
    alarmId: alarmRef.id,
    type,
    triggeredByName,
    location,
    createdAt: String(createdAt),
    instruction,
  });

  logger.info("alarm triggered", { groupId, alarmId: alarmRef.id, type, devices: tokens.length });
  return { alarmId: alarmRef.id, devices: tokens.length };
});

export const clearAlarm = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const groupId = requireString(request.data?.groupId, "Gruppe", 64);
  const alarmId = requireString(request.data?.alarmId, "Alarm", 64);
  await requireMember(groupId, uid);

  const alarmRef = db.doc(`groups/${groupId}/alarms/${alarmId}`);
  const alarm = await alarmRef.get();
  if (!alarm.exists) throw new HttpsError("not-found", "Alarm nicht gefunden.");
  if (alarm.get("status") === "cleared") return { alarmId, alreadyCleared: true };

  const group = await db.doc(`groups/${groupId}`).get();
  const adminIds: string[] = group.get("adminIds") ?? [];
  // The person who raised the alarm may also stand it down - they are the one who knows
  // it was a mistake, and waiting for an admin costs the whole building minutes.
  if (!adminIds.includes(uid) && alarm.get("triggeredBy") !== uid) {
    throw new HttpsError("permission-denied", "Nur die Verwaltung oder die auslösende Person.");
  }

  const member = await db.doc(`groups/${groupId}/members/${uid}`).get();
  const clearedByName: string = member.get("displayName") ?? "";
  const clearedAt = Date.now();

  await alarmRef.update({
    status: "cleared",
    clearedAt: FieldValue.serverTimestamp(),
    clearedBy: uid,
    clearedByName,
  });

  const tokens = await tokensOf(groupId);
  await sendData(groupId, tokens, {
    kind: "all_clear",
    groupId,
    alarmId,
    type: alarm.get("type") ?? "amok",
    triggeredByName: alarm.get("triggeredByName") ?? "",
    location: alarm.get("location") ?? "",
    createdAt: String(millisOf(alarm.get("createdAt"))),
    instruction: "",
    clearedByName,
    clearedAt: String(clearedAt),
  });

  logger.info("alarm cleared", { groupId, alarmId, devices: tokens.length });
  return { alarmId, devices: tokens.length };
});

/* ---------- keeping the device list honest ---------- */

/**
 * Silent data message. The device answers by writing its own member document, which is
 * the only way to learn whether a phone would still receive an alarm at all.
 */
export const ping = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const groupId = requireString(request.data?.groupId, "Gruppe", 64);
  await requireAdmin(groupId, uid);

  const target = typeof request.data?.uid === "string" ? request.data.uid : undefined;
  const tokens = await tokensOf(groupId, target);
  await sendData(groupId, tokens, { kind: "ping", groupId, alarmId: "", type: "test" }, 600);
  return { devices: tokens.length };
});

/**
 * A test alarm to the caller's own device only. This is the last step of onboarding: it
 * travels the exact path a real alarm takes, so a phone that stays silent here would have
 * stayed silent in an emergency too.
 */
export const selfTest = onCall(async (request) => {
  const uid = requireUid(request.auth);
  const groupId = requireString(request.data?.groupId, "Gruppe", 64);
  await requireMember(groupId, uid);

  const member = await db.doc(`groups/${groupId}/members/${uid}`).get();
  const displayName: string = member.get("displayName") ?? "";
  const tokens = await tokensOf(groupId, uid);
  if (tokens.length === 0) {
    throw new HttpsError("failed-precondition", "Dieses Gerät hat noch kein Zustellzeichen hinterlegt.");
  }

  await sendData(groupId, tokens, {
    kind: "alarm",
    groupId,
    alarmId: `selftest-${Date.now()}`,
    type: "test",
    triggeredByName: displayName,
    location: "",
    createdAt: String(Date.now()),
    instruction: DEFAULT_INSTRUCTIONS.test,
    selfTest: "true",
  });

  return { devices: tokens.length };
});

/* ---------- scheduled work ---------- */

/** Nightly ping so the admin device list is worth looking at in the morning. */
export const nightlyPing = onSchedule(
  { schedule: "0 3 * * *", timeZone: "Europe/Berlin", region: REGION },
  async () => {
    const groups = await db.collection("groups").get();
    for (const group of groups.docs) {
      const tokens = await tokensOf(group.id);
      if (tokens.length === 0) continue;
      await sendData(group.id, tokens, { kind: "ping", groupId: group.id, alarmId: "", type: "test" }, 3600);
    }
    logger.info("nightly ping sent", { groups: groups.size });
  },
);

/**
 * Deletes alarms, answers and chat messages 90 days after the all clear. These are
 * performance-adjacent records about named colleagues; keeping them forever would be
 * neither necessary nor defensible.
 */
export const cleanupOldAlarms = onSchedule(
  { schedule: "30 3 * * *", timeZone: "Europe/Berlin", region: REGION },
  async () => {
    const cutoff = Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000;
    const groups = await db.collection("groups").get();
    let removed = 0;

    for (const group of groups.docs) {
      const alarms = await group.ref.collection("alarms").where("status", "==", "cleared").get();
      for (const alarm of alarms.docs) {
        if (millisOf(alarm.get("clearedAt")) > cutoff) continue;
        // recursiveDelete takes the acks and messages subcollections with it.
        await db.recursiveDelete(alarm.ref);
        removed += 1;
      }
    }
    logger.info("old alarms removed", { removed, retentionDays: RETENTION_DAYS });
  },
);

import { getMessaging, type TokenMessage } from "firebase-admin/messaging";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";

/**
 * Sends a pure data message.
 *
 * There is no `notification` block anywhere in this file, and that is the single most
 * important line of the backend: with a notification block Android draws the message
 * itself and never wakes the app, so no alarm tone, no wake lock and no full screen
 * would ever happen. High priority is what puts the app on the temporary power allowlist
 * so it may start its foreground service from the background.
 *
 * The time to live is short on purpose. An alarm that reaches a phone half an hour late
 * is not information, it is confusion - and the client drops anything older than three
 * minutes anyway.
 */
export async function sendData(
  groupId: string,
  tokens: string[],
  data: Record<string, string>,
  ttlSeconds = 120,
): Promise<void> {
  if (tokens.length === 0) return;

  const messaging = getMessaging();
  const invalid: string[] = [];

  // sendEach takes at most 500 messages per call.
  for (let start = 0; start < tokens.length; start += 500) {
    const chunk = tokens.slice(start, start + 500);
    const messages: TokenMessage[] = chunk.map((token) => ({
      token,
      data,
      android: {
        priority: "high",
        ttl: ttlSeconds * 1000,
      },
    }));

    const response = await messaging.sendEach(messages);
    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error?.code ?? "";
      logger.warn("delivery failed", { token: chunk[index].slice(0, 12), code });
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token" ||
        code === "messaging/invalid-argument"
      ) {
        invalid.push(chunk[index]);
      }
    });
  }

  if (invalid.length > 0) await dropInvalidTokens(groupId, invalid);
}

/**
 * A token that the service rejected belongs to an app that was uninstalled or whose data
 * was cleared. Left in place it would be retried on every single alarm forever.
 */
async function dropInvalidTokens(groupId: string, tokens: string[]): Promise<void> {
  const db = getFirestore();
  const members = await db.collection(`groups/${groupId}/members`).get();
  const batch = db.batch();
  let count = 0;
  for (const doc of members.docs) {
    const token = doc.get("fcmToken");
    if (typeof token === "string" && tokens.includes(token)) {
      batch.update(doc.ref, { fcmToken: "", fcmTokenDroppedAt: Date.now() });
      count += 1;
    }
  }
  if (count > 0) {
    await batch.commit();
    logger.info("dropped invalid tokens", { groupId, count });
  }
}

/** Collects the delivery tokens of a group, optionally of a single member. */
export async function tokensOf(groupId: string, uid?: string): Promise<string[]> {
  const db = getFirestore();
  if (uid) {
    const doc = await db.doc(`groups/${groupId}/members/${uid}`).get();
    const token = doc.get("fcmToken");
    return typeof token === "string" && token.length > 0 ? [token] : [];
  }
  const members = await db.collection(`groups/${groupId}/members`).get();
  return members.docs
    .map((doc) => doc.get("fcmToken"))
    .filter((token): token is string => typeof token === "string" && token.length > 0);
}

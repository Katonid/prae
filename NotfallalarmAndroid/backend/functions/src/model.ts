/**
 * The contract shared with the Android client (and with a future iOS client).
 * Wire values are spelled out; renaming one here breaks every phone in the school.
 */

export const REGION = "europe-west3";

export type AlarmType = "amok" | "fire" | "medical" | "test";
export const ALARM_TYPES: AlarmType[] = ["amok", "fire", "medical", "test"];

export type AlarmStatus = "active" | "cleared";
export type MemberRole = "admin" | "member";

/** Data message kinds. There is never a `notification` block - see sendData(). */
export type MessageKind = "alarm" | "all_clear" | "ping";

export interface InviteCode {
  code: string;
  createdAt: number;
  expiresAt: number;
  revoked: boolean;
}

/**
 * Codes leave out I, O, 0 and 1: those are the pairs that get misread when someone
 * copies a code off a whiteboard, and the client deliberately does not guess.
 */
export const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export const CODE_LENGTH = 6;
export const CODE_VALID_DAYS = 7;

/** Default action texts. Placeholders - the school agrees the real ones with the police. */
export const DEFAULT_INSTRUCTIONS: Record<AlarmType, string> = {
  amok:
    "Türen schließen und verriegeln. Fenster schließen, Jalousien herunter. " +
    "Mit der Klasse außer Sicht gehen. Ruhe bewahren, Handys stumm. " +
    "Warten, bis die Polizei die Tür öffnet.",
  fire:
    "Fenster schließen, Klassenbuch mitnehmen, geordnet über den bekannten Fluchtweg " +
    "ins Freie. Sammelplatz aufsuchen und Vollständigkeit melden.",
  medical:
    "Ersthelfer verständigen. Wenn nötig 112 wählen. Eine Person zur Einweisung an den " +
    "Eingang schicken.",
  test: "Dies ist ein Probealarm. Bitte nur die Rückmeldung geben, sonst nichts unternehmen.",
};

/** A phone that has not reported for this long is shown in red in the admin view. */
export const STALE_DEVICE_MILLIS = 48 * 60 * 60 * 1000;

/** Alarms and their messages are deleted this long after the all clear. */
export const RETENTION_DAYS = 90;

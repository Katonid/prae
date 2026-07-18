"""SQLite-Datenbankschicht für den Mailsortierer.

Alle Konfigurationsdaten (Konten, Regeln, Einstellungen) und Protokolle
liegen in einer einzigen SQLite-Datei im DATA_DIR-Volume, damit sie einen
Container-Neustart überleben.
"""

import os
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime, timezone

DATA_DIR = os.environ.get("DATA_DIR", "/data")
DB_PATH = os.path.join(DATA_DIR, "mailsortierer.db")

_lock = threading.Lock()

SCHEMA = """
CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    imap_host TEXT NOT NULL,
    imap_port INTEGER NOT NULL DEFAULT 993,
    imap_security TEXT NOT NULL DEFAULT 'ssl',      -- 'ssl' | 'starttls' | 'none'
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    smtp_host TEXT DEFAULT '',
    smtp_port INTEGER DEFAULT 587,
    smtp_security TEXT DEFAULT 'starttls',          -- 'ssl' | 'starttls' | 'none'
    smtp_username TEXT DEFAULT '',
    smtp_password TEXT DEFAULT '',
    from_address TEXT DEFAULT '',
    active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    sender_pattern TEXT NOT NULL,
    target_folder TEXT NOT NULL,
    auto_reply INTEGER NOT NULL DEFAULT 0,
    reply_subject TEXT DEFAULT 'Abwesenheitsnotiz',
    reply_body TEXT DEFAULT '',
    active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS reply_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    rule_id INTEGER NOT NULL,
    sender TEXT NOT NULL,
    replied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS activity_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    level TEXT NOT NULL,
    message TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
"""

DEFAULT_SETTINGS = {
    "poll_interval_seconds": "300",
    "reply_cooldown_hours": "168",
}


def utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


@contextmanager
def get_db():
    with _lock:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        try:
            yield conn
            conn.commit()
        finally:
            conn.close()


def init_db():
    os.makedirs(DATA_DIR, exist_ok=True)
    with get_db() as db:
        db.executescript(SCHEMA)
        for key, value in DEFAULT_SETTINGS.items():
            db.execute(
                "INSERT OR IGNORE INTO settings (key, value) VALUES (?, ?)",
                (key, value),
            )


def get_setting(key: str) -> str:
    with get_db() as db:
        row = db.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
    return row["value"] if row else DEFAULT_SETTINGS.get(key, "")


def set_setting(key: str, value: str):
    with get_db() as db:
        db.execute(
            "INSERT INTO settings (key, value) VALUES (?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, str(value)),
        )


def log_activity(level: str, message: str):
    with get_db() as db:
        db.execute(
            "INSERT INTO activity_log (created_at, level, message) VALUES (?, ?, ?)",
            (utcnow(), level, message),
        )
        # Protokoll begrenzen, damit die Datenbank nicht unbegrenzt wächst.
        db.execute(
            "DELETE FROM activity_log WHERE id NOT IN "
            "(SELECT id FROM activity_log ORDER BY id DESC LIMIT 2000)"
        )


def get_logs(limit: int = 200):
    with get_db() as db:
        rows = db.execute(
            "SELECT * FROM activity_log ORDER BY id DESC LIMIT ?", (limit,)
        ).fetchall()
    return [dict(r) for r in rows]


def list_accounts(include_password: bool = False):
    with get_db() as db:
        rows = db.execute("SELECT * FROM accounts ORDER BY id").fetchall()
    accounts = [dict(r) for r in rows]
    if not include_password:
        for a in accounts:
            a["password"] = ""
            a["smtp_password"] = ""
    return accounts


def get_account(account_id: int, include_password: bool = False):
    with get_db() as db:
        row = db.execute("SELECT * FROM accounts WHERE id = ?", (account_id,)).fetchone()
    if not row:
        return None
    account = dict(row)
    if not include_password:
        account["password"] = ""
        account["smtp_password"] = ""
    return account


def create_account(data: dict) -> int:
    with get_db() as db:
        cur = db.execute(
            """INSERT INTO accounts
               (name, imap_host, imap_port, imap_security, username, password,
                smtp_host, smtp_port, smtp_security, smtp_username, smtp_password,
                from_address, active)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                data["name"], data["imap_host"], data["imap_port"],
                data["imap_security"], data["username"], data["password"],
                data["smtp_host"], data["smtp_port"], data["smtp_security"],
                data["smtp_username"], data["smtp_password"],
                data["from_address"], 1 if data["active"] else 0,
            ),
        )
        return cur.lastrowid


def update_account(account_id: int, data: dict):
    existing = get_account(account_id, include_password=True)
    if not existing:
        return False
    # Leere Passwortfelder bedeuten: bestehendes Passwort behalten.
    password = data["password"] or existing["password"]
    smtp_password = data["smtp_password"] or existing["smtp_password"]
    with get_db() as db:
        db.execute(
            """UPDATE accounts SET
               name = ?, imap_host = ?, imap_port = ?, imap_security = ?,
               username = ?, password = ?, smtp_host = ?, smtp_port = ?,
               smtp_security = ?, smtp_username = ?, smtp_password = ?,
               from_address = ?, active = ?
               WHERE id = ?""",
            (
                data["name"], data["imap_host"], data["imap_port"],
                data["imap_security"], data["username"], password,
                data["smtp_host"], data["smtp_port"], data["smtp_security"],
                data["smtp_username"], smtp_password,
                data["from_address"], 1 if data["active"] else 0,
                account_id,
            ),
        )
    return True


def delete_account(account_id: int):
    with get_db() as db:
        db.execute("DELETE FROM accounts WHERE id = ?", (account_id,))


def list_rules(account_id: int | None = None):
    query = (
        "SELECT rules.*, accounts.name AS account_name FROM rules "
        "JOIN accounts ON accounts.id = rules.account_id"
    )
    params: tuple = ()
    if account_id is not None:
        query += " WHERE rules.account_id = ?"
        params = (account_id,)
    query += " ORDER BY rules.id"
    with get_db() as db:
        rows = db.execute(query, params).fetchall()
    return [dict(r) for r in rows]


def get_rule(rule_id: int):
    with get_db() as db:
        row = db.execute("SELECT * FROM rules WHERE id = ?", (rule_id,)).fetchone()
    return dict(row) if row else None


def create_rule(data: dict) -> int:
    with get_db() as db:
        cur = db.execute(
            """INSERT INTO rules
               (account_id, sender_pattern, target_folder, auto_reply,
                reply_subject, reply_body, active)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                data["account_id"], data["sender_pattern"], data["target_folder"],
                1 if data["auto_reply"] else 0, data["reply_subject"],
                data["reply_body"], 1 if data["active"] else 0,
            ),
        )
        return cur.lastrowid


def update_rule(rule_id: int, data: dict):
    if not get_rule(rule_id):
        return False
    with get_db() as db:
        db.execute(
            """UPDATE rules SET
               account_id = ?, sender_pattern = ?, target_folder = ?,
               auto_reply = ?, reply_subject = ?, reply_body = ?, active = ?
               WHERE id = ?""",
            (
                data["account_id"], data["sender_pattern"], data["target_folder"],
                1 if data["auto_reply"] else 0, data["reply_subject"],
                data["reply_body"], 1 if data["active"] else 0,
                rule_id,
            ),
        )
    return True


def delete_rule(rule_id: int):
    with get_db() as db:
        db.execute("DELETE FROM rules WHERE id = ?", (rule_id,))


def last_reply_time(account_id: int, rule_id: int, sender: str) -> str | None:
    with get_db() as db:
        row = db.execute(
            "SELECT replied_at FROM reply_log "
            "WHERE account_id = ? AND rule_id = ? AND sender = ? "
            "ORDER BY id DESC LIMIT 1",
            (account_id, rule_id, sender.lower()),
        ).fetchone()
    return row["replied_at"] if row else None


def record_reply(account_id: int, rule_id: int, sender: str):
    with get_db() as db:
        db.execute(
            "INSERT INTO reply_log (account_id, rule_id, sender, replied_at) "
            "VALUES (?, ?, ?, ?)",
            (account_id, rule_id, sender.lower(), utcnow()),
        )

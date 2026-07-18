"""Hintergrund-Worker: ruft die Postfächer zyklisch ab und wendet die Regeln an.

Ablauf pro Konto:
  1. IMAP-Verbindung zum Posteingang aufbauen.
  2. Alle Nachrichten (nur Header) laden und gegen die aktiven Regeln prüfen.
  3. Bei Treffer: optional Abwesenheitsnotiz per SMTP senden, dann die Mail in
     den Zielordner verschieben (Ordner wird bei Bedarf angelegt).

Verschobene Mails verschwinden aus dem Posteingang und werden dadurch beim
nächsten Lauf nicht erneut verarbeitet. Für Abwesenheitsnotizen gilt
zusätzlich eine Sperrfrist pro Absender (reply_cooldown_hours), damit niemand
bei jeder Mail erneut eine Notiz erhält.
"""

import email.utils
import fnmatch
import smtplib
import ssl
import threading
import traceback
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage

from imap_tools import MailBox, MailBoxStartTls, MailBoxUnencrypted

from . import db

# Absender, die niemals eine automatische Antwort erhalten sollen.
NO_REPLY_MARKERS = ("noreply", "no-reply", "no_reply", "mailer-daemon", "postmaster", "bounce")


class MailWorker:
    def __init__(self):
        self._wakeup = threading.Event()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._running_check = threading.Lock()
        self.last_run: str | None = None
        self.last_results: dict[int, str] = {}

    # ---------- Lebenszyklus ----------

    def start(self):
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        self._wakeup.set()

    def trigger(self):
        """Sofortigen Prüflauf anstoßen (Button 'Jetzt prüfen')."""
        self._wakeup.set()

    def status(self) -> dict:
        return {
            "last_run": self.last_run,
            "checking": self._running_check.locked(),
            "results": self.last_results,
        }

    def _loop(self):
        while not self._stop.is_set():
            try:
                self.run_check()
            except Exception:
                db.log_activity("ERROR", f"Unerwarteter Fehler im Prüflauf: {traceback.format_exc(limit=3)}")
            try:
                interval = max(30, int(db.get_setting("poll_interval_seconds")))
            except ValueError:
                interval = 300
            self._wakeup.wait(timeout=interval)
            self._wakeup.clear()

    # ---------- Prüflauf ----------

    def run_check(self):
        if not self._running_check.acquire(blocking=False):
            return  # Es läuft bereits eine Prüfung.
        try:
            self.last_run = db.utcnow()
            for account in db.list_accounts(include_password=True):
                if not account["active"]:
                    self.last_results[account["id"]] = "inaktiv"
                    continue
                try:
                    moved, replied = self._process_account(account)
                    self.last_results[account["id"]] = (
                        f"OK – {moved} verschoben, {replied} Abwesenheitsnotizen"
                    )
                except Exception as exc:
                    self.last_results[account["id"]] = f"Fehler: {exc}"
                    db.log_activity(
                        "ERROR", f"Konto '{account['name']}': Abruf fehlgeschlagen: {exc}"
                    )
        finally:
            self._running_check.release()

    def _process_account(self, account: dict) -> tuple[int, int]:
        rules = [r for r in db.list_rules(account["id"]) if r["active"]]
        if not rules:
            return 0, 0

        moved = 0
        replied = 0
        with self._connect_imap(account) as mailbox:
            # Nur Header laden – Anhänge/Inhalte werden nicht benötigt.
            messages = list(
                mailbox.fetch(mark_seen=False, headers_only=True, bulk=50)
            )
            for msg in messages:
                sender = (msg.from_ or "").lower().strip()
                if not sender:
                    continue
                rule = self._match_rule(rules, sender)
                if not rule:
                    continue

                if rule["auto_reply"]:
                    if self._send_auto_reply(account, rule, msg):
                        replied += 1

                folder = rule["target_folder"]
                self._ensure_folder(mailbox, folder)
                mailbox.move([msg.uid], folder)
                moved += 1
                db.log_activity(
                    "INFO",
                    f"Konto '{account['name']}': Mail von {sender} "
                    f"(Betreff: {msg.subject or '–'}) nach '{folder}' verschoben.",
                )
        return moved, replied

    @staticmethod
    def _match_rule(rules: list[dict], sender: str) -> dict | None:
        """Erste passende Regel gewinnt. Muster: exakte Adresse oder Wildcard
        wie *@firma.de bzw. newsletter@*."""
        for rule in rules:
            pattern = rule["sender_pattern"].lower().strip()
            if not pattern:
                continue
            if "*" in pattern or "?" in pattern:
                if fnmatch.fnmatch(sender, pattern):
                    return rule
            elif sender == pattern:
                return rule
        return None

    # ---------- IMAP ----------

    @staticmethod
    def _connect_imap(account: dict):
        host = account["imap_host"]
        port = int(account["imap_port"])
        security = account["imap_security"]
        if security == "ssl":
            box = MailBox(host, port)
        elif security == "starttls":
            box = MailBoxStartTls(host, port)
        else:
            box = MailBoxUnencrypted(host, port)
        return box.login(account["username"], account["password"], initial_folder="INBOX")

    @staticmethod
    def _ensure_folder(mailbox, folder: str):
        if not mailbox.folder.exists(folder):
            mailbox.folder.create(folder)

    def test_account(self, account: dict) -> dict:
        """Verbindungstest für das Webinterface (IMAP und – falls
        konfiguriert – SMTP)."""
        result = {"imap": "", "smtp": ""}
        try:
            with self._connect_imap(account) as mailbox:
                mailbox.folder.list()
            result["imap"] = "OK"
        except Exception as exc:
            result["imap"] = f"Fehler: {exc}"

        if account["smtp_host"]:
            try:
                smtp = self._connect_smtp(account)
                smtp.quit()
                result["smtp"] = "OK"
            except Exception as exc:
                result["smtp"] = f"Fehler: {exc}"
        else:
            result["smtp"] = "nicht konfiguriert"
        return result

    # ---------- SMTP / Abwesenheitsnotiz ----------

    @staticmethod
    def _connect_smtp(account: dict) -> smtplib.SMTP:
        host = account["smtp_host"]
        port = int(account["smtp_port"] or 587)
        security = account["smtp_security"]
        context = ssl.create_default_context()
        if security == "ssl":
            smtp = smtplib.SMTP_SSL(host, port, context=context, timeout=30)
        else:
            smtp = smtplib.SMTP(host, port, timeout=30)
            if security == "starttls":
                smtp.starttls(context=context)
        user = account["smtp_username"] or account["username"]
        password = account["smtp_password"] or account["password"]
        if user and password:
            smtp.login(user, password)
        return smtp

    def _send_auto_reply(self, account: dict, rule: dict, msg) -> bool:
        sender = (msg.from_ or "").lower().strip()

        if not account["smtp_host"]:
            db.log_activity(
                "WARN",
                f"Konto '{account['name']}': Abwesenheitsnotiz an {sender} nicht "
                "möglich – kein SMTP-Server konfiguriert.",
            )
            return False

        # Keine Antworten an Automaten, Verteiler oder auf automatische Mails.
        if any(marker in sender for marker in NO_REPLY_MARKERS):
            return False
        headers = {k.lower(): v for k, v in (msg.headers or {}).items()}
        auto_submitted = " ".join(headers.get("auto-submitted", ())).lower()
        precedence = " ".join(headers.get("precedence", ())).lower()
        if (auto_submitted and "no" not in auto_submitted.split()) or \
           precedence in ("bulk", "junk", "list") or "list-id" in headers:
            return False

        # Sperrfrist: pro Absender und Regel nur eine Notiz im Zeitraum.
        try:
            cooldown = int(db.get_setting("reply_cooldown_hours"))
        except ValueError:
            cooldown = 168
        last = db.last_reply_time(account["id"], rule["id"], sender)
        if last:
            last_dt = datetime.strptime(last, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
            if datetime.now(timezone.utc) - last_dt < timedelta(hours=cooldown):
                return False

        reply = EmailMessage()
        from_address = account["from_address"] or account["username"]
        reply["From"] = from_address
        reply["To"] = msg.from_
        reply["Subject"] = rule["reply_subject"] or "Abwesenheitsnotiz"
        reply["Date"] = email.utils.formatdate(localtime=True)
        reply["Message-ID"] = email.utils.make_msgid()
        reply["Auto-Submitted"] = "auto-replied"
        reply["X-Auto-Response-Suppress"] = "All"
        original_id = " ".join(headers.get("message-id", ())).strip()
        if original_id:
            reply["In-Reply-To"] = original_id
            reply["References"] = original_id
        reply.set_content(rule["reply_body"] or "Ich bin derzeit abwesend und lese Ihre E-Mail zu einem späteren Zeitpunkt.")

        try:
            smtp = self._connect_smtp(account)
            try:
                smtp.send_message(reply)
            finally:
                smtp.quit()
        except Exception as exc:
            db.log_activity(
                "ERROR",
                f"Konto '{account['name']}': Abwesenheitsnotiz an {sender} "
                f"fehlgeschlagen: {exc}",
            )
            return False

        db.record_reply(account["id"], rule["id"], sender)
        db.log_activity(
            "INFO", f"Konto '{account['name']}': Abwesenheitsnotiz an {sender} gesendet."
        )
        return True


worker = MailWorker()

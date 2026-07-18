"""FastAPI-Anwendung: REST-API und Webinterface für den Mailsortierer."""

import os
import secrets
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.responses import FileResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import db
from .worker import worker

ADMIN_USERNAME = os.environ.get("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "")

security = HTTPBasic(auto_error=False)


def require_auth(credentials: HTTPBasicCredentials | None = Depends(security)):
    """HTTP Basic Auth, aktiv sobald ADMIN_PASSWORD gesetzt ist."""
    if not ADMIN_PASSWORD:
        return
    if (
        credentials is None
        or not secrets.compare_digest(credentials.username, ADMIN_USERNAME)
        or not secrets.compare_digest(credentials.password, ADMIN_PASSWORD)
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Anmeldung erforderlich",
            headers={"WWW-Authenticate": "Basic realm=Mailsortierer"},
        )


@asynccontextmanager
async def lifespan(_app: FastAPI):
    db.init_db()
    if not ADMIN_PASSWORD:
        db.log_activity(
            "WARN",
            "Kein ADMIN_PASSWORD gesetzt – das Webinterface ist ohne Anmeldung "
            "erreichbar. Für den Betrieb im Heimnetz die Umgebungsvariable "
            "ADMIN_PASSWORD setzen.",
        )
    worker.start()
    yield
    worker.stop()


app = FastAPI(title="Mailsortierer", lifespan=lifespan)

STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")


# ---------- Pydantic-Modelle ----------

class AccountIn(BaseModel):
    name: str = Field(min_length=1)
    imap_host: str = Field(min_length=1)
    imap_port: int = 993
    imap_security: str = "ssl"
    username: str = Field(min_length=1)
    password: str = ""
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_security: str = "starttls"
    smtp_username: str = ""
    smtp_password: str = ""
    from_address: str = ""
    active: bool = True


class RuleIn(BaseModel):
    account_id: int
    sender_pattern: str = Field(min_length=1)
    target_folder: str = Field(min_length=1)
    auto_reply: bool = False
    reply_subject: str = "Abwesenheitsnotiz"
    reply_body: str = ""
    active: bool = True


class SettingsIn(BaseModel):
    poll_interval_seconds: int = Field(ge=30, le=86400)
    reply_cooldown_hours: int = Field(ge=1, le=8760)


# ---------- Konten ----------

@app.get("/api/accounts", dependencies=[Depends(require_auth)])
def api_list_accounts():
    return db.list_accounts()


@app.post("/api/accounts", dependencies=[Depends(require_auth)])
def api_create_account(account: AccountIn):
    if not account.password:
        raise HTTPException(400, "Für ein neues Konto ist ein Passwort erforderlich.")
    account_id = db.create_account(account.model_dump())
    db.log_activity("INFO", f"Konto '{account.name}' angelegt.")
    return {"id": account_id}


@app.put("/api/accounts/{account_id}", dependencies=[Depends(require_auth)])
def api_update_account(account_id: int, account: AccountIn):
    if not db.update_account(account_id, account.model_dump()):
        raise HTTPException(404, "Konto nicht gefunden.")
    return {"ok": True}


@app.delete("/api/accounts/{account_id}", dependencies=[Depends(require_auth)])
def api_delete_account(account_id: int):
    db.delete_account(account_id)
    return {"ok": True}


@app.post("/api/accounts/{account_id}/test", dependencies=[Depends(require_auth)])
def api_test_account(account_id: int):
    account = db.get_account(account_id, include_password=True)
    if not account:
        raise HTTPException(404, "Konto nicht gefunden.")
    return worker.test_account(account)


# ---------- Regeln ----------

@app.get("/api/rules", dependencies=[Depends(require_auth)])
def api_list_rules():
    return db.list_rules()


@app.post("/api/rules", dependencies=[Depends(require_auth)])
def api_create_rule(rule: RuleIn):
    if not db.get_account(rule.account_id):
        raise HTTPException(400, "Zugehöriges Konto existiert nicht.")
    rule_id = db.create_rule(rule.model_dump())
    return {"id": rule_id}


@app.put("/api/rules/{rule_id}", dependencies=[Depends(require_auth)])
def api_update_rule(rule_id: int, rule: RuleIn):
    if not db.get_account(rule.account_id):
        raise HTTPException(400, "Zugehöriges Konto existiert nicht.")
    if not db.update_rule(rule_id, rule.model_dump()):
        raise HTTPException(404, "Regel nicht gefunden.")
    return {"ok": True}


@app.delete("/api/rules/{rule_id}", dependencies=[Depends(require_auth)])
def api_delete_rule(rule_id: int):
    db.delete_rule(rule_id)
    return {"ok": True}


# ---------- Einstellungen, Status, Protokoll ----------

@app.get("/api/settings", dependencies=[Depends(require_auth)])
def api_get_settings():
    return {
        "poll_interval_seconds": int(db.get_setting("poll_interval_seconds")),
        "reply_cooldown_hours": int(db.get_setting("reply_cooldown_hours")),
    }


@app.put("/api/settings", dependencies=[Depends(require_auth)])
def api_put_settings(settings: SettingsIn):
    db.set_setting("poll_interval_seconds", settings.poll_interval_seconds)
    db.set_setting("reply_cooldown_hours", settings.reply_cooldown_hours)
    return {"ok": True}


@app.get("/api/status", dependencies=[Depends(require_auth)])
def api_status():
    return worker.status()


@app.post("/api/run", dependencies=[Depends(require_auth)])
def api_run_now():
    worker.trigger()
    return {"ok": True}


@app.get("/api/logs", dependencies=[Depends(require_auth)])
def api_logs(limit: int = 200):
    return db.get_logs(min(max(limit, 1), 1000))


# ---------- Webinterface ----------

@app.get("/", dependencies=[Depends(require_auth)], include_in_schema=False)
def index():
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

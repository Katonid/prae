/* Mailsortierer – Webinterface */

let accounts = [];
let rules = [];

// ---------- Hilfsfunktionen ----------

async function api(path, options = {}) {
  const res = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    let detail = res.statusText;
    try { detail = (await res.json()).detail || detail; } catch (e) { /* ignorieren */ }
    throw new Error(detail);
  }
  return res.json();
}

let toastTimer = null;
function toast(message, isError = false) {
  const el = document.getElementById("toast");
  el.textContent = message;
  el.className = "show" + (isError ? " error" : "");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el.className = ""; }, 4000);
}

function esc(text) {
  const div = document.createElement("div");
  div.textContent = text ?? "";
  return div.innerHTML;
}

// ---------- Tabs ----------

document.querySelectorAll("nav .tab").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll("nav .tab").forEach((b) => b.classList.remove("active"));
    document.querySelectorAll(".tab-panel").forEach((p) => p.classList.remove("active"));
    btn.classList.add("active");
    document.getElementById("tab-" + btn.dataset.tab).classList.add("active");
    if (btn.dataset.tab === "logs") loadLogs();
  });
});

// ---------- Status ----------

async function loadStatus() {
  try {
    const status = await api("/api/status");
    const line = document.getElementById("status-line");
    if (status.checking) {
      line.textContent = "Prüfung läuft …";
    } else if (status.last_run) {
      line.textContent = "Letzter Abruf: " + status.last_run + " UTC";
    } else {
      line.textContent = "Noch kein Abruf";
    }
  } catch (e) { /* Statusanzeige ist unkritisch */ }
}

document.getElementById("btn-run").addEventListener("click", async () => {
  try {
    await api("/api/run", { method: "POST" });
    toast("Prüfung gestartet.");
    setTimeout(() => { loadStatus(); loadAccounts(); }, 3000);
  } catch (e) {
    toast("Fehler: " + e.message, true);
  }
});

// ---------- Konten ----------

const accountDialog = document.getElementById("account-dialog");
const accountForm = document.getElementById("account-form");

async function loadAccounts() {
  const [accountData, status] = await Promise.all([
    api("/api/accounts"),
    api("/api/status").catch(() => ({ results: {} })),
  ]);
  accounts = accountData;
  const list = document.getElementById("accounts-list");
  if (!accounts.length) {
    list.innerHTML = '<p class="hint">Noch keine Konten. Lege zuerst ein Mailkonto an.</p>';
    return;
  }
  list.innerHTML = accounts.map((a) => {
    const result = (status.results || {})[a.id];
    return `
    <div class="card" data-id="${a.id}">
      <div class="card-title">
        ${esc(a.name)}
        <span class="badge ${a.active ? "on" : "off"}">${a.active ? "aktiv" : "inaktiv"}</span>
      </div>
      <div class="card-sub">IMAP: ${esc(a.username)} @ ${esc(a.imap_host)}:${a.imap_port}
        ${a.smtp_host ? " &middot; SMTP: " + esc(a.smtp_host) + ":" + a.smtp_port : " &middot; kein SMTP (keine Abwesenheitsnotizen)"}
      </div>
      ${result ? `<div class="card-sub">Letzter Lauf: ${esc(result)}</div>` : ""}
      <div class="card-actions">
        <button class="secondary" data-action="edit">Bearbeiten</button>
        <button class="secondary" data-action="test">Verbindung testen</button>
        <button class="danger" data-action="delete">L&ouml;schen</button>
      </div>
      <div class="test-result"></div>
    </div>`;
  }).join("");
}

document.getElementById("accounts-list").addEventListener("click", async (event) => {
  const btn = event.target.closest("button[data-action]");
  if (!btn) return;
  const card = btn.closest(".card");
  const id = Number(card.dataset.id);
  const account = accounts.find((a) => a.id === id);

  if (btn.dataset.action === "edit") {
    openAccountDialog(account);
  } else if (btn.dataset.action === "test") {
    btn.disabled = true;
    const resultEl = card.querySelector(".test-result");
    resultEl.textContent = "Teste Verbindung …";
    try {
      const result = await api(`/api/accounts/${id}/test`, { method: "POST" });
      resultEl.textContent = `IMAP: ${result.imap} · SMTP: ${result.smtp}`;
    } catch (e) {
      resultEl.textContent = "Fehler: " + e.message;
    }
    btn.disabled = false;
  } else if (btn.dataset.action === "delete") {
    if (!confirm(`Konto "${account.name}" und alle zugehörigen Regeln löschen?`)) return;
    try {
      await api(`/api/accounts/${id}`, { method: "DELETE" });
      toast("Konto gelöscht.");
      await Promise.all([loadAccounts(), loadRules()]);
    } catch (e) {
      toast("Fehler: " + e.message, true);
    }
  }
});

function openAccountDialog(account) {
  accountForm.reset();
  document.getElementById("account-dialog-title").textContent =
    account ? "Konto bearbeiten" : "Konto hinzufügen";
  if (account) {
    for (const [key, value] of Object.entries(account)) {
      const field = accountForm.elements[key];
      if (!field) continue;
      if (field.type === "checkbox") field.checked = Boolean(value);
      else field.value = value ?? "";
    }
    accountForm.elements.password.value = "";
    accountForm.elements.smtp_password.value = "";
  } else {
    accountForm.elements.id.value = "";
    accountForm.elements.active.checked = true;
  }
  accountDialog.showModal();
}

document.getElementById("btn-new-account").addEventListener("click", () => openAccountDialog(null));
document.getElementById("account-cancel").addEventListener("click", () => accountDialog.close());

accountForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const f = accountForm.elements;
  const payload = {
    name: f.name.value.trim(),
    imap_host: f.imap_host.value.trim(),
    imap_port: Number(f.imap_port.value),
    imap_security: f.imap_security.value,
    username: f.username.value.trim(),
    password: f.password.value,
    smtp_host: f.smtp_host.value.trim(),
    smtp_port: Number(f.smtp_port.value || 587),
    smtp_security: f.smtp_security.value,
    smtp_username: f.smtp_username.value.trim(),
    smtp_password: f.smtp_password.value,
    from_address: f.from_address.value.trim(),
    active: f.active.checked,
  };
  const id = f.id.value;
  try {
    if (id) {
      await api(`/api/accounts/${id}`, { method: "PUT", body: JSON.stringify(payload) });
    } else {
      await api("/api/accounts", { method: "POST", body: JSON.stringify(payload) });
    }
    accountDialog.close();
    toast("Konto gespeichert.");
    await Promise.all([loadAccounts(), loadRules()]);
  } catch (e) {
    toast("Fehler: " + e.message, true);
  }
});

// ---------- Regeln ----------

const ruleDialog = document.getElementById("rule-dialog");
const ruleForm = document.getElementById("rule-form");

async function loadRules() {
  rules = await api("/api/rules");
  const list = document.getElementById("rules-list");
  if (!rules.length) {
    list.innerHTML = '<p class="hint">Noch keine Regeln definiert.</p>';
    return;
  }
  list.innerHTML = rules.map((r) => `
    <div class="card" data-id="${r.id}">
      <div class="card-title">
        ${esc(r.sender_pattern)} &rarr; &#128193; ${esc(r.target_folder)}
        <span class="badge ${r.active ? "on" : "off"}">${r.active ? "aktiv" : "inaktiv"}</span>
        ${r.auto_reply ? '<span class="badge reply">Abwesenheitsnotiz</span>' : ""}
      </div>
      <div class="card-sub">Konto: ${esc(r.account_name)}</div>
      <div class="card-actions">
        <button class="secondary" data-action="edit">Bearbeiten</button>
        <button class="danger" data-action="delete">L&ouml;schen</button>
      </div>
    </div>`).join("");
}

document.getElementById("rules-list").addEventListener("click", async (event) => {
  const btn = event.target.closest("button[data-action]");
  if (!btn) return;
  const id = Number(btn.closest(".card").dataset.id);
  const rule = rules.find((r) => r.id === id);
  if (btn.dataset.action === "edit") {
    openRuleDialog(rule);
  } else if (btn.dataset.action === "delete") {
    if (!confirm(`Regel für "${rule.sender_pattern}" löschen?`)) return;
    try {
      await api(`/api/rules/${id}`, { method: "DELETE" });
      toast("Regel gelöscht.");
      loadRules();
    } catch (e) {
      toast("Fehler: " + e.message, true);
    }
  }
});

function openRuleDialog(rule) {
  if (!accounts.length) {
    toast("Bitte zuerst ein Mailkonto anlegen.", true);
    return;
  }
  ruleForm.reset();
  document.getElementById("rule-dialog-title").textContent =
    rule ? "Regel bearbeiten" : "Regel hinzufügen";
  const select = ruleForm.elements.account_id;
  select.innerHTML = accounts
    .map((a) => `<option value="${a.id}">${esc(a.name)}</option>`)
    .join("");
  if (rule) {
    for (const [key, value] of Object.entries(rule)) {
      const field = ruleForm.elements[key];
      if (!field) continue;
      if (field.type === "checkbox") field.checked = Boolean(value);
      else field.value = value ?? "";
    }
  } else {
    ruleForm.elements.id.value = "";
    ruleForm.elements.active.checked = true;
    ruleForm.elements.reply_subject.value = "Abwesenheitsnotiz";
  }
  updateReplyFields();
  ruleDialog.showModal();
}

function updateReplyFields() {
  document.getElementById("reply-fields").style.display =
    document.getElementById("rule-auto-reply").checked ? "" : "none";
}
document.getElementById("rule-auto-reply").addEventListener("change", updateReplyFields);

document.getElementById("btn-new-rule").addEventListener("click", () => openRuleDialog(null));
document.getElementById("rule-cancel").addEventListener("click", () => ruleDialog.close());

ruleForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const f = ruleForm.elements;
  const payload = {
    account_id: Number(f.account_id.value),
    sender_pattern: f.sender_pattern.value.trim(),
    target_folder: f.target_folder.value.trim(),
    auto_reply: f.auto_reply.checked,
    reply_subject: f.reply_subject.value.trim() || "Abwesenheitsnotiz",
    reply_body: f.reply_body.value,
    active: f.active.checked,
  };
  const id = f.id.value;
  try {
    if (id) {
      await api(`/api/rules/${id}`, { method: "PUT", body: JSON.stringify(payload) });
    } else {
      await api("/api/rules", { method: "POST", body: JSON.stringify(payload) });
    }
    ruleDialog.close();
    toast("Regel gespeichert.");
    loadRules();
  } catch (e) {
    toast("Fehler: " + e.message, true);
  }
});

// ---------- Protokoll ----------

async function loadLogs() {
  const logs = await api("/api/logs");
  const tbody = document.querySelector("#log-table tbody");
  if (!logs.length) {
    tbody.innerHTML = '<tr><td colspan="3" class="hint">Noch keine Einträge.</td></tr>';
    return;
  }
  tbody.innerHTML = logs.map((l) => `
    <tr>
      <td>${esc(l.created_at)}</td>
      <td class="level-${esc(l.level)}">${esc(l.level)}</td>
      <td>${esc(l.message)}</td>
    </tr>`).join("");
}

document.getElementById("btn-refresh-logs").addEventListener("click", loadLogs);

// ---------- Einstellungen ----------

const settingsForm = document.getElementById("settings-form");

async function loadSettings() {
  const settings = await api("/api/settings");
  settingsForm.elements.poll_interval_seconds.value = settings.poll_interval_seconds;
  settingsForm.elements.reply_cooldown_hours.value = settings.reply_cooldown_hours;
}

settingsForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    await api("/api/settings", {
      method: "PUT",
      body: JSON.stringify({
        poll_interval_seconds: Number(settingsForm.elements.poll_interval_seconds.value),
        reply_cooldown_hours: Number(settingsForm.elements.reply_cooldown_hours.value),
      }),
    });
    toast("Einstellungen gespeichert.");
  } catch (e) {
    toast("Fehler: " + e.message, true);
  }
});

// ---------- Start ----------

(async function init() {
  try {
    await Promise.all([loadAccounts(), loadRules(), loadSettings()]);
    loadStatus();
    setInterval(loadStatus, 15000);
  } catch (e) {
    toast("Fehler beim Laden: " + e.message, true);
  }
})();

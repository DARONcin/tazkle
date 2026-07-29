export const accountClientScript = `
const form = document.querySelector("#account-form");
const status = document.querySelector("#status");
const mode = form?.dataset.mode;
const oauthQuery = String(
  form?.querySelector('input[name="oauth_query"]')?.value || ""
);

for (const button of document.querySelectorAll("[data-social-provider]")) {
  button.addEventListener("click", async () => {
    const provider = button.dataset.socialProvider;
    if (!provider) return;
    setBusy(
      true,
      provider === "google"
        ? "Conectando con Google…"
        : "Conectando con Microsoft…"
    );
    try {
      const response = await fetch("/api/auth/sign-in/social", {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ provider, oauth_query: oauthQuery })
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(userMessage(payload));
      if (!payload.url) {
        throw new Error("El proveedor no devolvió una ruta segura de acceso.");
      }
      window.location.assign(payload.url);
    } catch (error) {
      showError(error);
    }
  });
}

form?.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!form.reportValidity()) return;
  const data = new FormData(form);
  const body = {
    email: String(data.get("email") || "").trim(),
    password: String(data.get("password") || ""),
    oauth_query: oauthQuery,
    rememberMe: true
  };
  if (mode === "signup") {
    body.name = String(data.get("name") || "").trim();
  }
  setBusy(true, "Validando de forma segura…");
  try {
    const response = await fetch(
      mode === "signup"
        ? "/api/auth/sign-up/email"
        : "/api/auth/sign-in/email",
      {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json"
        },
        body: JSON.stringify(body)
      }
    );
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(userMessage(payload));

    if (mode === "signup") {
      const continueResponse = await fetch("/api/auth/oauth2/continue", {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ created: true, oauth_query: oauthQuery })
      });
      const continuePayload = await continueResponse.json().catch(() => ({}));
      if (!continueResponse.ok) {
        throw new Error(userMessage(continuePayload));
      }
      if (!continuePayload.url) {
        throw new Error("No fue posible continuar con la autorización.");
      }
      window.location.assign(continuePayload.url);
      return;
    }

    if (!payload.url) throw new Error("No fue posible volver a Tazkle.");
    window.location.assign(payload.url);
  } catch (error) {
    showError(error);
  }
});

function setBusy(value, message = "") {
  for (const control of document.querySelectorAll("button,input")) {
    control.disabled = value;
  }
  if (value) {
    status.textContent = message;
    status.hidden = false;
  }
}

function showError(error) {
  setBusy(false);
  status.textContent = safeMessage(error);
  status.hidden = false;
}

function userMessage(payload) {
  const code = payload?.code || payload?.error?.code;
  if (code === "INVALID_EMAIL_OR_PASSWORD") {
    return "El correo o la contraseña no coinciden.";
  }
  if (
    code === "USER_ALREADY_EXISTS" ||
    code === "USER_ALREADY_EXISTS_USE_ANOTHER_EMAIL"
  ) {
    return "Ya existe una cuenta con ese correo.";
  }
  if (code === "PASSWORD_TOO_SHORT") {
    return "La contraseña debe tener al menos 12 caracteres.";
  }
  if (code === "INVALID_EMAIL") return "Escribe un correo válido.";
  if (code === "PROVIDER_NOT_FOUND") {
    return "Ese proveedor todavía no está configurado.";
  }
  if (code === "OAUTH_LINK_ERROR") {
    return "No fue posible asociar la cuenta del proveedor.";
  }
  return "No fue posible completar el acceso. Revisa los datos e inténtalo nuevamente.";
}

function safeMessage(error) {
  return error instanceof Error && error.message
    ? error.message
    : "No fue posible completar el acceso.";
}
`;

export const consentClientScript = `
const form = document.querySelector("#consent-form");
const status = document.querySelector("#status");
const oauthQuery = String(
  form?.querySelector('input[name="oauth_query"]')?.value || ""
);

form?.addEventListener("submit", async (event) => {
  event.preventDefault();
  const submitter = event.submitter;
  const accept = submitter?.value === "accept";
  setBusy(true);
  try {
    const response = await fetch("/api/auth/oauth2/consent", {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ accept, oauth_query: oauthQuery })
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(userMessage(payload));
    if (!payload.url) throw new Error("No fue posible volver a Tazkle.");
    window.location.assign(payload.url);
  } catch (error) {
    status.textContent = safeMessage(error);
    status.hidden = false;
    setBusy(false);
  }
});

function setBusy(value) {
  for (const control of form?.elements || []) {
    control.disabled = value;
  }
  if (value) {
    status.textContent = "Guardando tu decisión…";
    status.hidden = false;
  }
}

function userMessage() {
  return "No fue posible guardar la autorización.";
}

function safeMessage(error) {
  return error instanceof Error && error.message
    ? error.message
    : "No fue posible completar el acceso.";
}
`;

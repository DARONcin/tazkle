export const accountClientScript = `
const form = document.querySelector("#account-form");
const otpForm = document.querySelector("#otp-form");
const recoveryStep = document.querySelector("#recovery-step");
const status = document.querySelector("#status");
const title = document.querySelector("#page-title");
const alternate = document.querySelector(".alternate");
const socialOptions = document.querySelector(".social-options");
const socialDivider = document.querySelector(".divider");
const otpInput = document.querySelector("#otp");
const otpInstructions = document.querySelector("#otp-instructions");
const resendButton = document.querySelector("#resend-code");
const finishEnrollmentButton = document.querySelector("#finish-enrollment");
const recoveryCodesList = document.querySelector("#recovery-codes");
const forgotPasswordLink = document.querySelector("#forgot-password-link");
const forgotPasswordForm = document.querySelector("#forgot-password-form");
const cancelForgotPasswordButton = document.querySelector("#cancel-forgot-password");
const resetPasswordForm = document.querySelector("#reset-password-form");
const resetPasswordInstructions = document.querySelector("#reset-password-instructions");
const resetOTPInput = document.querySelector("#reset-otp");
const resendResetCodeButton = document.querySelector("#resend-reset-code");
const mode = form?.dataset.mode;
const oauthQuery = String(
  form?.querySelector('input[name="oauth_query"]')?.value || ""
);
let challengeMode = null;
let pendingEmail = "";
let pendingPassword = "";
let pendingResetEmail = "";
let recoveryCodes = [];
let lastCodeSentAt = 0;
let lastResetCodeSentAt = 0;

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
  pendingEmail = body.email;
  pendingPassword = body.password;
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
    if (!response.ok) {
      if (errorCode(payload) === "EMAIL_NOT_VERIFIED") {
        await requestEmailVerificationCode();
        showOTP(
          "email-verification",
          "Solicitamos un código para el correo de tu cuenta. Puede tardar unos segundos."
        );
        return;
      }
      throw new Error(userMessage(payload));
    }

    if (mode === "signup") {
      await requestEmailVerificationCode();
      showOTP(
        "email-verification",
        "Solicitamos un código para " + maskedEmail(pendingEmail) + ". Puede tardar unos segundos."
      );
      return;
    }

    if (payload.twoFactorRedirect === true) {
      await requestTwoFactorCode();
      showOTP(
        "two-factor",
        "Contraseña correcta. Solicitamos el segundo código para " + maskedEmail(pendingEmail) + ". Puede tardar unos segundos."
      );
      return;
    }

    recoveryCodes = await enableTwoFactor();
    await requestTwoFactorCode();
    showOTP(
      "two-factor",
      "Esta cuenta ahora exige dos pasos. Solicitamos un código para " + maskedEmail(pendingEmail) + ". Puede tardar unos segundos."
    );
  } catch (error) {
    showError(error);
  }
});

otpForm?.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!otpForm.reportValidity()) return;
  const code = String(new FormData(otpForm).get("otp") || "").trim();
  setBusy(true, "Verificando el código…");
  try {
    if (challengeMode === "email-verification") {
      const response = await jsonRequest("/api/auth/email-otp/verify-email", {
        email: pendingEmail,
        otp: code
      });
      if (!response.ok) throw new Error(userMessage(response.payload));
      try {
        recoveryCodes = await enableTwoFactor();
      } catch (error) {
        if (mode === "signup" && requestErrorCode(error) === "INVALID_PASSWORD") {
          await showExistingAccountRecovery();
          return;
        }
        throw error;
      }
      showRecoveryCodes();
      return;
    }

    if (challengeMode === "two-factor") {
      const response = await jsonRequest("/api/auth/two-factor/verify-otp", {
        code,
        trustDevice: false
      });
      if (!response.ok) throw new Error(userMessage(response.payload));
      if (recoveryCodes.length > 0) {
        showRecoveryCodes();
      } else {
        await continueAuthorization();
      }
      return;
    }

    throw new Error("El desafío de seguridad ya no está disponible.");
  } catch (error) {
    showError(error);
    otpInput?.focus();
  }
});

resendButton?.addEventListener("click", async () => {
  const remaining = 60 - Math.floor((Date.now() - lastCodeSentAt) / 1000);
  if (lastCodeSentAt > 0 && remaining > 0) {
    showStatus("Podrás solicitar otro código en " + remaining + " segundos.");
    return;
  }

  setBusy(true, "Solicitando un código nuevo…");
  try {
    if (challengeMode === "email-verification") {
      const response = await jsonRequest(
        "/api/auth/email-otp/send-verification-otp",
        {
          email: pendingEmail,
          type: "email-verification"
        }
      );
      if (!response.ok) throw new Error(userMessage(response.payload));
    } else if (challengeMode === "two-factor") {
      await requestTwoFactorCode();
    } else {
      throw new Error("El desafío de seguridad ya no está disponible.");
    }
    lastCodeSentAt = Date.now();
    setBusy(false);
    showStatus("Solicitamos un código nuevo. Usa únicamente el mensaje más reciente.");
    otpInput?.focus();
  } catch (error) {
    showError(error);
  }
});

finishEnrollmentButton?.addEventListener("click", async () => {
  setBusy(true, "Terminando la conexión segura…");
  try {
    await continueAuthorization();
  } catch (error) {
    showError(error);
  }
});

forgotPasswordLink?.addEventListener("click", () => {
  showForgotPassword();
});

cancelForgotPasswordButton?.addEventListener("click", () => {
  showSignInForm();
});

forgotPasswordForm?.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!forgotPasswordForm.reportValidity()) return;
  const email = String(
    new FormData(forgotPasswordForm).get("forgot-email") || ""
  ).trim();
  pendingResetEmail = email;
  setBusy(true, "Solicitando un código…");
  try {
    const response = await jsonRequest(
      "/api/auth/email-otp/request-password-reset",
      { email }
    );
    if (!response.ok) throw new Error(userMessage(response.payload));
    lastResetCodeSentAt = Date.now();
    showResetPassword();
  } catch (error) {
    showError(error);
  }
});

resetPasswordForm?.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!resetPasswordForm.reportValidity()) return;
  const data = new FormData(resetPasswordForm);
  const otp = String(data.get("otp") || "").trim();
  const password = String(data.get("password") || "");
  setBusy(true, "Restableciendo tu contraseña…");
  try {
    const response = await jsonRequest("/api/auth/email-otp/reset-password", {
      email: pendingResetEmail,
      otp,
      password
    });
    if (!response.ok) throw new Error(userMessage(response.payload));
    pendingResetEmail = "";
    showSignInForm("Contraseña actualizada. Inicia sesión con tu nueva contraseña.");
  } catch (error) {
    showError(error);
    resetOTPInput?.focus();
  }
});

resendResetCodeButton?.addEventListener("click", async () => {
  const remaining = 60 - Math.floor((Date.now() - lastResetCodeSentAt) / 1000);
  if (lastResetCodeSentAt > 0 && remaining > 0) {
    showStatus("Podrás solicitar otro código en " + remaining + " segundos.");
    return;
  }

  setBusy(true, "Solicitando un código nuevo…");
  try {
    const response = await jsonRequest(
      "/api/auth/email-otp/request-password-reset",
      { email: pendingResetEmail }
    );
    if (!response.ok) throw new Error(userMessage(response.payload));
    lastResetCodeSentAt = Date.now();
    setBusy(false);
    showStatus("Solicitamos un código nuevo. Usa únicamente el mensaje más reciente.");
    resetOTPInput?.focus();
  } catch (error) {
    showError(error);
  }
});

function showForgotPassword() {
  form.hidden = true;
  if (socialOptions) socialOptions.hidden = true;
  if (socialDivider) socialDivider.hidden = true;
  otpForm.hidden = true;
  recoveryStep.hidden = true;
  resetPasswordForm.hidden = true;
  forgotPasswordForm.hidden = false;
  if (alternate) alternate.hidden = true;
  if (title) title.textContent = "Recuperar contraseña";
  const forgotEmailInput = document.querySelector("#forgot-email");
  if (forgotEmailInput && !forgotEmailInput.value) {
    forgotEmailInput.value = document.querySelector("#email")?.value || "";
  }
  setBusy(false);
  showStatus("Escribe el correo de tu cuenta.");
  forgotEmailInput?.focus();
}

function showResetPassword() {
  forgotPasswordForm.hidden = true;
  resetPasswordForm.hidden = false;
  if (title) title.textContent = "Restablecer contraseña";
  resetPasswordInstructions.textContent =
    "Enviamos un código a " + maskedEmail(pendingResetEmail) + ". Puede tardar unos segundos.";
  setBusy(false);
  showStatus("Revisa tu bandeja de entrada y correo no deseado.");
  resetOTPInput?.focus();
}

function showSignInForm(message) {
  forgotPasswordForm.hidden = true;
  resetPasswordForm.hidden = true;
  otpForm.hidden = true;
  recoveryStep.hidden = true;
  form.hidden = false;
  if (socialOptions) socialOptions.hidden = false;
  if (socialDivider) socialDivider.hidden = false;
  if (alternate) alternate.hidden = false;
  if (title) title.textContent = "Entrar a Tazkle";
  setBusy(false);
  if (message) {
    showStatus(message);
  } else if (status) {
    status.hidden = true;
  }
}

async function enableTwoFactor() {
  if (!pendingPassword) {
    throw new Error("Vuelve a iniciar sesión para activar la protección en dos pasos.");
  }
  const response = await jsonRequest("/api/auth/two-factor/enable", {
    password: pendingPassword,
    issuer: "Tazkle"
  });
  if (!response.ok) throw requestError(response.payload);
  pendingPassword = "";
  if (!Array.isArray(response.payload.backupCodes)) {
    throw new Error("No fue posible crear los códigos de recuperación.");
  }
  return response.payload.backupCodes.filter(
    (code) => typeof code === "string" && code.length > 0
  );
}

async function requestEmailVerificationCode() {
  const response = await jsonRequest(
    "/api/auth/email-otp/send-verification-otp",
    {
      email: pendingEmail,
      type: "email-verification"
    }
  );
  if (!response.ok) throw requestError(response.payload);
  lastCodeSentAt = Date.now();
}

async function requestTwoFactorCode() {
  const response = await jsonRequest("/api/auth/two-factor/send-otp", {
    trustDevice: false
  });
  if (!response.ok) throw new Error(userMessage(response.payload));
  lastCodeSentAt = Date.now();
}

async function continueAuthorization() {
  const response = await jsonRequest("/api/auth/oauth2/continue", {
    created: mode === "signup",
    postLogin: mode === "signin",
    oauth_query: oauthQuery
  });
  if (!response.ok) throw new Error(userMessage(response.payload));
  const destination = response.payload.url || response.payload.redirect_uri;
  if (!destination) {
    throw new Error("No fue posible volver a Tazkle.");
  }
  recoveryCodes = [];
  window.location.assign(destination);
}

async function showExistingAccountRecovery() {
  await jsonRequest("/api/auth/sign-out", {}).catch(() => undefined);
  challengeMode = null;
  pendingPassword = "";
  otpForm.hidden = true;
  form.hidden = true;
  recoveryStep.hidden = true;
  if (socialOptions) socialOptions.hidden = true;
  if (socialDivider) socialDivider.hidden = true;
  if (title) title.textContent = "Esta cuenta ya existía";
  if (alternate) {
    alternate.hidden = false;
    alternate.textContent = "Iniciar sesión con mi cuenta";
  }
  setBusy(false);
  showStatus(
    "El código fue correcto y el correo quedó confirmado. Ahora inicia sesión con la contraseña actual de esa cuenta."
  );
  alternate?.focus();
}

async function jsonRequest(url, body) {
  const response = await fetch(url, {
    method: "POST",
    credentials: "same-origin",
    headers: {
      "Accept": "application/json",
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });
  return {
    ok: response.ok,
    status: response.status,
    payload: await response.json().catch(() => ({}))
  };
}

function requestError(payload) {
  const error = new Error(userMessage(payload));
  error.code = errorCode(payload);
  return error;
}

function requestErrorCode(error) {
  return error && typeof error === "object" && "code" in error
    ? error.code
    : undefined;
}

function showOTP(nextMode, instructions) {
  challengeMode = nextMode;
  form.hidden = true;
  if (socialOptions) socialOptions.hidden = true;
  if (socialDivider) socialDivider.hidden = true;
  otpForm.hidden = false;
  recoveryStep.hidden = true;
  if (alternate) alternate.hidden = true;
  if (title) {
    title.textContent =
      nextMode === "email-verification"
        ? "Verifica tu correo"
        : "Segundo paso";
  }
  otpInstructions.textContent = instructions;
  otpInput.value = "";
  setBusy(false);
  showStatus(
    nextMode === "email-verification"
      ? "Revisa tu bandeja de entrada y correo no deseado."
      : "La sesión no se abrirá hasta verificar este código."
  );
  otpInput.focus();
}

function showRecoveryCodes() {
  otpForm.hidden = true;
  form.hidden = true;
  recoveryStep.hidden = false;
  if (alternate) alternate.hidden = true;
  if (title) title.textContent = "Protección activada";
  recoveryCodesList.replaceChildren();
  for (const code of recoveryCodes) {
    const item = document.createElement("li");
    item.textContent = code;
    recoveryCodesList.append(item);
  }
  setBusy(false);
  showStatus("Guarda estos códigos fuera de Tazkle antes de continuar.");
  finishEnrollmentButton.focus();
}

function setBusy(value, message = "") {
  for (const control of document.querySelectorAll("button,input")) {
    control.disabled = value;
  }
  if (value) {
    status.textContent = message;
    status.hidden = false;
  }
}

function showStatus(message) {
  status.textContent = message;
  status.hidden = false;
}

function showError(error) {
  setBusy(false);
  showStatus(safeMessage(error));
}

function userMessage(payload) {
  const code = errorCode(payload);
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
  if (code === "PASSWORD_TOO_LONG") {
    return "La contraseña no puede superar 128 caracteres.";
  }
  if (code === "USER_NOT_FOUND") {
    return "No fue posible restablecer la contraseña. Solicita un código nuevo.";
  }
  if (code === "INVALID_PASSWORD") {
    return "La contraseña no coincide con la cuenta existente.";
  }
  if (code === "INVALID_EMAIL") return "Escribe un correo válido.";
  if (code === "EMAIL_NOT_VERIFIED") {
    return "Primero debes verificar el correo de la cuenta.";
  }
  if (code === "INVALID_OTP" || code === "INVALID_CODE") {
    return "El código no coincide. Revisa los seis dígitos.";
  }
  if (code === "OTP_EXPIRED" || code === "OTP_HAS_EXPIRED") {
    return "El código caducó. Solicita uno nuevo.";
  }
  if (
    code === "TOO_MANY_ATTEMPTS" ||
    code === "TOO_MANY_ATTEMPTS_REQUEST_NEW_CODE"
  ) {
    return "Se agotaron los intentos. Solicita un código nuevo.";
  }
  if (code === "ACCOUNT_TEMPORARILY_LOCKED") {
    return "La cuenta está bloqueada temporalmente por seguridad. Inténtalo dentro de 15 minutos.";
  }
  if (code === "PROVIDER_NOT_FOUND") {
    return "Ese proveedor todavía no está configurado.";
  }
  if (code === "OAUTH_LINK_ERROR") {
    return "No fue posible asociar la cuenta del proveedor.";
  }
  if (code === "invalid_signature" || code === "INVALID_SIGNATURE") {
    return "Esta ventana segura expiró. Vuelve a Tazkle, cancela el intento y abre Crear cuenta nuevamente.";
  }
  return "No fue posible completar el acceso. Revisa los datos e inténtalo nuevamente.";
}

function errorCode(payload) {
  const directError =
    typeof payload?.error === "string" ? payload.error : undefined;
  return payload?.code || payload?.error?.code || directError;
}

function maskedEmail(email) {
  const parts = String(email).split("@");
  if (parts.length !== 2) return "tu correo";
  const name = parts[0];
  const visible = name.slice(0, Math.min(2, name.length));
  return visible + "•••@" + parts[1];
}

function safeMessage(error) {
  return error instanceof Error && error.message
    ? error.message
    : "No fue posible completar el acceso.";
}
`;

export const deleteAccountClientScript = `
const form = document.querySelector("#delete-account-form");
const confirmation = document.querySelector("#confirmation");
const deleteButton = document.querySelector("#delete-account-button");
const status = document.querySelector("#status");

confirmation?.addEventListener("input", () => {
  if (deleteButton) {
    deleteButton.disabled = confirmation.value.trim() !== "ELIMINAR";
  }
});

form?.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!form.reportValidity()) return;
  if (confirmation?.value.trim() !== "ELIMINAR") {
    showStatus("Escribe exactamente ELIMINAR para continuar.");
    confirmation?.focus();
    return;
  }

  setBusy(true);
  try {
    const response = await fetch("/api/auth/tazkle-delete-user", {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ confirmation: "ELIMINAR" })
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok || payload.success !== true) {
      throw new Error(deletionMessage(payload, response.status));
    }

    const data = new FormData(form);
    const callback = String(data.get("callback") || "");
    const state = String(data.get("state") || "");
    const destination = new URL(callback);
    destination.searchParams.set("state", state);
    window.location.assign(destination.toString());
  } catch (error) {
    setBusy(false);
    showStatus(
      error instanceof Error
        ? error.message
        : "No fue posible eliminar la cuenta."
    );
  }
});

function setBusy(value) {
  for (const control of form?.elements || []) {
    control.disabled = value;
  }
  if (value) {
    showStatus("Eliminando la cuenta y revocando sus sesiones…");
  }
}

function showStatus(message) {
  if (!status) return;
  status.textContent = message;
  status.hidden = false;
}

function deletionMessage(payload, statusCode) {
  const code = payload?.code || payload?.error?.code;
  if (statusCode === 401 || code === "UNAUTHORIZED") {
    return "La sesión ya no es válida. Cierra esta ventana, inicia sesión nuevamente y repite la operación.";
  }
  if (code === "SESSION_EXPIRED") {
    return "Por seguridad necesitas una sesión reciente. Vuelve a iniciar sesión antes de eliminar la cuenta.";
  }
  if (code === "REMOTE_DELETION_UNCONFIRMED") {
    return "Identity no pudo confirmar el borrado remoto. Tus datos locales se conservaron.";
  }
  return "No fue posible eliminar la cuenta. No se borraron los datos locales.";
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

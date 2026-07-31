import { randomUUID } from "node:crypto";
import type { IdentityConfiguration } from "./config.js";

const RESEND_EMAIL_ENDPOINT = "https://api.resend.com/emails";
const DELIVERY_TIMEOUT_MILLISECONDS = 5_000;

export type AuthenticationEmailKind =
  | "email-verification"
  | "two-factor"
  | "forget-password"
  | "change-email";

export type AuthenticationEmailSender = {
  sendOTP: (input: {
    to: string;
    otp: string;
    kind: AuthenticationEmailKind;
  }) => Promise<void>;
};

export function createAuthenticationEmailSender(
  configuration: IdentityConfiguration,
  fetchImplementation: typeof fetch = fetch,
): AuthenticationEmailSender {
  return {
    sendOTP: async ({ to, otp, kind }) => {
      if (!/^\d{6}$/.test(otp)) {
        throw new Error("Authentication email code is invalid");
      }

      const response = await fetchImplementation(RESEND_EMAIL_ENDPOINT, {
        method: "POST",
        redirect: "error",
        headers: {
          Accept: "application/json",
          Authorization: `Bearer ${configuration.transactionalEmail.apiKey}`,
          "Content-Type": "application/json",
          "Idempotency-Key": randomUUID(),
        },
        body: JSON.stringify({
          from: configuration.transactionalEmail.from,
          to: [to],
          subject: emailSubject(kind),
          text: emailText(otp, kind),
        }),
        signal: AbortSignal.timeout(DELIVERY_TIMEOUT_MILLISECONDS),
      });

      if (!response.ok) {
        throw new Error("Authentication email delivery failed");
      }
    },
  };
}

function emailSubject(kind: AuthenticationEmailKind): string {
  switch (kind) {
    case "email-verification":
      return "Verifica tu correo de Tazkle";
    case "two-factor":
      return "Tu código de seguridad de Tazkle";
    case "forget-password":
      return "Recupera tu cuenta de Tazkle";
    case "change-email":
      return "Confirma el cambio de correo en Tazkle";
  }
}

function emailText(otp: string, kind: AuthenticationEmailKind): string {
  const purpose = {
    "email-verification": "verificar tu correo",
    "two-factor": "completar el inicio de sesión",
    "forget-password": "recuperar tu cuenta",
    "change-email": "confirmar el cambio de correo",
  }[kind];

  return [
    `Tu código para ${purpose} es: ${otp}`,
    "",
    "Caduca en 5 minutos y sólo puede utilizarse una vez.",
    "Si no solicitaste este código, ignora este mensaje y no lo compartas.",
  ].join("\n");
}

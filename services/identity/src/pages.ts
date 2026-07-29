import { randomBytes } from "node:crypto";
import type { SocialProviderID } from "./config.js";

export type IdentityPage = {
  body: string;
  contentSecurityPolicy: string;
};

export function signInPage(
  search: string,
  socialProviders: readonly SocialProviderID[] = [],
): IdentityPage {
  return accountPage("signin", search, socialProviders);
}

export function signUpPage(
  search: string,
  socialProviders: readonly SocialProviderID[] = [],
): IdentityPage {
  return accountPage("signup", search, socialProviders);
}

export function consentPage(search: string): IdentityPage {
  const nonce = randomBytes(18).toString("base64");

  return {
    contentSecurityPolicy: contentSecurityPolicy(nonce),
    body: documentShell({
      title: "Autorizar Tazkle",
      nonce,
      content: `
        <main class="auth-shell">
          ${brandMark()}
          <section class="auth-card" aria-labelledby="page-title">
            <p class="eyebrow">Permisos de cuenta</p>
            <h1 id="page-title">Conectar con Tazkle</h1>
            <p class="lead">Tazkle solicita conocer tu perfil y mantener una sesión segura para sincronizar tus proyectos.</p>
            <ul class="scope-list">
              <li>Identificar tu cuenta mediante nombre y correo.</li>
              <li>Mantener la sesión hasta que cierres sesión o revoques el acceso.</li>
              <li>Usar el acceso únicamente con los servicios de Tazkle.</li>
            </ul>
            <form id="consent-form">
              <input type="hidden" name="oauth_query" value="${escapeAttribute(normalizedQuery(search))}" />
              <p id="status" class="status" role="status" aria-live="polite" hidden></p>
              <div class="actions split">
                <button class="button secondary" type="submit" name="decision" value="deny">Cancelar</button>
                <button class="button primary" type="submit" name="decision" value="accept">Autorizar</button>
              </div>
            </form>
          </section>
        </main>
      `,
      scriptSource: "/identity/client/consent.js",
    }),
  };
}

function accountPage(
  mode: "signin" | "signup",
  search: string,
  socialProviders: readonly SocialProviderID[],
): IdentityPage {
  const nonce = randomBytes(18).toString("base64");
  const isSignUp = mode === "signup";
  const title = isSignUp ? "Crear cuenta" : "Entrar a Tazkle";
  const alternateText = isSignUp
    ? "Ya tengo una cuenta"
    : "Crear una cuenta";
  const alternateURL = authorizationRestartURL(
    search,
    isSignUp ? "signin" : "signup",
  );
  const submitText = isSignUp ? "Crear cuenta y continuar" : "Continuar";

  return {
    contentSecurityPolicy: contentSecurityPolicy(nonce),
    body: documentShell({
      title,
      nonce,
      content: `
        <main class="auth-shell">
          ${brandMark()}
          <section class="auth-card" aria-labelledby="page-title">
            <p class="eyebrow">Cuenta Tazkle</p>
            <h1 id="page-title">${title}</h1>
            <p class="lead">Conecta proyectos, colaboración y sincronización con una cuenta segura.</p>
            ${socialProviderButtons(socialProviders)}
            <form id="account-form" data-mode="${mode}">
              <input type="hidden" name="oauth_query" value="${escapeAttribute(normalizedQuery(search))}" />
              ${
                isSignUp
                  ? `<label for="name">Nombre</label>
                     <input id="name" name="name" type="text" autocomplete="name" maxlength="120" required />`
                  : ""
              }
              <label for="email">Correo</label>
              <input id="email" name="email" type="email" inputmode="email" autocomplete="email" maxlength="320" required autofocus />
              <label for="password">Contraseña</label>
              <input id="password" name="password" type="password" autocomplete="${isSignUp ? "new-password" : "current-password"}" minlength="12" maxlength="128" required />
              ${
                isSignUp
                  ? `<p class="field-help">Usa al menos 12 caracteres. Tazkle nunca recibe esta contraseña en la app de macOS.</p>`
                  : ""
              }
              <p id="status" class="status" role="status" aria-live="polite" aria-atomic="true" hidden></p>
              <button class="button primary" type="submit">${submitText}</button>
            </form>
            <a class="alternate" href="${escapeAttribute(alternateURL)}">${alternateText}</a>
          </section>
          <p class="privacy-note">El acceso ocurre en una ventana segura del sistema. Puedes seguir trabajando localmente sin conectar una cuenta.</p>
        </main>
      `,
      scriptSource: "/identity/client/account.js",
    }),
  };
}

function documentShell({
  title,
  nonce,
  content,
  scriptSource,
}: {
  title: string;
  nonce: string;
  content: string;
  scriptSource: string;
}): string {
  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="color-scheme" content="dark light" />
  <title>${escapeHTML(title)} · Tazkle</title>
  <style nonce="${nonce}">
    :root { color-scheme: dark; --bg:rgb(8 19 29); --panel:rgb(19 36 48); --panel2:rgb(14 27 38); --text:rgb(237 242 246); --muted:rgb(167 179 191); --line:rgb(44 65 81); --blue:rgb(79 124 255); --purple:rgb(140 107 255); --cyan:rgb(109 214 231); --danger:rgb(255 107 115); }
    * { box-sizing:border-box; }
    body { margin:0; min-height:100vh; color:var(--text); background:radial-gradient(circle at 50% -10%,rgba(79,124,255,.18),transparent 38%),var(--bg); font:15px/1.5 -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif; }
    button,input { font:inherit; }
    .auth-shell { width:min(100% - 32px,460px); min-height:100vh; margin:auto; display:flex; flex-direction:column; justify-content:center; gap:20px; padding:32px 0; }
    .brand { display:flex; justify-content:center; align-items:center; gap:10px; font-size:22px; font-weight:750; letter-spacing:-.02em; }
    .mark { width:32px; height:32px; display:grid; place-items:center; border-radius:10px; background:linear-gradient(145deg,var(--blue),var(--purple)); box-shadow:0 10px 30px rgba(79,124,255,.25); }
    .mark svg { width:20px; height:20px; }
    .auth-card { padding:30px; border:1px solid var(--line); border-radius:22px; background:linear-gradient(180deg,rgba(19,36,48,.97),rgba(14,27,38,.98)); box-shadow:0 24px 80px rgba(0,0,0,.32); }
    .eyebrow { margin:0 0 8px; color:var(--cyan); font-size:12px; font-weight:750; letter-spacing:.1em; text-transform:uppercase; }
    h1 { margin:0; font-size:30px; line-height:1.15; letter-spacing:-.035em; }
    .lead { margin:12px 0 24px; color:var(--muted); }
    form { display:grid; gap:10px; }
    label { margin-top:4px; font-weight:650; }
    input { width:100%; padding:12px 14px; color:var(--text); background:rgb(9 22 32); border:1px solid var(--line); border-radius:11px; outline:none; }
    input:focus-visible { border-color:var(--blue); box-shadow:0 0 0 3px rgba(79,124,255,.25); }
    .field-help,.privacy-note { margin:0; color:var(--muted); font-size:13px; }
    .button { min-height:44px; margin-top:8px; padding:10px 16px; border:0; border-radius:11px; font-weight:700; cursor:pointer; }
    .button:focus-visible,.alternate:focus-visible { outline:3px solid rgba(109,214,231,.45); outline-offset:3px; }
    .button:disabled { cursor:progress; opacity:.66; }
    .primary { color:white; background:linear-gradient(135deg,var(--blue),var(--purple)); }
    .secondary { color:var(--text); background:rgb(38 56 71); border:1px solid var(--line); }
    .social-options { display:grid; gap:10px; }
    .social-button { width:100%; min-height:44px; margin:0; display:flex; align-items:center; justify-content:center; gap:10px; color:var(--text); background:rgb(9 22 32); border:1px solid var(--line); }
    .social-button:hover { border-color:rgb(86 111 130); background:rgb(16 31 42); }
    .provider-icon { width:18px; height:18px; flex:none; }
    .divider { display:flex; align-items:center; gap:12px; margin:20px 0 14px; color:var(--muted); font-size:12px; text-transform:uppercase; letter-spacing:.08em; }
    .divider::before,.divider::after { content:""; height:1px; flex:1; background:var(--line); }
    .alternate { display:block; width:max-content; margin:20px auto 0; color:rgb(157 181 255); text-decoration:none; }
    .status { margin:4px 0 0; color:rgb(255 210 122); }
    .scope-list { margin:0 0 22px; padding-left:22px; color:var(--muted); }
    .scope-list li + li { margin-top:8px; }
    .actions { display:flex; justify-content:flex-end; gap:10px; }
    .actions .button { flex:1; }
    .privacy-note { padding:0 20px; text-align:center; }
    @media (prefers-reduced-motion:no-preference) { .auth-card { animation:enter .24s ease-out both; } @keyframes enter { from { opacity:0; transform:translateY(8px); } } }
    @media (prefers-color-scheme:light) { :root { color-scheme:light; --bg:rgb(237 242 246); --panel:rgb(255 255 255); --panel2:rgb(247 249 251); --text:rgb(8 19 29); --muted:rgb(83 101 114); --line:rgb(203 214 221); } body { background:radial-gradient(circle at 50% -10%,rgba(79,124,255,.13),transparent 40%),var(--bg); } input,.social-button { background:rgb(255 255 255); } .social-button:hover { background:rgb(247 249 251); } .secondary { background:rgb(231 237 241); } }
    @media (max-width:480px) { .auth-card { padding:24px 20px; border-radius:18px; } h1 { font-size:27px; } }
  </style>
</head>
<body>
  ${content}
  <script src="${escapeAttribute(scriptSource)}" defer></script>
</body>
</html>`;
}

function brandMark(): string {
  return `<div class="brand" aria-label="Tazkle">
    <span class="mark" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="none">
        <path d="M12 4v16M5.5 8.5c2.5 0 3.5 1.5 6.5 1.5s4-1.5 6.5-1.5" stroke="white" stroke-width="2.2" stroke-linecap="round"/>
        <circle cx="5.5" cy="8.5" r="2" fill="white"/><circle cx="18.5" cy="8.5" r="2" fill="white"/><circle cx="12" cy="20" r="2" fill="white"/>
      </svg>
    </span>
    <span>Tazkle</span>
  </div>`;
}

function socialProviderButtons(
  providers: readonly SocialProviderID[],
): string {
  if (providers.length === 0) {
    return "";
  }

  const buttons = providers
    .map((provider) => {
      if (provider === "google") {
        return `<button class="button social-button" type="button" data-social-provider="google">
          <svg class="provider-icon" viewBox="0 0 18 18" aria-hidden="true">
            <path fill="rgb(66 133 244)" d="M17.6 9.2c0-.6-.1-1.2-.2-1.7H9v3.2h4.8a4.1 4.1 0 0 1-1.8 2.7v2.2h2.9c1.7-1.6 2.7-3.8 2.7-6.4Z"/>
            <path fill="rgb(52 168 83)" d="M9 18c2.4 0 4.5-.8 5.9-2.2L12 13.5c-.8.5-1.8.9-3 .9-2.3 0-4.3-1.6-5-3.7H1v2.3A9 9 0 0 0 9 18Z"/>
            <path fill="rgb(251 188 5)" d="M4 10.7A5.4 5.4 0 0 1 4 7.3V5H1a9 9 0 0 0 0 8l3-2.3Z"/>
            <path fill="rgb(234 67 53)" d="M9 3.6c1.3 0 2.5.5 3.4 1.3L15 2.3A8.7 8.7 0 0 0 9 0a9 9 0 0 0-8 5l3 2.3c.7-2.1 2.7-3.7 5-3.7Z"/>
          </svg>
          Continuar con Google
        </button>`;
      }
      return `<button class="button social-button" type="button" data-social-provider="microsoft">
        <svg class="provider-icon" viewBox="0 0 18 18" aria-hidden="true">
          <path fill="rgb(242 80 34)" d="M0 0h8.5v8.5H0z"/><path fill="rgb(127 186 0)" d="M9.5 0H18v8.5H9.5z"/>
          <path fill="rgb(0 164 239)" d="M0 9.5h8.5V18H0z"/><path fill="rgb(255 185 0)" d="M9.5 9.5H18V18H9.5z"/>
        </svg>
        Continuar con Microsoft
      </button>`;
    })
    .join("");

  return `<div class="social-options" aria-label="Proveedores de acceso">${buttons}</div>
    <div class="divider" aria-hidden="true"><span>o usa tu correo</span></div>`;
}

function normalizedQuery(search: string): string {
  return search.startsWith("?") ? search.slice(1) : search;
}

function authorizationRestartURL(
  search: string,
  mode: "signin" | "signup",
): string {
  const source = new URLSearchParams(normalizedQuery(search));
  const next = new URLSearchParams();
  for (const name of [
    "client_id",
    "redirect_uri",
    "response_type",
    "scope",
    "state",
    "code_challenge",
    "code_challenge_method",
    "resource",
  ]) {
    const value = source.get(name);
    if (value) {
      next.set(name, value);
    }
  }
  if (mode === "signup") {
    next.set("prompt", "create");
  }
  return `/api/auth/oauth2/authorize?${next.toString()}`;
}

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function escapeAttribute(value: string): string {
  return escapeHTML(value).replaceAll("`", "&#96;");
}

function contentSecurityPolicy(nonce: string): string {
  return [
    "default-src 'none'",
    `style-src 'nonce-${nonce}'`,
    "script-src 'self'",
    "connect-src 'self'",
    "img-src 'self' data:",
    "font-src 'self'",
    "form-action 'self'",
    "base-uri 'none'",
    "frame-ancestors 'none'",
  ].join("; ");
}

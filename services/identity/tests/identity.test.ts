import assert from "node:assert/strict";
import test from "node:test";
import { createIdentityApp } from "../src/app.js";
import { authorizationCodeLifetimeSeconds } from "../src/auth.js";

test("authorization codes stay short-lived while allowing account completion", () => {
  assert.equal(authorizationCodeLifetimeSeconds, 10 * 60);
});

test("identity publishes its bounded capability", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async () => new Response(null, { status: 204 }),
    },
  });

  const response = await app.request("/internal/capabilities");

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    service: "identity",
    authority: "identity",
    writesDomain: false,
    externalEgress: true,
  });
});

test("sign-in page has a strict CSP, accessible status and no reflected script", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async () => new Response(null, { status: 204 }),
    },
  });

  const response = await app.request(
    "/sign-in?client_id=%3C%2Fscript%3E%3Cscript%3Ealert(1)%3C%2Fscript%3E",
  );
  const body = await response.text();
  const csp = response.headers.get("content-security-policy") ?? "";

  assert.equal(response.status, 200);
  assert.match(csp, /default-src 'none'/);
  assert.match(csp, /script-src 'self'/);
  assert.match(body, /role="status"/);
  assert.match(body, /src="\/identity\/client\/account\.js" defer/);
  assert.doesNotMatch(body, /addEventListener/);
  assert.doesNotMatch(body, /<\/script><script>alert/);
  assert.match(body, /%3C%2Fscript%3E/);
  assert.doesNotMatch(body, /data-social-provider="/);
});

test("sign-in page exposes only configured social providers", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async () => new Response(null, { status: 204 }),
    },
    socialProviders: ["google", "microsoft"],
  });

  const response = await app.request("/sign-in?client_id=tazkle-macos");
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.match(body, /data-social-provider="google"/);
  assert.match(body, /Continuar con Google/);
  assert.match(body, /data-social-provider="microsoft"/);
  assert.match(body, /Continuar con Microsoft/);
  assert.match(body, /name="oauth_query"/);
});

test("sign-up page keeps browser validation and an atomic live status", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async () => new Response(null, { status: 204 }),
    },
  });

  const response = await app.request("/sign-up?client_id=tazkle-macos");
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.match(body, /<form id="account-form" data-mode="signup">/);
  assert.doesNotMatch(body, /<form id="account-form" novalidate>/);
  assert.match(body, /aria-live="polite" aria-atomic="true"/);
  assert.match(body, /id="otp-form" hidden/);
  assert.match(body, /autocomplete="one-time-code"/);
  assert.match(body, /pattern="\[0-9\]\{6\}"/);
  assert.match(body, /id="recovery-step"/);
  assert.match(body, /name="oauth_query"/);
  assert.match(body, /src="\/identity\/client\/account\.js" defer/);
});

test("sign-in page offers password recovery that sign-up does not", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async () => new Response(null, { status: 204 }),
    },
  });

  const signIn = await app.request("/sign-in?client_id=tazkle-macos");
  const signInBody = await signIn.text();
  const signUp = await app.request("/sign-up?client_id=tazkle-macos");
  const signUpBody = await signUp.text();

  assert.match(signInBody, /id="forgot-password-link"/);
  assert.match(signInBody, /id="forgot-password-form" hidden/);
  assert.match(signInBody, /id="reset-password-form" hidden/);
  assert.match(signInBody, /autocomplete="one-time-code"/);
  assert.doesNotMatch(signUpBody, /id="forgot-password-link"/);
  assert.doesNotMatch(signUpBody, /id="forgot-password-form"/);
  assert.doesNotMatch(signUpBody, /id="reset-password-form"/);
});

test("account client script performs validated sign-up and OAuth continuation", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async () => new Response(null, { status: 204 }),
    },
  });

  const response = await app.request("/identity/client/account.js");
  const script = await response.text();

  assert.equal(response.status, 200);
  assert.match(
    response.headers.get("content-type") ?? "",
    /application\/javascript/,
  );
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.match(script, /form\?\.addEventListener\("submit"/);
  assert.match(script, /form\.reportValidity\(\)/);
  assert.ok(
    script.indexOf("new FormData(form)") <
      script.indexOf('setBusy(true, "Validando de forma segura…")'),
  );
  assert.match(script, /\/api\/auth\/sign-up\/email/);
  assert.match(script, /\/api\/auth\/email-otp\/verify-email/);
  assert.match(script, /\/api\/auth\/two-factor\/enable/);
  assert.match(script, /\/api\/auth\/two-factor\/send-otp/);
  assert.match(script, /\/api\/auth\/two-factor\/verify-otp/);
  assert.match(script, /\/api\/auth\/oauth2\/continue/);
  assert.match(script, /await requestEmailVerificationCode\(\)/);
  assert.match(script, /created: mode === "signup"/);
  assert.match(script, /postLogin: mode === "signin"/);
  assert.match(script, /showExistingAccountRecovery/);
  assert.match(script, /El código fue correcto y el correo quedó confirmado/);
  assert.match(script, /Solicitamos el segundo código/);
  assert.doesNotMatch(script, /Enviamos el segundo código/);
  assert.match(script, /trustDevice: false/);
  assert.match(script, /recoveryCodesList\.replaceChildren/);
  assert.match(script, /invalid_signature/);
  assert.match(script, /Esta ventana segura expiró/);
  assert.match(script, /\/api\/auth\/email-otp\/request-password-reset/);
  assert.match(script, /\/api\/auth\/email-otp\/reset-password/);
  assert.match(script, /pendingResetEmail = ""/);
  assert.match(script, /Contraseña actualizada\. Inicia sesión con tu nueva contraseña\./);
});

test("consent page loads a same-origin script that submits the decision", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async () => new Response(null, { status: 204 }),
    },
  });

  const page = await app.request("/consent?client_id=tazkle-macos");
  const pageBody = await page.text();
  const scriptResponse = await app.request("/identity/client/consent.js");
  const script = await scriptResponse.text();

  assert.match(pageBody, /name="oauth_query"/);
  assert.match(pageBody, /src="\/identity\/client\/consent\.js" defer/);
  assert.match(script, /form\?\.addEventListener\("submit"/);
  assert.match(script, /\/api\/auth\/oauth2\/consent/);
});

test("account deletion page requires a bounded callback and explicit phrase", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async () => new Response(null, { status: 204 }),
    },
  });
  const state = "a".repeat(43);
  const validPage = await app.request(
    `/account/delete?callback=${encodeURIComponent("app.tazkle.desktop:/account/deleted")}&state=${state}`,
  );
  const validBody = await validPage.text();
  const invalidBody = await (
    await app.request(
      `/account/delete?callback=${encodeURIComponent("https://evil.example/delete")}&state=${state}`,
    )
  ).text();
  const script = await (
    await app.request("/identity/client/delete-account.js")
  ).text();

  assert.equal(validPage.status, 200);
  assert.match(validBody, /id="delete-account-form"/);
  assert.match(validBody, /Escribe ELIMINAR para confirmar/);
  assert.match(validBody, /verificó nuevamente tu cuenta/);
  assert.match(
    validBody,
    /src="\/identity\/client\/delete-account\.js" defer/,
  );
  assert.doesNotMatch(invalidBody, /id="delete-account-form"/);
  assert.match(invalidBody, /solicitud de eliminación no es válida/);
  assert.match(script, /confirmation\.value\.trim\(\) !== "ELIMINAR"/);
  assert.match(script, /\/api\/auth\/tazkle-delete-user/);
  assert.match(script, /confirmation: "ELIMINAR"/);
  assert.match(script, /credentials: "same-origin"/);
  assert.doesNotMatch(script, /innerHTML/);
});

test("account deletion confirms the remote identity is absent before succeeding", async () => {
  const delegatedPaths: string[] = [];
  const verifiedUserIDs: string[] = [];
  const app = createIdentityApp({
    auth: {
      handler: async (request) => {
        const path = new URL(request.url).pathname;
        delegatedPaths.push(path);
        if (path === "/api/auth/get-session") {
          return Response.json({
            session: { id: "session-123" },
            user: { id: "user-123" },
          });
        }
        if (path === "/api/auth/delete-user") {
          return Response.json(
            {
              success: true,
              message: "User deleted",
            },
            {
              headers: {
                "Set-Cookie":
                  "tazkle.session_token=; Max-Age=0; HttpOnly; SameSite=Lax",
              },
            },
          );
        }
        return Response.json({ code: "NOT_FOUND" }, { status: 404 });
      },
    },
    accountDeletion: {
      userExists: async (userID) => {
        verifiedUserIDs.push(userID);
        return false;
      },
    },
  });

  const response = await app.request("/api/auth/tazkle-delete-user", {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      Cookie: "tazkle.session_token=signed",
      Origin: "https://identity.tazkle.app",
    },
    body: JSON.stringify({ confirmation: "ELIMINAR" }),
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    success: true,
    message: "User deleted",
  });
  assert.deepEqual(delegatedPaths, [
    "/api/auth/get-session",
    "/api/auth/delete-user",
  ]);
  assert.deepEqual(verifiedUserIDs, ["user-123"]);
  assert.match(
    response.headers.get("set-cookie") ?? "",
    /Max-Age=0/,
  );
});

test("account deletion preserves local data when the remote user remains", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async (request) => {
        const path = new URL(request.url).pathname;
        if (path === "/api/auth/get-session") {
          return Response.json({
            session: { id: "session-123" },
            user: { id: "user-123" },
          });
        }
        return Response.json({
          success: true,
          message: "User deleted",
        });
      },
    },
    accountDeletion: {
      userExists: async () => true,
    },
  });

  const response = await app.request("/api/auth/tazkle-delete-user", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Cookie: "tazkle.session_token=signed",
    },
    body: JSON.stringify({ confirmation: "ELIMINAR" }),
  });
  const payload = await response.json();

  assert.equal(response.status, 503);
  assert.equal(payload.code, "REMOTE_DELETION_UNCONFIRMED");
  assert.match(payload.message, /datos locales se conservaron/);
});

test("account deletion rejects an invalid phrase before touching Identity", async () => {
  let delegatedCalls = 0;
  const app = createIdentityApp({
    auth: {
      handler: async () => {
        delegatedCalls += 1;
        return Response.json({ success: true });
      },
    },
    accountDeletion: {
      userExists: async () => false,
    },
  });

  const response = await app.request("/api/auth/tazkle-delete-user", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ confirmation: "eliminar" }),
  });

  assert.equal(response.status, 400);
  assert.equal(delegatedCalls, 0);
});

test("account mode links restart authorization without reusing signed state", async () => {
  const app = createIdentityApp({
    auth: {
      handler: async () => new Response(null, { status: 204 }),
    },
  });
  const common =
    "client_id=tazkle-macos&redirect_uri=app.tazkle.desktop%3A%2Foauth%2Fcallback" +
    "&response_type=code&scope=openid+email&state=state" +
    "&code_challenge=challenge&code_challenge_method=S256";

  const signUpBody = await (
    await app.request(`/sign-up?${common}&prompt=create&sig=old-signature`)
  ).text();
  const signInBody = await (
    await app.request(`/sign-in?${common}&sig=old-signature`)
  ).text();
  const signUpAlternate = signUpBody.match(
    /<a class="alternate" href="([^"]+)"/,
  )?.[1];
  const signInAlternate = signInBody.match(
    /<a class="alternate" href="([^"]+)"/,
  )?.[1];

  assert.ok(signUpAlternate?.startsWith("/api/auth/oauth2/authorize?"));
  assert.doesNotMatch(signUpAlternate, /old-signature|prompt=create/);
  assert.ok(signInAlternate?.startsWith("/api/auth/oauth2/authorize?"));
  assert.match(signInAlternate, /prompt=create/);
  assert.doesNotMatch(signInAlternate, /old-signature/);
});

test("auth endpoints are delegated without exposing unrelated routes", async () => {
  const delegatedPaths: string[] = [];
  const app = createIdentityApp({
    auth: {
      handler: async (request) => {
        delegatedPaths.push(new URL(request.url).pathname);
        return Response.json({ delegated: true });
      },
    },
  });

  const response = await app.request("/api/auth/.well-known/openid-configuration");
  const authorizationServerMetadata = await app.request(
    "/.well-known/oauth-authorization-server/api/auth",
  );
  const missing = await app.request("/admin");

  assert.equal(response.status, 200);
  assert.equal(authorizationServerMetadata.status, 200);
  assert.deepEqual(delegatedPaths, [
    "/api/auth/.well-known/openid-configuration",
    "/.well-known/oauth-authorization-server/api/auth",
  ]);
  assert.equal(missing.status, 404);
});

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
    externalEgress: false,
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
  assert.match(body, /name="oauth_query"/);
  assert.match(body, /src="\/identity\/client\/account\.js" defer/);
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
  assert.match(script, /\/api\/auth\/oauth2\/continue/);
  assert.match(script, /created: true/);
  assert.match(script, /invalid_signature/);
  assert.match(script, /Esta ventana segura expiró/);
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

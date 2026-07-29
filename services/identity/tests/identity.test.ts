import assert from "node:assert/strict";
import test from "node:test";
import { createIdentityApp } from "../src/app.js";

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

test("sign-in page has a nonce CSP, accessible status and no reflected script", async () => {
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
  assert.match(csp, /script-src 'nonce-/);
  assert.match(body, /role="status"/);
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
  assert.match(body, /oauth_query: oauthQuery/);
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

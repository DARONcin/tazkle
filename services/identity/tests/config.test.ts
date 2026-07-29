import assert from "node:assert/strict";
import test from "node:test";
import {
  enabledSocialProviders,
  identityConfigurationFromEnvironment,
} from "../src/config.js";

const secret = "test-better-auth-secret-at-least-32-bytes";

test("identity accepts an explicit loopback issuer outside production", () => {
  const configuration = identityConfigurationFromEnvironment({
    NODE_ENV: "development",
    ALLOW_INSECURE_LOCAL_OIDC: "true",
    BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
    BETTER_AUTH_SECRET: secret,
    DATABASE_URL: "postgres://identity:password@postgres/tazkle",
  });

  assert.equal(
    configuration.publicBaseURL.toString(),
    "http://127.0.0.1:8787/api/auth",
  );
  assert.equal(configuration.macOSClient.id, "tazkle-macos");
  assert.equal(
    configuration.macOSClient.redirectURI,
    "app.tazkle.desktop:/oauth/callback",
  );
  assert.equal(configuration.secureCookies, false);
});

test("identity refuses non-loopback HTTP and HTTP in production", () => {
  assert.throws(() =>
    identityConfigurationFromEnvironment({
      NODE_ENV: "development",
      ALLOW_INSECURE_LOCAL_OIDC: "true",
      BETTER_AUTH_URL: "http://identity.example.com/api/auth",
      BETTER_AUTH_SECRET: secret,
      DATABASE_URL: "postgres://identity:password@postgres/tazkle",
    }),
  );

  assert.throws(() =>
    identityConfigurationFromEnvironment({
      NODE_ENV: "production",
      BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
      BETTER_AUTH_SECRET: secret,
      DATABASE_URL: "postgres://identity:password@postgres/tazkle",
    }),
  );
});

test("identity pins the native redirect URI", () => {
  assert.throws(() =>
    identityConfigurationFromEnvironment({
      BETTER_AUTH_URL: "https://identity.tazkle.app/api/auth",
      BETTER_AUTH_SECRET: secret,
      DATABASE_URL: "postgres://identity:password@postgres/tazkle",
      TAZKLE_OIDC_REDIRECT_URI: "https://evil.example/callback",
    }),
  );
});

test("identity enables only social providers with a complete credential pair", () => {
  const configuration = identityConfigurationFromEnvironment({
    ALLOW_INSECURE_LOCAL_OIDC: "true",
    BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
    BETTER_AUTH_SECRET: secret,
    DATABASE_URL: "postgres://identity:password@postgres/tazkle",
    GOOGLE_CLIENT_ID: "google-client.apps.exampleusercontent.com",
    GOOGLE_CLIENT_SECRET: "google-client-secret",
    MICROSOFT_CLIENT_ID: "microsoft-client-id",
    MICROSOFT_CLIENT_SECRET: "microsoft-client-secret",
    MICROSOFT_TENANT_ID: "common",
  });

  assert.deepEqual(enabledSocialProviders(configuration), [
    "google",
    "microsoft",
  ]);
  assert.equal(
    configuration.socialProviders.microsoft?.tenantID,
    "common",
  );
});

test("identity refuses a partially configured social provider", () => {
  assert.throws(
    () =>
      identityConfigurationFromEnvironment({
        ALLOW_INSECURE_LOCAL_OIDC: "true",
        BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
        BETTER_AUTH_SECRET: secret,
        DATABASE_URL: "postgres://identity:password@postgres/tazkle",
        GOOGLE_CLIENT_ID: "google-client.apps.exampleusercontent.com",
      }),
    /Google OAuth requires both client ID and client secret/,
  );
});

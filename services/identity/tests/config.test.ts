import assert from "node:assert/strict";
import test from "node:test";
import {
  enabledSocialProviders,
  identityConfigurationFromEnvironment,
} from "../src/config.js";

const secret = "test-better-auth-secret-at-least-32-bytes";
const resendKey = "re_test_key_with_a_safe_nonproduction_value";

function environment(
  overrides: NodeJS.ProcessEnv = {},
): NodeJS.ProcessEnv {
  return {
    RESEND_API_KEY: resendKey,
    AUTH_EMAIL_FROM: "Tazkle <seguridad@example.com>",
    ...overrides,
  };
}

test("identity accepts an explicit loopback issuer outside production", () => {
  const configuration = identityConfigurationFromEnvironment(environment({
    NODE_ENV: "development",
    ALLOW_INSECURE_LOCAL_OIDC: "true",
    BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
    BETTER_AUTH_SECRET: secret,
    DATABASE_URL: "postgres://identity:password@postgres/tazkle",
  }));

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
  assert.equal(configuration.transactionalEmail.provider, "resend");
  assert.equal(
    configuration.transactionalEmail.from,
    "Tazkle <seguridad@example.com>",
  );
});

test("identity refuses non-loopback HTTP and HTTP in production", () => {
  assert.throws(() =>
    identityConfigurationFromEnvironment(environment({
      NODE_ENV: "development",
      ALLOW_INSECURE_LOCAL_OIDC: "true",
      BETTER_AUTH_URL: "http://identity.example.com/api/auth",
      BETTER_AUTH_SECRET: secret,
      DATABASE_URL: "postgres://identity:password@postgres/tazkle",
    })),
  );

  assert.throws(() =>
    identityConfigurationFromEnvironment(environment({
      NODE_ENV: "production",
      BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
      BETTER_AUTH_SECRET: secret,
      DATABASE_URL: "postgres://identity:password@postgres/tazkle",
    })),
  );
});

test("identity pins the native redirect URI", () => {
  assert.throws(() =>
    identityConfigurationFromEnvironment(environment({
      BETTER_AUTH_URL: "https://identity.tazkle.app/api/auth",
      BETTER_AUTH_SECRET: secret,
      DATABASE_URL: "postgres://identity:password@postgres/tazkle",
      TAZKLE_OIDC_REDIRECT_URI: "https://evil.example/callback",
    })),
  );
});

test("identity enables only social providers with a complete credential pair", () => {
  const configuration = identityConfigurationFromEnvironment(environment({
    ALLOW_INSECURE_LOCAL_OIDC: "true",
    BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
    BETTER_AUTH_SECRET: secret,
    DATABASE_URL: "postgres://identity:password@postgres/tazkle",
    GOOGLE_CLIENT_ID: "google-client.apps.exampleusercontent.com",
    GOOGLE_CLIENT_SECRET: "google-client-secret",
    MICROSOFT_CLIENT_ID: "microsoft-client-id",
    MICROSOFT_CLIENT_SECRET: "microsoft-client-secret",
    MICROSOFT_TENANT_ID: "common",
  }));

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
      identityConfigurationFromEnvironment(environment({
        ALLOW_INSECURE_LOCAL_OIDC: "true",
        BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
        BETTER_AUTH_SECRET: secret,
        DATABASE_URL: "postgres://identity:password@postgres/tazkle",
        GOOGLE_CLIENT_ID: "google-client.apps.exampleusercontent.com",
      })),
    /Google OAuth requires both client ID and client secret/,
  );
});

test("identity requires a bounded Resend key and a safe sender", () => {
  assert.throws(
    () =>
      identityConfigurationFromEnvironment({
        ALLOW_INSECURE_LOCAL_OIDC: "true",
        BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
        BETTER_AUTH_SECRET: secret,
        DATABASE_URL: "postgres://identity:password@postgres/tazkle",
        AUTH_EMAIL_FROM: "Tazkle <seguridad@example.com>",
      }),
    /Resend API key/,
  );

  assert.throws(
    () =>
      identityConfigurationFromEnvironment(environment({
        ALLOW_INSECURE_LOCAL_OIDC: "true",
        BETTER_AUTH_URL: "http://127.0.0.1:8787/api/auth",
        BETTER_AUTH_SECRET: secret,
        DATABASE_URL: "postgres://identity:password@postgres/tazkle",
        AUTH_EMAIL_FROM: "Tazkle\r\nBcc: attacker@example.com",
      })),
    /AUTH_EMAIL_FROM/,
  );
});

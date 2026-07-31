import assert from "node:assert/strict";
import { createHash, randomBytes } from "node:crypto";
import { createInterface } from "node:readline/promises";

const origin = process.env.TAZKLE_SMOKE_ORIGIN ?? "http://127.0.0.1:8787";
const issuer = `${origin}/api/auth`;
const clientID = "tazkle-macos";
const redirectURI = "app.tazkle.desktop:/oauth/callback";
const resource = "tazkle-local";
const email = process.env.TAZKLE_SMOKE_EMAIL;
if (!email) {
  throw new Error(
    "TAZKLE_SMOKE_EMAIL is required; use an address authorized by the configured email provider",
  );
}
const password =
  process.env.TAZKLE_SMOKE_PASSWORD ??
  `Smoke-${randomBytes(18).toString("base64url")}`;
const state = randomBytes(24).toString("base64url");
const verifier = randomBytes(64).toString("base64url");
const challenge = createHash("sha256")
  .update(verifier)
  .digest("base64url");
const cookieJar = new Map();

const authorizationServerMetadata = await checkedJSON(
  await fetch(
    `${origin}/.well-known/oauth-authorization-server/api/auth`,
    {
      headers: { Accept: "application/json" },
      redirect: "error",
    },
  ),
  200,
);
assert.equal(authorizationServerMetadata.issuer, issuer);

const discovery = await checkedJSON(
  await fetch(`${issuer}/.well-known/openid-configuration`, {
    headers: { Accept: "application/json" },
    redirect: "error",
  }),
  200,
);
assert.equal(discovery.issuer, issuer);

const authorizationURL = new URL(discovery.authorization_endpoint);
authorizationURL.search = new URLSearchParams({
  client_id: clientID,
  redirect_uri: redirectURI,
  response_type: "code",
  scope: "openid profile email offline_access",
  state,
  code_challenge: challenge,
  code_challenge_method: "S256",
  resource,
  prompt: "create",
}).toString();

const authorizationResponse = await request(authorizationURL, {
  headers: { Accept: "text/html" },
  redirect: "manual",
});
assert.equal(authorizationResponse.status, 302);
const signUpLocation = requiredLocation(authorizationResponse);
assert.equal(signUpLocation.pathname, "/sign-up");
const signedRequestIssuedAt = Number(signUpLocation.searchParams.get("ba_iat"));
const signedRequestExpiresAt = Number(signUpLocation.searchParams.get("exp"));
assert.equal(
  signedRequestExpiresAt - Math.floor(signedRequestIssuedAt / 1_000),
  10 * 60,
);
const oauthQuery = signUpLocation.search.slice(1);

const signUp = await request(`${origin}/api/auth/sign-up/email`, {
  method: "POST",
  headers: jsonHeaders(),
  body: JSON.stringify({
    name: "Tazkle Auth Smoke",
    email,
    password,
    rememberMe: true,
    oauth_query: oauthQuery,
  }),
});
const signUpPayload = await checkedJSON(signUp, 200);
assert.equal(signUpPayload.user.email, email);
assert.equal(signUpPayload.user.emailVerified, false);

await checkedJSON(
  await request(
    `${origin}/api/auth/email-otp/send-verification-otp`,
    {
      method: "POST",
      headers: jsonHeaders(),
      body: JSON.stringify({
        email,
        type: "email-verification",
      }),
    },
  ),
  200,
);

const emailOTP = await verificationCode(
  "TAZKLE_SMOKE_EMAIL_OTP",
  "Código de verificación enviado por correo: ",
);
const verification = await request(
  `${origin}/api/auth/email-otp/verify-email`,
  {
    method: "POST",
    headers: jsonHeaders(),
    body: JSON.stringify({
      email,
      otp: emailOTP,
    }),
  },
);
const verificationPayload = await checkedJSON(verification, 200);
assert.equal(verificationPayload.status, true);
assert.equal(verificationPayload.user.emailVerified, true);

const enableTwoFactor = await request(
  `${origin}/api/auth/two-factor/enable`,
  {
    method: "POST",
    headers: jsonHeaders(),
    body: JSON.stringify({
      password,
      issuer: "Tazkle",
    }),
  },
);
const enrollment = await checkedJSON(enableTwoFactor, 200);
assert.equal(enrollment.backupCodes.length, 8);

const continueSignUp = await request(`${origin}/api/auth/oauth2/continue`, {
  method: "POST",
  headers: jsonHeaders(),
  body: JSON.stringify({
    created: true,
    oauth_query: oauthQuery,
  }),
});
const continuePayload = await checkedJSON(continueSignUp, 200);
const consentLocation = new URL(continuePayload.url, origin);
assert.equal(consentLocation.pathname, "/consent");

const consent = await request(`${origin}/api/auth/oauth2/consent`, {
  method: "POST",
  headers: jsonHeaders(),
  body: JSON.stringify({
    accept: true,
    oauth_query: consentLocation.search.slice(1),
  }),
});
const consentPayload = await checkedJSON(consent, 200);
const callback = new URL(consentPayload.url);
assert.equal(callback.protocol, "app.tazkle.desktop:");
assert.equal(callback.searchParams.get("state"), state);
const code = callback.searchParams.get("code");
assert.ok(code);

const token = await checkedJSON(
  await fetch(discovery.token_endpoint, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      client_id: clientID,
      redirect_uri: redirectURI,
      code,
      code_verifier: verifier,
      resource,
    }),
  }),
  200,
);
assert.equal(token.token_type.toLowerCase(), "bearer");
assert.equal(token.access_token.split(".").length, 3);
assert.ok(token.refresh_token);

const userInfo = await checkedJSON(
  await fetch(discovery.userinfo_endpoint, {
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${token.access_token}`,
    },
  }),
  200,
);
assert.equal(userInfo.email, email);

const refreshed = await checkedJSON(
  await fetch(discovery.token_endpoint, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      client_id: clientID,
      refresh_token: token.refresh_token,
      resource,
    }),
  }),
  200,
);
assert.equal(refreshed.access_token.split(".").length, 3);

console.info(
  JSON.stringify({
    status: "ok",
    flow: "email-verification-2fa-enrollment-pkce-consent-token-userinfo-refresh",
    email: maskEmail(email),
    emailVerified: userInfo.email_verified === true,
  }),
);

async function verificationCode(environmentName, prompt) {
  const configured = process.env[environmentName]?.trim();
  if (configured) {
    assert.match(configured, /^\d{6}$/);
    return configured;
  }
  if (!process.stdin.isTTY) {
    throw new Error(
      `${environmentName} is required when stdin is not interactive`,
    );
  }
  const terminal = createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  try {
    const value = (await terminal.question(prompt)).trim();
    assert.match(value, /^\d{6}$/);
    return value;
  } finally {
    terminal.close();
  }
}

function maskEmail(value) {
  const [name, domain] = value.split("@");
  return `${name.slice(0, 2)}•••@${domain}`;
}

async function request(input, init) {
  const headers = new Headers(init?.headers);
  const cookie = [...cookieJar]
    .map(([name, value]) => `${name}=${value}`)
    .join("; ");
  if (cookie) {
    headers.set("Cookie", cookie);
  }
  const response = await fetch(input, {
    ...init,
    headers,
  });
  for (const setCookie of response.headers.getSetCookie()) {
    const pair = setCookie.split(";", 1)[0];
    const separator = pair.indexOf("=");
    if (separator > 0) {
      cookieJar.set(pair.slice(0, separator), pair.slice(separator + 1));
    }
  }
  return response;
}

function jsonHeaders() {
  return {
    Accept: "application/json",
    "Content-Type": "application/json",
    Origin: origin,
  };
}

async function checkedJSON(response, expectedStatus) {
  const payload = await response.json().catch(() => ({}));
  assert.equal(
    response.status,
    expectedStatus,
    `HTTP ${response.status}: ${JSON.stringify(payload)}`,
  );
  return payload;
}

function requiredLocation(response) {
  const value = response.headers.get("Location");
  assert.ok(value);
  return new URL(value, origin);
}

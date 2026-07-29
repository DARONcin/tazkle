import assert from "node:assert/strict";
import test from "node:test";
import {
  createLocalJWKSet,
  exportJWK,
  generateKeyPair,
  jwtVerify,
  SignJWT,
} from "jose";
import {
  AuthenticationError,
  createInternalActorSigner,
  createOIDCAccessTokenVerifier,
  oidcConfigurationFromEnvironment,
  readBearerToken,
} from "../src/authentication.js";

test("OIDC verifier validates signature issuer audience expiry and subject", async () => {
  const { privateKey, publicKey } = await generateKeyPair("ES256");
  const publicJWK = await exportJWK(publicKey);
  const keySet = createLocalJWKSet({
    keys: [{ ...publicJWK, alg: "ES256", kid: "test-key", use: "sig" }],
  });
  const verifier = createOIDCAccessTokenVerifier(
    {
      issuer: "https://identity.test",
      audience: "tazkle-tests",
      jwksURL: new URL("https://identity.test/jwks.json"),
    },
    keySet,
  );
  const token = await new SignJWT({ name: "Ana" })
    .setProtectedHeader({ alg: "ES256", kid: "test-key" })
    .setIssuer("https://identity.test")
    .setAudience("tazkle-tests")
    .setSubject("user-123")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(privateKey);

  assert.deepEqual(await verifier.verify(token), {
    issuer: "https://identity.test",
    subject: "user-123",
    displayName: "Ana",
  });
});

test("OIDC verifier rejects a token for another audience", async () => {
  const { privateKey, publicKey } = await generateKeyPair("ES256");
  const publicJWK = await exportJWK(publicKey);
  const verifier = createOIDCAccessTokenVerifier(
    {
      issuer: "https://identity.test",
      audience: "tazkle-tests",
      jwksURL: new URL("https://identity.test/jwks.json"),
    },
    createLocalJWKSet({
      keys: [{ ...publicJWK, alg: "ES256", kid: "test-key", use: "sig" }],
    }),
  );
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: "test-key" })
    .setIssuer("https://identity.test")
    .setAudience("another-application")
    .setSubject("user-123")
    .setExpirationTime("5m")
    .sign(privateKey);

  await assert.rejects(verifier.verify(token), AuthenticationError);
});

test("bearer parser accepts only compact signed JWTs", () => {
  assert.equal(
    readBearerToken("Bearer header.payload.signature"),
    "header.payload.signature",
  );
  assert.throws(
    () => readBearerToken("Bearer header.payload.signature extra"),
    AuthenticationError,
  );
  assert.throws(() => readBearerToken("Basic secret"), AuthenticationError);
});

test("OIDC configuration allows only an explicit local HTTP topology", () => {
  const local = oidcConfigurationFromEnvironment({
    OIDC_ISSUER: "http://127.0.0.1:8787/api/auth",
    OIDC_AUDIENCE: "tazkle-local",
    OIDC_JWKS_URL: "http://identity:8791/api/auth/jwks",
    ALLOW_INSECURE_LOCAL_OIDC: "true",
  });

  assert.equal(local.issuer, "http://127.0.0.1:8787/api/auth");
  assert.equal(local.jwksURL.hostname, "identity");
  assert.throws(() =>
    oidcConfigurationFromEnvironment({
      OIDC_ISSUER: "http://evil.example/api/auth",
      OIDC_AUDIENCE: "tazkle-local",
      OIDC_JWKS_URL: "http://evil.example/jwks",
      ALLOW_INSECURE_LOCAL_OIDC: "true",
    }),
  );
});

test("internal actor assertion is short lived and bound to Project Core", async () => {
  const secret = "test-secret-with-at-least-thirty-two-bytes";
  const signer = createInternalActorSigner(secret);
  const token = await signer.sign(
    {
      issuer: "https://identity.test",
      subject: "user-123",
      displayName: "Ana",
    },
    "550e8400-e29b-41d4-a716-446655440010",
  );
  const { payload } = await jwtVerify(
    token,
    new TextEncoder().encode(secret),
    {
      issuer: "tazkle-gateway",
      audience: "tazkle-project-core",
      algorithms: ["HS256"],
    },
  );

  assert.equal(payload.sub, "user-123");
  assert.equal(payload.identityIssuer, "https://identity.test");
  assert.equal(payload.jti, "550e8400-e29b-41d4-a716-446655440010");
  assert.ok((payload.exp ?? 0) - (payload.iat ?? 0) <= 30);
});

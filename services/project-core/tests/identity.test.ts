import assert from "node:assert/strict";
import test from "node:test";
import { SignJWT } from "jose";
import {
  createInternalActorVerifier,
  InternalAuthenticationError,
} from "../src/identity.js";

const secret = "test-secret-with-at-least-thirty-two-bytes";

test("Project Core verifies the Gateway actor assertion", async () => {
  const token = await new SignJWT({
    identityIssuer: "https://identity.test",
    displayName: "Ana",
    requestId: "550e8400-e29b-41d4-a716-446655440010",
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setIssuer("tazkle-gateway")
    .setAudience("tazkle-project-core")
    .setSubject("user-123")
    .setJti("550e8400-e29b-41d4-a716-446655440010")
    .setIssuedAt()
    .setExpirationTime("30s")
    .sign(new TextEncoder().encode(secret));

  assert.deepEqual(await createInternalActorVerifier(secret).verify(token), {
    identityIssuer: "https://identity.test",
    subject: "user-123",
    displayName: "Ana",
    requestId: "550e8400-e29b-41d4-a716-446655440010",
  });
});

test("Project Core rejects an assertion with a mismatched request identifier", async () => {
  const token = await new SignJWT({
    identityIssuer: "https://identity.test",
    requestId: "550e8400-e29b-41d4-a716-446655440010",
  })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuer("tazkle-gateway")
    .setAudience("tazkle-project-core")
    .setSubject("user-123")
    .setJti("550e8400-e29b-41d4-a716-446655440011")
    .setIssuedAt()
    .setExpirationTime("30s")
    .sign(new TextEncoder().encode(secret));

  await assert.rejects(
    createInternalActorVerifier(secret).verify(token),
    InternalAuthenticationError,
  );
});

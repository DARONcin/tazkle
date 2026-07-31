import assert from "node:assert/strict";
import test from "node:test";
import type { IdentityConfiguration } from "../src/config.js";
import { createAuthenticationEmailSender } from "../src/email.js";

const configuration = {
  transactionalEmail: {
    provider: "resend",
    apiKey: "re_test_key_that_never_leaves_the_unit_test",
    from: "Tazkle <seguridad@example.com>",
  },
} as IdentityConfiguration;

test("authentication email uses the pinned Resend endpoint without leaking the key", async () => {
  let observedURL = "";
  let observedAuthorization = "";
  let observedBody = "";

  const sender = createAuthenticationEmailSender(
    configuration,
    async (input, init) => {
      observedURL = String(input);
      observedAuthorization = new Headers(init?.headers).get("authorization") ?? "";
      observedBody = String(init?.body);
      return new Response(JSON.stringify({ id: "email-id" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    },
  );

  await sender.sendOTP({
    to: "persona@example.com",
    otp: "123456",
    kind: "two-factor",
  });

  assert.equal(observedURL, "https://api.resend.com/emails");
  assert.equal(
    observedAuthorization,
    "Bearer re_test_key_that_never_leaves_the_unit_test",
  );
  assert.doesNotMatch(observedBody, /re_test_key/);
  assert.match(observedBody, /persona@example\.com/);
  assert.match(observedBody, /123456/);
  assert.doesNotMatch(observedBody, /<script/i);
});

test("authentication email rejects malformed codes before external egress", async () => {
  let requested = false;
  const sender = createAuthenticationEmailSender(
    configuration,
    async () => {
      requested = true;
      return new Response(null, { status: 200 });
    },
  );

  await assert.rejects(
    sender.sendOTP({
      to: "persona@example.com",
      otp: "12ab56",
      kind: "email-verification",
    }),
    /code is invalid/,
  );
  assert.equal(requested, false);
});

test("authentication email exposes only a generic delivery failure", async () => {
  const sender = createAuthenticationEmailSender(
    configuration,
    async () =>
      new Response('{"message":"provider-sensitive-diagnostic"}', {
        status: 422,
      }),
  );

  await assert.rejects(
    sender.sendOTP({
      to: "persona@example.com",
      otp: "123456",
      kind: "email-verification",
    }),
    /^Error: Authentication email delivery failed$/,
  );
});

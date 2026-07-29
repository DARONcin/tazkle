import assert from "node:assert/strict";
import test from "node:test";
import {
  createProjectCommandSchema,
  createHealthResponse,
  errorEnvelopeSchema,
  healthResponseSchema,
  idempotencyKeySchema,
} from "../src/index.js";

test("health responses preserve explicit dependency degradation", () => {
  const response = createHealthResponse("project-core", [
    {
      name: "postgres",
      status: "unavailable",
      detail: "connection refused",
    },
  ]);

  assert.equal(response.status, "degraded");
  assert.equal(healthResponseSchema.parse(response).service, "project-core");
});

test("error envelopes reject request identifiers that are not UUIDs", () => {
  assert.throws(() => {
    errorEnvelopeSchema.parse({
      error: {
        code: "BAD_REQUEST",
        message: "Solicitud inválida.",
        requestId: "client-controlled-value",
      },
    });
  });
});

test("project creation rejects mass assignment fields", () => {
  assert.equal(
    createProjectCommandSchema.safeParse({
      name: "Portal",
      templateKey: "web-application",
      responsibleUserId: "550e8400-e29b-41d4-a716-446655440000",
    }).success,
    false,
  );
});

test("idempotency keys use a bounded header-safe alphabet", () => {
  assert.equal(
    idempotencyKeySchema.safeParse("project-create-0001").success,
    true,
  );
  assert.equal(idempotencyKeySchema.safeParse("short").success, false);
  assert.equal(
    idempotencyKeySchema.safeParse("project\r\nX-Evil: yes").success,
    false,
  );
});

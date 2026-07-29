import assert from "node:assert/strict";
import test from "node:test";
import { createProjectCoreApp } from "../src/app.js";
import {
  InternalAuthenticationError,
  type InternalActorVerifier,
} from "../src/identity.js";
import type { ProjectRepository } from "../src/projects.js";

const actor = {
  identityIssuer: "https://identity.test",
  subject: "user-123",
  displayName: "Ana",
  requestId: "550e8400-e29b-41d4-a716-446655440010",
};

const actorVerifier: InternalActorVerifier = {
  verify: async () => actor,
};

const projects: ProjectRepository = {
  create: async (_actor, command) => ({
    project: {
      id: "550e8400-e29b-41d4-a716-446655440000",
      organizationId: "550e8400-e29b-41d4-a716-446655440001",
      responsibleUserId: "550e8400-e29b-41d4-a716-446655440002",
      name: command.name,
      templateKey: command.templateKey,
      lifecycleStatus: "draft",
      rowVersion: 1,
      createdAt: "2026-07-28T18:00:00.000Z",
    },
    replayed: false,
  }),
  list: async () => [],
};

test("project core is the only service declaring domain-write authority", async () => {
  const app = createProjectCoreApp({
    databaseProbe: async () => [{ name: "postgres", status: "available" }],
    actorVerifier,
    projects,
  });

  const response = await app.request("/internal/capabilities");
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.service, "project-core");
  assert.equal(payload.writesDomain, true);
  assert.equal(payload.externalEgress, false);
});

test("project core readiness reflects database failure without exposing details", async () => {
  const app = createProjectCoreApp({
    databaseProbe: async () => [
      {
        name: "postgres",
        status: "unavailable",
        detail: "La base central no respondió.",
      },
    ],
    actorVerifier,
    projects,
  });

  const response = await app.request("/health/ready");
  const payload = await response.json();

  assert.equal(response.status, 503);
  assert.equal(payload.status, "degraded");
  assert.doesNotMatch(JSON.stringify(payload), /password|postgresql:\/\//i);
});

test("project core rejects a mutation without a signed internal actor", async () => {
  let repositoryCalls = 0;
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier: {
      verify: async () => {
        throw new InternalAuthenticationError();
      },
    },
    projects: {
      ...projects,
      create: async () => {
        repositoryCalls += 1;
        throw new Error("must not be called");
      },
    },
  });

  const response = await app.request("/internal/v1/projects", {
    method: "POST",
    headers: {
      Authorization: "Bearer internal.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "project-create-0001",
    },
    body: JSON.stringify({
      name: "Portal",
      templateKey: "web-application",
    }),
  });

  assert.equal(response.status, 401);
  assert.equal(repositoryCalls, 0);
});

test("project core creates a project from the narrow command contract", async () => {
  let receivedActor = "";
  let receivedKey = "";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects: {
      ...projects,
      create: async (verifiedActor, command, idempotencyKey) => {
        receivedActor = verifiedActor.subject;
        receivedKey = idempotencyKey;
        return projects.create(verifiedActor, command, idempotencyKey);
      },
    },
  });

  const response = await app.request("/internal/v1/projects", {
    method: "POST",
    headers: {
      Authorization: "Bearer internal.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "project-create-0001",
    },
    body: JSON.stringify({
      name: "Portal",
      templateKey: "web-application",
    }),
  });

  assert.equal(response.status, 201);
  assert.equal(receivedActor, "user-123");
  assert.equal(receivedKey, "project-create-0001");
  assert.equal((await response.json()).project.name, "Portal");
});

test("project core rejects mass assignment fields", async () => {
  let repositoryCalls = 0;
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects: {
      ...projects,
      create: async () => {
        repositoryCalls += 1;
        throw new Error("must not be called");
      },
    },
  });

  const response = await app.request("/internal/v1/projects", {
    method: "POST",
    headers: {
      Authorization: "Bearer internal.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "project-create-0001",
    },
    body: JSON.stringify({
      name: "Portal",
      templateKey: "web-application",
      organizationRole: "organization-admin",
    }),
  });

  assert.equal(response.status, 400);
  assert.equal(repositoryCalls, 0);
});

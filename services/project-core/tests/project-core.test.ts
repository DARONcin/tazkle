import assert from "node:assert/strict";
import test from "node:test";
import { createProjectCoreApp } from "../src/app.js";
import { ProjectOperationError } from "../src/errors.js";
import type { GraphRepository } from "../src/graph.js";
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

const projectId = "550e8400-e29b-41d4-a716-446655440000";

const actorVerifier: InternalActorVerifier = {
  verify: async () => actor,
};

const projects: ProjectRepository = {
  create: async (_actor, command) => ({
    project: {
      id: projectId,
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

const emptyGraph = { blocks: [], relations: [] };

const graph: GraphRepository = {
  get: async () => ({ graph: emptyGraph, rowVersion: 1, replayed: false }),
  replace: async (_actor, _projectId, command) => ({
    graph: command.graph,
    rowVersion: command.expectedRowVersion + 1,
    replayed: false,
  }),
};

test("project core is the only service declaring domain-write authority", async () => {
  const app = createProjectCoreApp({
    databaseProbe: async () => [{ name: "postgres", status: "available" }],
    actorVerifier,
    projects,
    graph,
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
    graph,
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
    graph,
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
    graph,
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
    graph,
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

test("project core reads the project graph", async () => {
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
  });

  const response = await app.request(
    `/internal/v1/projects/${projectId}/graph`,
    { headers: { Authorization: "Bearer internal.payload.signature" } },
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.deepEqual(payload.graph, emptyGraph);
  assert.equal(payload.rowVersion, 1);
});

test("project core rejects a malformed project id", async () => {
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
  });

  const response = await app.request(
    "/internal/v1/projects/not-a-uuid/graph",
    { headers: { Authorization: "Bearer internal.payload.signature" } },
  );

  assert.equal(response.status, 400);
});

test("project core replaces the project graph atomically", async () => {
  let receivedProjectId = "";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph: {
      ...graph,
      replace: async (verifiedActor, forProjectId, command) => {
        receivedProjectId = forProjectId;
        return graph.replace(verifiedActor, forProjectId, command, "irrelevant");
      },
    },
  });

  const blockId = "550e8400-e29b-41d4-a716-446655440003";
  const response = await app.request(
    `/internal/v1/projects/${projectId}/graph`,
    {
      method: "PUT",
      headers: {
        Authorization: "Bearer internal.payload.signature",
        "Content-Type": "application/json",
        "Idempotency-Key": "graph-replace-0001",
      },
      body: JSON.stringify({
        expectedRowVersion: 1,
        graph: {
          blocks: [
            {
              id: blockId,
              title: "API",
              summary: "",
              family: "technology",
              state: "draft",
              architectureLayer: "services",
              position: { x: 0, y: 0 },
              rowVersion: 1,
            },
          ],
          relations: [],
        },
      }),
    },
  );
  const payload = await response.json();

  assert.equal(response.status, 201);
  assert.equal(receivedProjectId, projectId);
  assert.equal(payload.rowVersion, 2);
  assert.equal(payload.graph.blocks[0].title, "API");
});

test("project core rejects a graph replace with a stale row version", async () => {
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph: {
      ...graph,
      replace: async () => {
        throw new ProjectOperationError(
          409,
          "WRITE_CONFLICT",
          "El proyecto cambió desde la última lectura. Actualiza antes de guardar.",
        );
      },
    },
  });

  const response = await app.request(
    `/internal/v1/projects/${projectId}/graph`,
    {
      method: "PUT",
      headers: {
        Authorization: "Bearer internal.payload.signature",
        "Content-Type": "application/json",
        "Idempotency-Key": "graph-replace-0002",
      },
      body: JSON.stringify({
        expectedRowVersion: 1,
        graph: emptyGraph,
      }),
    },
  );

  assert.equal(response.status, 409);
  assert.equal((await response.json()).error.code, "WRITE_CONFLICT");
});

test("project core rejects a graph replace with a self-relation", async () => {
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
  });

  const blockId = "550e8400-e29b-41d4-a716-446655440003";
  const response = await app.request(
    `/internal/v1/projects/${projectId}/graph`,
    {
      method: "PUT",
      headers: {
        Authorization: "Bearer internal.payload.signature",
        "Content-Type": "application/json",
        "Idempotency-Key": "graph-replace-0003",
      },
      body: JSON.stringify({
        expectedRowVersion: 1,
        graph: {
          blocks: [
            {
              id: blockId,
              title: "API",
              summary: "",
              family: "technology",
              state: "draft",
              architectureLayer: null,
              position: { x: 0, y: 0 },
              rowVersion: 1,
            },
          ],
          relations: [
            {
              id: "550e8400-e29b-41d4-a716-446655440004",
              sourceId: blockId,
              targetId: blockId,
              sourcePort: "right",
              targetPort: "left",
              type: "requires",
              isCritical: false,
              rowVersion: 1,
            },
          ],
        },
      }),
    },
  );

  assert.equal(response.status, 400);
});

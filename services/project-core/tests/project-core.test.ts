import assert from "node:assert/strict";
import test from "node:test";
import { createProjectCoreApp } from "../src/app.js";
import { ProjectOperationError } from "../src/errors.js";
import type { GraphRepository } from "../src/graph.js";
import {
  InternalAuthenticationError,
  type InternalActorVerifier,
} from "../src/identity.js";
import type { MemberRepository } from "../src/members.js";
import type { OrganizationPlanningRepository } from "../src/organization-planning.js";
import type { ProjectRepository } from "../src/projects.js";
import type { RoleRateRepository } from "../src/role-rates.js";

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

const members: MemberRepository = {
  list: async () => ({ members: [] }),
};

const roleRates: RoleRateRepository = {
  list: async () => ({ rates: [] }),
  upsert: async (_actor, command) => ({
    rate: {
      organizationId: command.organizationId,
      role: command.role,
      hourlyRateMXN: command.hourlyRateMXN,
      updatedAt: "2026-07-28T18:00:00.000Z",
    },
    replayed: false,
  }),
};

const organizationPlanning: OrganizationPlanningRepository = {
  get: async (_actor, organizationId) => ({
    organizationId,
    riskReservePercent: 10,
    targetMarginPercent: 20,
    workdayHours: 8,
    updatedAt: "2026-07-28T18:00:00.000Z",
  }),
  update: async (_actor, organizationId, command) => ({
    defaults: {
      organizationId,
      riskReservePercent: command.riskReservePercent,
      targetMarginPercent: command.targetMarginPercent,
      workdayHours: command.workdayHours,
      updatedAt: "2026-07-28T18:00:00.000Z",
    },
    replayed: false,
  }),
};

test("project core is the only service declaring domain-write authority", async () => {
  const app = createProjectCoreApp({
    databaseProbe: async () => [{ name: "postgres", status: "available" }],
    actorVerifier,
    projects,
    graph,
    members,
    roleRates,
    organizationPlanning,
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
    members,
    roleRates,
    organizationPlanning,
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
    members,
    roleRates,
    organizationPlanning,
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
    members,
    roleRates,
    organizationPlanning,
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
    members,
    roleRates,
    organizationPlanning,
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
    members,
    roleRates,
    organizationPlanning,
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
    members,
    roleRates,
    organizationPlanning,
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
    members,
    roleRates,
    organizationPlanning,
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
    members,
    roleRates,
    organizationPlanning,
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
    members,
    roleRates,
    organizationPlanning,
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

test("project core lists teammates across accessible organizations", async () => {
  const organizationId = "550e8400-e29b-41d4-a716-446655440005";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
    members: {
      list: async () => ({
        members: [
          {
            organizationId,
            userId: "550e8400-e29b-41d4-a716-446655440006",
            displayName: "Ana",
            role: "organization-admin",
            status: "active",
            createdAt: "2026-07-28T18:00:00.000Z",
          },
        ],
      }),
    },
    roleRates,
    organizationPlanning,
  });

  const response = await app.request("/internal/v1/members", {
    headers: { Authorization: "Bearer internal.payload.signature" },
  });
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.members.length, 1);
  assert.equal(payload.members[0].displayName, "Ana");
  assert.equal(payload.members[0].role, "organization-admin");
});

test("project core rejects a members list without a signed internal actor", async () => {
  let repositoryCalls = 0;
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier: {
      verify: async () => {
        throw new InternalAuthenticationError();
      },
    },
    projects,
    graph,
    members: {
      list: async () => {
        repositoryCalls += 1;
        throw new Error("must not be called");
      },
    },
    roleRates,
    organizationPlanning,
  });

  const response = await app.request("/internal/v1/members");

  assert.equal(response.status, 401);
  assert.equal(repositoryCalls, 0);
});

test("project core lists role rates across accessible organizations", async () => {
  const organizationId = "550e8400-e29b-41d4-a716-446655440005";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
    members,
    roleRates: {
      ...roleRates,
      list: async () => ({
        rates: [
          {
            organizationId,
            role: "development",
            hourlyRateMXN: 750,
            updatedAt: "2026-07-28T18:00:00.000Z",
          },
        ],
      }),
    },
    organizationPlanning,
  });

  const response = await app.request("/internal/v1/role-rates", {
    headers: { Authorization: "Bearer internal.payload.signature" },
  });
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.rates.length, 1);
  assert.equal(payload.rates[0].role, "development");
  assert.equal(payload.rates[0].hourlyRateMXN, 750);
});

test("project core upserts a role rate with a signed internal actor", async () => {
  const organizationId = "550e8400-e29b-41d4-a716-446655440005";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
    members,
    roleRates,
    organizationPlanning,
  });

  const response = await app.request("/internal/v1/role-rates", {
    method: "PUT",
    headers: {
      Authorization: "Bearer internal.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "role-rate-upsert-0000000000000001",
    },
    body: JSON.stringify({
      organizationId,
      role: "development",
      hourlyRateMXN: 750,
    }),
  });
  const payload = await response.json();

  assert.equal(response.status, 201);
  assert.equal(payload.rate.role, "development");
  assert.equal(payload.rate.hourlyRateMXN, 750);
  assert.equal(payload.replayed, false);
});

test("project core rejects a role rate upsert from a non-admin actor", async () => {
  const organizationId = "550e8400-e29b-41d4-a716-446655440005";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
    members,
    roleRates: {
      ...roleRates,
      upsert: async () => {
        throw new ProjectOperationError(
          403,
          "RATE_MANAGEMENT_FORBIDDEN",
          "Sólo un administrador de la organización puede capturar tarifas internas.",
        );
      },
    },
    organizationPlanning,
  });

  const response = await app.request("/internal/v1/role-rates", {
    method: "PUT",
    headers: {
      Authorization: "Bearer internal.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "role-rate-upsert-0000000000000002",
    },
    body: JSON.stringify({
      organizationId,
      role: "development",
      hourlyRateMXN: 750,
    }),
  });

  assert.equal(response.status, 403);
});

test("project core rejects a role rate upsert without a signed internal actor", async () => {
  let repositoryCalls = 0;
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier: {
      verify: async () => {
        throw new InternalAuthenticationError();
      },
    },
    projects,
    graph,
    members,
    roleRates: {
      ...roleRates,
      upsert: async () => {
        repositoryCalls += 1;
        throw new Error("must not be called");
      },
    },
    organizationPlanning,
  });

  const response = await app.request("/internal/v1/role-rates", {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      "Idempotency-Key": "role-rate-upsert-0000000000000003",
    },
    body: JSON.stringify({
      organizationId: "550e8400-e29b-41d4-a716-446655440005",
      role: "development",
      hourlyRateMXN: 750,
    }),
  });

  assert.equal(response.status, 401);
  assert.equal(repositoryCalls, 0);
});

test("project core reads organization planning defaults", async () => {
  const organizationId = "550e8400-e29b-41d4-a716-446655440005";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
    members,
    roleRates,
    organizationPlanning,
  });

  const response = await app.request(
    `/internal/v1/organizations/${organizationId}/planning-defaults`,
    { headers: { Authorization: "Bearer internal.payload.signature" } },
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.organizationId, organizationId);
  assert.equal(payload.riskReservePercent, 10);
  assert.equal(payload.targetMarginPercent, 20);
  assert.equal(payload.workdayHours, 8);
});

test("project core rejects a malformed organization id for planning defaults", async () => {
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
    members,
    roleRates,
    organizationPlanning,
  });

  const response = await app.request(
    "/internal/v1/organizations/not-a-uuid/planning-defaults",
    { headers: { Authorization: "Bearer internal.payload.signature" } },
  );

  assert.equal(response.status, 400);
});

test("project core updates organization planning defaults with a signed internal actor", async () => {
  const organizationId = "550e8400-e29b-41d4-a716-446655440005";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
    members,
    roleRates,
    organizationPlanning,
  });

  const response = await app.request(
    `/internal/v1/organizations/${organizationId}/planning-defaults`,
    {
      method: "PUT",
      headers: {
        Authorization: "Bearer internal.payload.signature",
        "Content-Type": "application/json",
        "Idempotency-Key": "planning-defaults-upsert-0000000000000001",
      },
      body: JSON.stringify({
        riskReservePercent: 15,
        targetMarginPercent: 25,
        workdayHours: 8,
      }),
    },
  );
  const payload = await response.json();

  assert.equal(response.status, 201);
  assert.equal(payload.defaults.riskReservePercent, 15);
  assert.equal(payload.defaults.targetMarginPercent, 25);
  assert.equal(payload.replayed, false);
});

test("project core rejects a planning defaults update from a non-admin actor", async () => {
  const organizationId = "550e8400-e29b-41d4-a716-446655440005";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier,
    projects,
    graph,
    members,
    roleRates,
    organizationPlanning: {
      ...organizationPlanning,
      update: async () => {
        throw new ProjectOperationError(
          403,
          "ORGANIZATION_SETTINGS_FORBIDDEN",
          "Sólo un administrador de la organización puede capturar estos valores.",
        );
      },
    },
  });

  const response = await app.request(
    `/internal/v1/organizations/${organizationId}/planning-defaults`,
    {
      method: "PUT",
      headers: {
        Authorization: "Bearer internal.payload.signature",
        "Content-Type": "application/json",
        "Idempotency-Key": "planning-defaults-upsert-0000000000000002",
      },
      body: JSON.stringify({
        riskReservePercent: 15,
        targetMarginPercent: 25,
        workdayHours: 8,
      }),
    },
  );

  assert.equal(response.status, 403);
});

test("project core rejects a planning defaults update without a signed internal actor", async () => {
  let repositoryCalls = 0;
  const organizationId = "550e8400-e29b-41d4-a716-446655440005";
  const app = createProjectCoreApp({
    databaseProbe: async () => [],
    actorVerifier: {
      verify: async () => {
        throw new InternalAuthenticationError();
      },
    },
    projects,
    graph,
    members,
    roleRates,
    organizationPlanning: {
      ...organizationPlanning,
      update: async () => {
        repositoryCalls += 1;
        throw new Error("must not be called");
      },
    },
  });

  const response = await app.request(
    `/internal/v1/organizations/${organizationId}/planning-defaults`,
    {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "Idempotency-Key": "planning-defaults-upsert-0000000000000003",
      },
      body: JSON.stringify({
        riskReservePercent: 15,
        targetMarginPercent: 25,
        workdayHours: 8,
      }),
    },
  );

  assert.equal(response.status, 401);
  assert.equal(repositoryCalls, 0);
});

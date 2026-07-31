import assert from "node:assert/strict";
import test from "node:test";
import { createHealthResponse } from "@tazkle/platform-contracts";
import { createGatewayApp } from "../src/app.js";
import {
  AuthenticationError,
  type AccessTokenVerifier,
  type InternalActorSigner,
} from "../src/authentication.js";

const urls = {
  identity: new URL("http://identity.test"),
  projectCore: new URL("http://project-core.test"),
  tazki: new URL("http://tazki.test"),
  automation: new URL("http://automation.test"),
};

const accessTokens: AccessTokenVerifier = {
  verify: async () => ({
    issuer: "https://identity.test",
    subject: "user-123",
    displayName: "Ana",
  }),
};
const internalActors: InternalActorSigner = {
  sign: async () => "internal.payload.signature",
};

test("gateway aggregates only allowlisted internal service capabilities", async () => {
  const fakeFetch: typeof fetch = async (input) => {
    const url = new URL(input.toString());
    const service = url.hostname.split(".")[0];
    if (url.pathname === "/internal/capabilities") {
      const body = {
        identity: {
          service: "identity",
          authority: "identity",
          writesDomain: false,
          externalEgress: false,
        },
        "project-core": {
          service: "project-core",
          authority: "domain",
          writesDomain: true,
          externalEgress: false,
        },
        tazki: {
          service: "tazki",
          authority: "proposal-only",
          writesDomain: false,
          externalEgress: true,
        },
        automation: {
          service: "automation",
          authority: "automation",
          writesDomain: false,
          externalEgress: false,
        },
      }[service];
      return Response.json(body);
    }
    return Response.json(
      createHealthResponse(
        service as "identity" | "project-core" | "tazki" | "automation",
      ),
    );
  };
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: fakeFetch,
  });

  const response = await app.request("/v1/platform/capabilities?target=http://evil.test");
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.services.length, 5);
  assert.deepEqual(
    payload.services.filter((service: { writesDomain: boolean }) => service.writesDomain)
      .map((service: { service: string }) => service.service),
    ["project-core"],
  );
});

test("gateway proxies only the fixed identity service and preserves auth cookies", async () => {
  let target = "";
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: async (input, init) => {
      target = input.toString();
      const headers = new Headers(init?.headers);
      assert.equal(headers.get("Authorization"), "Bearer access-token");
      assert.equal(headers.get("X-Parent-Request-ID")?.length, 36);
      assert.equal(headers.get("X-Tazkle-Client-IP"), null);
      return new Response(JSON.stringify({ issuer: "identity" }), {
        headers: {
          "Content-Type": "application/json",
          "Set-Cookie": "tazkle.session=value; HttpOnly; SameSite=Lax",
        },
      });
    },
  });

  const response = await app.request("/api/auth/.well-known/openid-configuration", {
    headers: {
      Accept: "application/json",
      Authorization: "Bearer access-token",
      "X-Tazkle-Client-IP": "203.0.113.42",
    },
  });

  assert.equal(
    target,
    "http://identity.test/api/auth/.well-known/openid-configuration",
  );
  assert.equal(response.status, 200);
  assert.match(response.headers.get("set-cookie") ?? "", /HttpOnly/);
});

test("gateway exposes only the allowlisted same-origin identity client scripts", async () => {
  let target = "";
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: async (input) => {
      target = input.toString();
      return new Response("console.log('identity');", {
        headers: {
          "Content-Type": "application/javascript; charset=utf-8",
        },
      });
    },
  });

  const response = await app.request("/identity/client/account.js");
  const missing = await app.request("/identity/client/unknown.js");

  assert.equal(target, "http://identity.test/identity/client/account.js");
  assert.equal(response.status, 200);
  assert.match(
    response.headers.get("content-type") ?? "",
    /application\/javascript/,
  );
  assert.equal(missing.status, 404);
});

test("gateway turns Better Auth browser navigation JSON into a bounded redirect", async () => {
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: async () => {
      return Response.json(
        {
          redirect: true,
          url: "/sign-in?client_id=tazkle-macos&sig=signed",
        },
        {
          headers: {
            "Set-Cookie":
              "tazkle.oauth_state=signed; HttpOnly; SameSite=Lax",
          },
        },
      );
    },
  });

  const response = await app.request("/api/auth/oauth2/authorize", {
    headers: {
      Accept: "text/html",
    },
  });

  assert.equal(response.status, 302);
  assert.equal(
    response.headers.get("location"),
    "/sign-in?client_id=tazkle-macos&sig=signed",
  );
  assert.match(
    response.headers.get("set-cookie") ?? "",
    /tazkle\.oauth_state=signed/,
  );
});

test("gateway refuses an identity open redirect", async () => {
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: async () => {
      return Response.json({
        redirect: true,
        url: "https://evil.example/steal-session",
      });
    },
  });

  const response = await app.request("/api/auth/oauth2/authorize", {
    headers: {
      Accept: "text/html",
    },
  });

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("location"), null);
});

test("gateway readiness becomes unavailable when an internal service fails", async () => {
  const fakeFetch: typeof fetch = async () => {
    throw new Error("connection refused");
  };
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: fakeFetch,
  });

  const response = await app.request("/health/ready");

  assert.equal(response.status, 503);
  assert.equal((await response.json()).status, "degraded");
});

test("gateway authenticates before parsing a project mutation", async () => {
  let internalCalls = 0;
  const app = createGatewayApp({
    urls,
    accessTokens: {
      verify: async () => {
        throw new AuthenticationError();
      },
    },
    internalActors,
    fetchImplementation: async () => {
      internalCalls += 1;
      throw new Error("must not be called");
    },
  });

  const response = await app.request("/v1/projects", {
    method: "POST",
    headers: {
      Accept: "application/json",
      Authorization: "Bearer header.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "project-create-0001",
    },
    body: "{not-json",
  });

  assert.equal(response.status, 401);
  assert.equal(internalCalls, 0);
  assert.equal((await response.json()).error.code, "UNAUTHORIZED");
});

test("gateway forwards a validated project command without the external token", async () => {
  let forwardedAuthorization = "";
  let forwardedBody = "";
  let forwardedIdempotencyKey = "";
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: async (input, init) => {
      const url = new URL(input.toString());
      assert.equal(url.hostname, "project-core.test");
      assert.equal(url.pathname, "/internal/v1/projects");
      const headers = new Headers(init?.headers);
      forwardedAuthorization = headers.get("Authorization") ?? "";
      forwardedIdempotencyKey = headers.get("Idempotency-Key") ?? "";
      forwardedBody = String(init?.body);
      return Response.json(
        {
          project: {
            id: "550e8400-e29b-41d4-a716-446655440000",
            organizationId: "550e8400-e29b-41d4-a716-446655440001",
            responsibleUserId: "550e8400-e29b-41d4-a716-446655440002",
            name: "Portal",
            templateKey: "web-application",
            lifecycleStatus: "draft",
            rowVersion: 1,
            createdAt: "2026-07-28T18:00:00.000Z",
          },
          replayed: false,
        },
        { status: 201 },
      );
    },
  });

  const response = await app.request("/v1/projects", {
    method: "POST",
    headers: {
      Accept: "application/json",
      Authorization: "Bearer external.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "project-create-0001",
    },
    body: JSON.stringify({
      name: "Portal",
      templateKey: "web-application",
    }),
  });

  assert.equal(response.status, 201);
  assert.equal(forwardedAuthorization, "Bearer internal.payload.signature");
  assert.equal(forwardedIdempotencyKey, "project-create-0001");
  assert.deepEqual(JSON.parse(forwardedBody), {
    name: "Portal",
    templateKey: "web-application",
  });
});

test("gateway rejects unknown project properties before Project Core", async () => {
  let internalCalls = 0;
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: async () => {
      internalCalls += 1;
      throw new Error("must not be called");
    },
  });

  const response = await app.request("/v1/projects", {
    method: "POST",
    headers: {
      Accept: "application/json",
      Authorization: "Bearer external.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "project-create-0001",
    },
    body: JSON.stringify({
      name: "Portal",
      templateKey: "web-application",
      responsibleUserId: "550e8400-e29b-41d4-a716-446655440099",
    }),
  });

  assert.equal(response.status, 400);
  assert.equal(internalCalls, 0);
});

const projectId = "550e8400-e29b-41d4-a716-446655440000";
const emptyGraph = { graph: { blocks: [], relations: [] }, rowVersion: 1, replayed: false };

test("gateway forwards a project graph read to the scoped project path", async () => {
  let target = "";
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: async (input) => {
      target = input.toString();
      return Response.json(emptyGraph);
    },
  });

  const response = await app.request(`/v1/projects/${projectId}/graph`, {
    headers: {
      Accept: "application/json",
      Authorization: "Bearer external.payload.signature",
    },
  });

  assert.equal(response.status, 200);
  assert.equal(
    target,
    `http://project-core.test/internal/v1/projects/${projectId}/graph`,
  );
  assert.deepEqual(await response.json(), emptyGraph);
});

test("gateway forwards a validated graph replace with its idempotency key", async () => {
  let forwardedIdempotencyKey = "";
  let forwardedBody = "";
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: async (input, init) => {
      const url = new URL(input.toString());
      assert.equal(url.pathname, `/internal/v1/projects/${projectId}/graph`);
      const headers = new Headers(init?.headers);
      forwardedIdempotencyKey = headers.get("Idempotency-Key") ?? "";
      forwardedBody = String(init?.body);
      return Response.json(
        { graph: { blocks: [], relations: [] }, rowVersion: 2, replayed: false },
        { status: 201 },
      );
    },
  });

  const command = {
    expectedRowVersion: 1,
    graph: { blocks: [], relations: [] },
  };

  const response = await app.request(`/v1/projects/${projectId}/graph`, {
    method: "PUT",
    headers: {
      Accept: "application/json",
      Authorization: "Bearer external.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "graph-replace-0001",
    },
    body: JSON.stringify(command),
  });

  assert.equal(response.status, 201);
  assert.equal(forwardedIdempotencyKey, "graph-replace-0001");
  assert.deepEqual(JSON.parse(forwardedBody), command);
});

test("gateway rejects a graph replace with a self-relation before Project Core", async () => {
  let internalCalls = 0;
  const app = createGatewayApp({
    urls,
    accessTokens,
    internalActors,
    fetchImplementation: async () => {
      internalCalls += 1;
      throw new Error("must not be called");
    },
  });

  const blockId = "550e8400-e29b-41d4-a716-446655440003";
  const response = await app.request(`/v1/projects/${projectId}/graph`, {
    method: "PUT",
    headers: {
      Accept: "application/json",
      Authorization: "Bearer external.payload.signature",
      "Content-Type": "application/json",
      "Idempotency-Key": "graph-replace-0002",
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
  });

  assert.equal(response.status, 400);
  assert.equal(internalCalls, 0);
});

import { createHmac, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";

const baseURL = process.env.PROJECT_CORE_URL ?? "http://127.0.0.1:8788";
const secret = process.env.INTERNAL_IDENTITY_SECRET_FILE
  ? readFileSync(process.env.INTERNAL_IDENTITY_SECRET_FILE, "utf8").replace(
      /\r?\n$/,
      "",
    )
  : process.env.INTERNAL_IDENTITY_SECRET;

if (!secret || Buffer.byteLength(secret, "utf8") < 32) {
  throw new Error("INTERNAL_IDENTITY_SECRET is required");
}

function signedActor(subject) {
  const requestId = randomUUID();
  const now = Math.floor(Date.now() / 1_000);
  const header = encode({ alg: "HS256", typ: "JWT" });
  const payload = encode({
    iss: "tazkle-gateway",
    aud: "tazkle-project-core",
    sub: subject,
    jti: requestId,
    iat: now,
    exp: now + 30,
    identityIssuer: "https://identity.invalid",
    requestId,
  });
  const unsigned = `${header}.${payload}`;
  const signature = createHmac("sha256", secret)
    .update(unsigned)
    .digest("base64url");
  return `${unsigned}.${signature}`;
}

async function request(subject, path, init = {}) {
  const response = await fetch(new URL(path, baseURL), {
    ...init,
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${signedActor(subject)}`,
      ...init.headers,
    },
  });
  const body = await response.json();
  return { response, body };
}

const createCommand = {
  name: "Proyecto de prueba de dominio",
  templateKey: "web-application",
};
const idempotencyKey = `domain-smoke-${randomUUID()}`;

const created = await request("domain-smoke-user-a", "/internal/v1/projects", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Idempotency-Key": idempotencyKey,
  },
  body: JSON.stringify(createCommand),
});
assert(created.response.status === 201, "first creation must return 201");
assert(created.body.replayed === false, "first creation must not be a replay");

const replayed = await request("domain-smoke-user-a", "/internal/v1/projects", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Idempotency-Key": idempotencyKey,
  },
  body: JSON.stringify(createCommand),
});
assert(replayed.response.status === 200, "idempotent replay must return 200");
assert(replayed.body.replayed === true, "second creation must be a replay");
assert(
  replayed.body.project.id === created.body.project.id,
  "idempotent replay must preserve the project",
);

const ownerList = await request(
  "domain-smoke-user-a",
  "/internal/v1/projects",
);
assert(ownerList.response.status === 200, "owner list must return 200");
assert(
  ownerList.body.projects.some(
    (project) => project.id === created.body.project.id,
  ),
  "owner must see the created project",
);

const otherList = await request(
  "domain-smoke-user-b",
  "/internal/v1/projects",
);
assert(otherList.response.status === 200, "other actor list must return 200");
assert(
  !otherList.body.projects.some(
    (project) => project.id === created.body.project.id,
  ),
  "another actor must not see the project",
);

const crossTenant = await request(
  "domain-smoke-user-b",
  "/internal/v1/projects",
  {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Idempotency-Key": `cross-tenant-${randomUUID()}`,
    },
    body: JSON.stringify({
      ...createCommand,
      organizationId: created.body.project.organizationId,
    }),
  },
);
assert(
  crossTenant.response.status === 403,
  "cross-organization creation must be forbidden",
);

console.info("project-domain-smoke: passed");

function encode(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { HTTP_HEADERS, MAX_JSON_BODY_BYTES } from "@tazkle/platform-contracts";
import { createServiceApp, readSecretValue } from "../src/index.js";

test("service boundary emits trusted request and security headers", async () => {
  const app = createServiceApp({ service: "gateway" });
  const response = await app.request("/health/live", {
    headers: {
      [HTTP_HEADERS.requestId]: "client-controlled",
    },
  });

  assert.equal(response.status, 200);
  assert.match(response.headers.get(HTTP_HEADERS.requestId) ?? "", /^[0-9a-f-]{36}$/);
  assert.notEqual(response.headers.get(HTTP_HEADERS.requestId), "client-controlled");
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
});

test("service boundary rejects oversized bodies before routing", async () => {
  const app = createServiceApp({ service: "gateway" });
  const response = await app.request("/missing", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": String(MAX_JSON_BODY_BYTES + 1),
    },
    body: "{}",
  });

  assert.equal(response.status, 413);
  assert.equal((await response.json()).error.code, "PAYLOAD_TOO_LARGE");
});

test("secret reader accepts a mounted file without its final newline", async () => {
  const directory = await mkdtemp(path.join(tmpdir(), "tazkle-secret-"));
  const secretPath = path.join(directory, "secret");
  try {
    await writeFile(secretPath, "mounted-secret-value\n", { mode: 0o600 });
    assert.equal(
      readSecretValue(undefined, secretPath, "Test secret"),
      "mounted-secret-value",
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("secret reader rejects ambiguous value and file configuration", () => {
  assert.throws(
    () => readSecretValue("value", "/tmp/secret", "Test secret"),
    /either a value or a file/,
  );
});

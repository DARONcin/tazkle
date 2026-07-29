import assert from "node:assert/strict";
import test from "node:test";
import { createAutomationApp } from "../src/app.js";

const successfulFetch: typeof fetch = async () => Response.json({ status: "ok" });

test("automation cannot write domain state directly", async () => {
  const app = createAutomationApp({
    projectCoreURL: new URL("http://project-core.test"),
    fetchImplementation: successfulFetch,
  });

  const response = await app.request("/internal/capabilities");
  const payload = await response.json();

  assert.equal(payload.authority, "automation");
  assert.equal(payload.writesDomain, false);
});

test("automation does not accept jobs before a queue is configured", async () => {
  const app = createAutomationApp({
    projectCoreURL: new URL("http://project-core.test"),
    fetchImplementation: successfulFetch,
  });

  const response = await app.request("/internal/jobs", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });

  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, "QUEUE_NOT_CONFIGURED");
});

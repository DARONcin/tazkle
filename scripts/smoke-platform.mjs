import assert from "node:assert/strict";

const gatewayURL = new URL(
  process.env.TAZKLE_GATEWAY_URL ?? "http://127.0.0.1:8787",
);

const readinessResponse = await fetch(new URL("/health/ready", gatewayURL), {
  headers: { Accept: "application/json" },
  redirect: "error",
  signal: AbortSignal.timeout(5_000),
});
assert.equal(readinessResponse.status, 200);
const readiness = await readinessResponse.json();
assert.equal(readiness.service, "gateway");
assert.equal(readiness.status, "ok");

const capabilitiesResponse = await fetch(
  new URL("/v1/platform/capabilities", gatewayURL),
  {
    headers: { Accept: "application/json" },
    redirect: "error",
    signal: AbortSignal.timeout(5_000),
  },
);
assert.equal(capabilitiesResponse.status, 200);
const capabilities = await capabilitiesResponse.json();
assert.equal(capabilities.services.length, 4);
assert.deepEqual(
  capabilities.services
    .filter((service) => service.writesDomain)
    .map((service) => service.service),
  ["project-core"],
);

console.info("platform-smoke: passed");

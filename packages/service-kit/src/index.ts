import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { serve } from "@hono/node-server";
import type { HttpBindings } from "@hono/node-server";
import {
  createHealthResponse,
  HTTP_HEADERS,
  MAX_JSON_BODY_BYTES,
  type DependencyStatus,
  type ErrorEnvelope,
  type ServiceName,
} from "@tazkle/platform-contracts";
import { Hono, type MiddlewareHandler } from "hono";
import { bodyLimit } from "hono/body-limit";

export type PlatformEnvironment = {
  Bindings: HttpBindings;
  Variables: {
    requestId: string;
  };
};

export type ReadinessProbe = () => Promise<DependencyStatus[]>;

type ServiceAppOptions = {
  service: ServiceName;
  readiness?: ReadinessProbe;
};

export function createServiceApp({
  service,
  readiness = async () => [],
}: ServiceAppOptions): Hono<PlatformEnvironment> {
  const app = new Hono<PlatformEnvironment>();

  app.use("*", requestBoundary());
  app.use(
    "*",
    bodyLimit({
      maxSize: MAX_JSON_BODY_BYTES,
      onError: (context) => {
        return context.json(
          createErrorEnvelope(
            "PAYLOAD_TOO_LARGE",
            "La petición supera el límite permitido.",
            context.get("requestId"),
          ),
          413,
        );
      },
    }),
  );

  app.get("/health/live", (context) => {
    return context.json(createHealthResponse(service));
  });

  app.get("/health/ready", async (context) => {
    const dependencies = await readiness();
    const health = createHealthResponse(service, dependencies);
    return context.json(health, health.status === "ok" ? 200 : 503);
  });

  app.onError((error, context) => {
    const requestId = context.get("requestId");
    console.error(
      JSON.stringify({
        level: "error",
        service,
        requestId,
        event: "unhandled_request_error",
        errorType: error.name,
      }),
    );
    return context.json(
      createErrorEnvelope(
        "INTERNAL_ERROR",
        "No se pudo completar la petición.",
        requestId,
      ),
      500,
    );
  });

  app.notFound((context) => {
    return context.json(
      createErrorEnvelope(
        "ROUTE_NOT_FOUND",
        "La ruta solicitada no existe.",
        context.get("requestId"),
      ),
      404,
    );
  });

  return app;
}

export function startService(
  app: Hono<PlatformEnvironment>,
  service: ServiceName,
): void {
  const port = parsePort(process.env.PORT);
  const server = serve({
    fetch: app.fetch,
    port,
  });

  console.info(
    JSON.stringify({
      level: "info",
      service,
      event: "service_started",
      port,
    }),
  );

  const shutdown = (signal: string): void => {
    console.info(
      JSON.stringify({
        level: "info",
        service,
        event: "service_stopping",
        signal,
      }),
    );
    server.close((error) => {
      process.exitCode = error ? 1 : 0;
    });
  };

  process.once("SIGINT", () => shutdown("SIGINT"));
  process.once("SIGTERM", () => shutdown("SIGTERM"));
}

export function requireInternalServiceURL(
  rawValue: string | undefined,
  variableName: string,
): URL {
  if (!rawValue) {
    throw new Error(`${variableName} is required`);
  }

  const url = new URL(rawValue);
  if (!["http:", "https:"].includes(url.protocol)) {
    throw new Error(`${variableName} must use http or https`);
  }
  if (url.username || url.password || url.search || url.hash) {
    throw new Error(`${variableName} must not include credentials, query, or fragment`);
  }
  return url;
}

export async function probeHTTPDependency(
  name: string,
  url: URL,
  fetchImplementation: typeof fetch = fetch,
): Promise<DependencyStatus> {
  try {
    const response = await fetchImplementation(url, {
      headers: {
        Accept: "application/json",
      },
      redirect: "error",
      signal: AbortSignal.timeout(2_000),
    });
    return {
      name,
      status: response.ok ? "available" : "unavailable",
      detail: response.ok ? undefined : `HTTP ${response.status}`,
    };
  } catch {
    return {
      name,
      status: "unavailable",
      detail: "No fue posible establecer conexión.",
    };
  }
}

export function readSecretValue(
  environmentValue: string | undefined,
  filePath: string | undefined,
  secretName: string,
): string {
  if (environmentValue && filePath) {
    throw new Error(`${secretName} must use either a value or a file, not both`);
  }

  let value = environmentValue;
  if (filePath) {
    value = readFileSync(filePath, "utf8").replace(/\r?\n$/, "");
  }

  if (!value || value.includes("\0") || Buffer.byteLength(value, "utf8") > 4_096) {
    throw new Error(`${secretName} is missing or invalid`);
  }
  return value;
}

function requestBoundary(): MiddlewareHandler<PlatformEnvironment> {
  return async (context, next) => {
    const requestId = randomUUID();
    context.set("requestId", requestId);

    await next();

    context.header(HTTP_HEADERS.requestId, requestId);
    context.header("Cache-Control", "no-store");
    context.header("X-Content-Type-Options", "nosniff");
    context.header("Referrer-Policy", "no-referrer");
    context.header("Permissions-Policy", "camera=(), microphone=(), geolocation=()");
  };
}

export function createErrorEnvelope(
  code: string,
  message: string,
  requestId: string,
): ErrorEnvelope {
  return {
    error: {
      code,
      message,
      requestId,
    },
  };
}

function parsePort(rawValue: string | undefined): number {
  const parsed = Number(rawValue ?? "8787");
  if (!Number.isInteger(parsed) || parsed < 1_024 || parsed > 65_535) {
    throw new Error("PORT must be an integer between 1024 and 65535");
  }
  return parsed;
}

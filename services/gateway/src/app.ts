import {
  createProjectCommandSchema,
  createProjectResponseSchema,
  errorEnvelopeSchema,
  HTTP_HEADERS,
  idempotencyKeySchema,
  membersListResponseSchema,
  organizationPlanningDefaultsSchema,
  platformCapabilitiesSchema,
  projectGraphResponseSchema,
  projectListResponseSchema,
  replaceProjectGraphCommandSchema,
  roleRatesListResponseSchema,
  serviceCapabilitySchema,
  updateOrganizationPlanningDefaultsCommandSchema,
  updateOrganizationPlanningDefaultsResponseSchema,
  upsertRoleRateCommandSchema,
  upsertRoleRateResponseSchema,
  type HealthResponse,
  type ServiceCapability,
} from "@tazkle/platform-contracts";
import {
  createErrorEnvelope,
  createServiceApp,
  probeHTTPDependency,
  requireInternalServiceURL,
} from "@tazkle/service-kit";
import type { Context } from "hono";
import { isIP } from "node:net";
import { ZodError, type ZodType } from "zod";
import {
  AuthenticationError,
  readBearerToken,
  type AccessTokenVerifier,
  type InternalActorSigner,
} from "./authentication.js";

type GatewayURLs = {
  identity: URL;
  projectCore: URL;
  tazki: URL;
  automation: URL;
};

type GatewayAppOptions = {
  urls: GatewayURLs;
  accessTokens: AccessTokenVerifier;
  internalActors: InternalActorSigner;
  fetchImplementation?: typeof fetch;
};

export function createGatewayApp({
  urls,
  accessTokens,
  internalActors,
  fetchImplementation = fetch,
}: GatewayAppOptions) {
  const services = [
    ["identity", urls.identity],
    ["project-core", urls.projectCore],
    ["tazki", urls.tazki],
    ["automation", urls.automation],
  ] as const;

  const app = createServiceApp({
    service: "gateway",
    readiness: async () => {
      return Promise.all(
        services.map(([name, url]) => {
          return probeHTTPDependency(
            name,
            new URL("/health/ready", url),
            fetchImplementation,
          );
        }),
      );
    },
  });

  app.get("/v1/platform/status", async (context) => {
    const health = await Promise.all(
      services.map(async ([name, url]): Promise<HealthResponse> => {
        const response = await fetchImplementation(new URL("/health/ready", url), {
          headers: { Accept: "application/json" },
          redirect: "error",
          signal: AbortSignal.timeout(2_000),
        });
        if (!response.ok && response.status !== 503) {
          throw new Error(`${name} returned an invalid status`);
        }
        return response.json() as Promise<HealthResponse>;
      }),
    );

    return context.json({
      status: health.some((service) => service.status === "degraded")
        ? "degraded"
        : "ok",
      services: health,
    });
  });

  app.get("/v1/platform/capabilities", async (context) => {
    const gatewayCapability: ServiceCapability = {
      service: "gateway",
      authority: "edge",
      writesDomain: false,
      externalEgress: false,
    };
    const internalCapabilities = await Promise.all(
      services.map(async ([name, url]) => {
        const response = await fetchImplementation(
          new URL("/internal/capabilities", url),
          {
            headers: { Accept: "application/json" },
            redirect: "error",
            signal: AbortSignal.timeout(2_000),
          },
        );
        if (!response.ok) {
          throw new Error(`${name} capabilities unavailable`);
        }
        return serviceCapabilitySchema.parse(await response.json());
      }),
    );

    return context.json(
      platformCapabilitiesSchema.parse({
        services: [gatewayCapability, ...internalCapabilities],
      }),
    );
  });

  app.on(["GET", "POST"], "/api/auth/*", (context) => {
    return proxyIdentityRequest(context, urls.identity, fetchImplementation);
  });

  app.get(
    "/.well-known/oauth-authorization-server/api/auth",
    (context) => proxyIdentityRequest(context, urls.identity, fetchImplementation),
  );

  for (const pagePath of [
    "/sign-in",
    "/sign-up",
    "/consent",
    "/account/delete",
    "/identity/client/account.js",
    "/identity/client/consent.js",
    "/identity/client/delete-account.js",
  ]) {
    app.get(pagePath, (context) => {
      return proxyIdentityRequest(context, urls.identity, fetchImplementation);
    });
  }

  app.get("/v1/projects", async (context) => {
    try {
      requireJSONAccept(context.req.header("Accept"));
      const internalToken = await authenticateAndSign(
        context,
        accessTokens,
        internalActors,
      );
      const response = await fetchInternal(
        new URL("/internal/v1/projects", urls.projectCore),
        {
          method: "GET",
          headers: internalHeaders(internalToken),
        },
        fetchImplementation,
      );
      return proxyProjectResponse(
        context,
        response,
        projectListResponseSchema,
      );
    } catch (error) {
      return gatewayOperationError(context, error);
    }
  });

  app.post("/v1/projects", async (context) => {
    try {
      requireJSONAccept(context.req.header("Accept"));
      requireJSONContentType(context.req.header("Content-Type"));
      const idempotencyKey = idempotencyKeySchema.parse(
        context.req.header(HTTP_HEADERS.idempotencyKey),
      );
      const internalToken = await authenticateAndSign(
        context,
        accessTokens,
        internalActors,
      );
      const command = createProjectCommandSchema.parse(await context.req.json());
      const response = await fetchInternal(
        new URL("/internal/v1/projects", urls.projectCore),
        {
          method: "POST",
          headers: {
            ...internalHeaders(internalToken),
            "Content-Type": "application/json",
            [HTTP_HEADERS.idempotencyKey]: idempotencyKey,
          },
          body: JSON.stringify(command),
        },
        fetchImplementation,
      );
      return proxyProjectResponse(
        context,
        response,
        createProjectResponseSchema,
      );
    } catch (error) {
      return gatewayOperationError(context, error);
    }
  });

  app.get("/v1/projects/:projectId/graph", async (context) => {
    try {
      requireJSONAccept(context.req.header("Accept"));
      const internalToken = await authenticateAndSign(
        context,
        accessTokens,
        internalActors,
      );
      const response = await fetchInternal(
        new URL(
          `/internal/v1/projects/${context.req.param("projectId")}/graph`,
          urls.projectCore,
        ),
        {
          method: "GET",
          headers: internalHeaders(internalToken),
        },
        fetchImplementation,
      );
      return proxyProjectResponse(context, response, projectGraphResponseSchema);
    } catch (error) {
      return gatewayOperationError(context, error);
    }
  });

  app.put("/v1/projects/:projectId/graph", async (context) => {
    try {
      requireJSONAccept(context.req.header("Accept"));
      requireJSONContentType(context.req.header("Content-Type"));
      const idempotencyKey = idempotencyKeySchema.parse(
        context.req.header(HTTP_HEADERS.idempotencyKey),
      );
      const internalToken = await authenticateAndSign(
        context,
        accessTokens,
        internalActors,
      );
      const command = replaceProjectGraphCommandSchema.parse(
        await context.req.json(),
      );
      const response = await fetchInternal(
        new URL(
          `/internal/v1/projects/${context.req.param("projectId")}/graph`,
          urls.projectCore,
        ),
        {
          method: "PUT",
          headers: {
            ...internalHeaders(internalToken),
            "Content-Type": "application/json",
            [HTTP_HEADERS.idempotencyKey]: idempotencyKey,
          },
          body: JSON.stringify(command),
        },
        fetchImplementation,
      );
      return proxyProjectResponse(context, response, projectGraphResponseSchema);
    } catch (error) {
      return gatewayOperationError(context, error);
    }
  });

  app.get("/v1/members", async (context) => {
    try {
      requireJSONAccept(context.req.header("Accept"));
      const internalToken = await authenticateAndSign(
        context,
        accessTokens,
        internalActors,
      );
      const response = await fetchInternal(
        new URL("/internal/v1/members", urls.projectCore),
        {
          method: "GET",
          headers: internalHeaders(internalToken),
        },
        fetchImplementation,
      );
      return proxyProjectResponse(context, response, membersListResponseSchema);
    } catch (error) {
      return gatewayOperationError(context, error);
    }
  });

  app.get("/v1/role-rates", async (context) => {
    try {
      requireJSONAccept(context.req.header("Accept"));
      const internalToken = await authenticateAndSign(
        context,
        accessTokens,
        internalActors,
      );
      const response = await fetchInternal(
        new URL("/internal/v1/role-rates", urls.projectCore),
        {
          method: "GET",
          headers: internalHeaders(internalToken),
        },
        fetchImplementation,
      );
      return proxyProjectResponse(context, response, roleRatesListResponseSchema);
    } catch (error) {
      return gatewayOperationError(context, error);
    }
  });

  app.put("/v1/role-rates", async (context) => {
    try {
      requireJSONAccept(context.req.header("Accept"));
      requireJSONContentType(context.req.header("Content-Type"));
      const idempotencyKey = idempotencyKeySchema.parse(
        context.req.header(HTTP_HEADERS.idempotencyKey),
      );
      const internalToken = await authenticateAndSign(
        context,
        accessTokens,
        internalActors,
      );
      const command = upsertRoleRateCommandSchema.parse(
        await context.req.json(),
      );
      const response = await fetchInternal(
        new URL("/internal/v1/role-rates", urls.projectCore),
        {
          method: "PUT",
          headers: {
            ...internalHeaders(internalToken),
            "Content-Type": "application/json",
            [HTTP_HEADERS.idempotencyKey]: idempotencyKey,
          },
          body: JSON.stringify(command),
        },
        fetchImplementation,
      );
      return proxyProjectResponse(context, response, upsertRoleRateResponseSchema);
    } catch (error) {
      return gatewayOperationError(context, error);
    }
  });

  app.get(
    "/v1/organizations/:organizationId/planning-defaults",
    async (context) => {
      try {
        requireJSONAccept(context.req.header("Accept"));
        const internalToken = await authenticateAndSign(
          context,
          accessTokens,
          internalActors,
        );
        const response = await fetchInternal(
          new URL(
            `/internal/v1/organizations/${context.req.param("organizationId")}/planning-defaults`,
            urls.projectCore,
          ),
          {
            method: "GET",
            headers: internalHeaders(internalToken),
          },
          fetchImplementation,
        );
        return proxyProjectResponse(
          context,
          response,
          organizationPlanningDefaultsSchema,
        );
      } catch (error) {
        return gatewayOperationError(context, error);
      }
    },
  );

  app.put(
    "/v1/organizations/:organizationId/planning-defaults",
    async (context) => {
      try {
        requireJSONAccept(context.req.header("Accept"));
        requireJSONContentType(context.req.header("Content-Type"));
        const idempotencyKey = idempotencyKeySchema.parse(
          context.req.header(HTTP_HEADERS.idempotencyKey),
        );
        const internalToken = await authenticateAndSign(
          context,
          accessTokens,
          internalActors,
        );
        const command = updateOrganizationPlanningDefaultsCommandSchema.parse(
          await context.req.json(),
        );
        const response = await fetchInternal(
          new URL(
            `/internal/v1/organizations/${context.req.param("organizationId")}/planning-defaults`,
            urls.projectCore,
          ),
          {
            method: "PUT",
            headers: {
              ...internalHeaders(internalToken),
              "Content-Type": "application/json",
              [HTTP_HEADERS.idempotencyKey]: idempotencyKey,
            },
            body: JSON.stringify(command),
          },
          fetchImplementation,
        );
        return proxyProjectResponse(
          context,
          response,
          updateOrganizationPlanningDefaultsResponseSchema,
        );
      } catch (error) {
        return gatewayOperationError(context, error);
      }
    },
  );

  return app;
}

export function gatewayURLsFromEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): GatewayURLs {
  return {
    identity: requireInternalServiceURL(
      environment.IDENTITY_URL,
      "IDENTITY_URL",
    ),
    projectCore: requireInternalServiceURL(
      environment.PROJECT_CORE_URL,
      "PROJECT_CORE_URL",
    ),
    tazki: requireInternalServiceURL(environment.TAZKI_URL, "TAZKI_URL"),
    automation: requireInternalServiceURL(
      environment.AUTOMATION_URL,
      "AUTOMATION_URL",
    ),
  };
}

async function proxyIdentityRequest(
  context: Context,
  identityURL: URL,
  fetchImplementation: typeof fetch,
): Promise<Response> {
  const incomingURL = new URL(context.req.url);
  const targetURL = new URL(
    `${incomingURL.pathname}${incomingURL.search}`,
    identityURL,
  );
  const headers = new Headers();
  for (const name of [
    "Accept",
    "Authorization",
    "Content-Type",
    "Cookie",
    "Origin",
    "User-Agent",
    "Sec-Fetch-Dest",
    "Sec-Fetch-Mode",
    "Sec-Fetch-Site",
  ]) {
    const value = context.req.header(name);
    if (value) {
      headers.set(name, value);
    }
  }
  headers.set(HTTP_HEADERS.parentRequestId, context.get("requestId") as string);
  const clientIP = directClientIPAddress(context);
  if (clientIP) {
    headers.set(HTTP_HEADERS.trustedClientIp, clientIP);
  }

  let response: Response;
  try {
    response = await fetchImplementation(targetURL, {
      method: context.req.method,
      headers,
      ...(context.req.method === "GET"
        ? {}
        : { body: await context.req.arrayBuffer() }),
      redirect: "manual",
      signal: AbortSignal.timeout(10_000),
    });
  } catch {
    return context.json(
      createErrorEnvelope(
        "IDENTITY_UNAVAILABLE",
        "El servicio de acceso no está disponible.",
        context.get("requestId") as string,
      ),
      503,
    );
  }

  const browserRedirect = await identityBrowserRedirect(context, response);
  if (browserRedirect) {
    return browserRedirect;
  }

  const responseHeaders = new Headers();
  for (const name of [
    "Cache-Control",
    "Content-Language",
    "Content-Security-Policy",
    "Content-Type",
    "Cross-Origin-Opener-Policy",
    "Cross-Origin-Resource-Policy",
    "Location",
    "Referrer-Policy",
    "X-Content-Type-Options",
    "X-Frame-Options",
  ]) {
    const value = response.headers.get(name);
    if (value) {
      responseHeaders.set(name, value);
    }
  }
  for (const cookie of response.headers.getSetCookie()) {
    responseHeaders.append("Set-Cookie", cookie);
  }

  return new Response(response.body, {
    status: response.status,
    headers: responseHeaders,
  });
}

function directClientIPAddress(context: Context): string | undefined {
  const environment = context.env as
    | {
        incoming?: {
          socket?: {
            remoteAddress?: string;
          };
        };
      }
    | undefined;
  const candidate = environment?.incoming?.socket?.remoteAddress?.trim();
  if (!candidate || isIP(candidate) === 0) {
    return undefined;
  }
  return candidate;
}

async function identityBrowserRedirect(
  context: Context,
  response: Response,
): Promise<Response | undefined> {
  const acceptsHTML = context.req.header("Accept")?.includes("text/html") ?? false;
  if (
    context.req.method !== "GET" ||
    !acceptsHTML ||
    response.status !== 200 ||
    !response.headers.get("Content-Type")?.includes("application/json")
  ) {
    return undefined;
  }

  let payload: unknown;
  try {
    payload = await response.clone().json();
  } catch {
    return undefined;
  }
  if (
    !payload ||
    typeof payload !== "object" ||
    !("redirect" in payload) ||
    payload.redirect !== true ||
    !("url" in payload) ||
    typeof payload.url !== "string"
  ) {
    return undefined;
  }

  const location = safeIdentityRedirect(payload.url, new URL(context.req.url));
  if (!location) {
    return undefined;
  }
  const headers = new Headers({
    Location: location,
    "Cache-Control": "no-store",
  });
  for (const cookie of response.headers.getSetCookie()) {
    headers.append("Set-Cookie", cookie);
  }
  return new Response(null, {
    status: 302,
    headers,
  });
}

function safeIdentityRedirect(
  rawLocation: string,
  requestURL: URL,
): string | undefined {
  if (rawLocation.startsWith("/")) {
    const target = new URL(rawLocation, requestURL);
    if (
      target.origin === requestURL.origin &&
      ["/sign-in", "/sign-up", "/consent"].includes(target.pathname)
    ) {
      return `${target.pathname}${target.search}`;
    }
    return undefined;
  }

  try {
    const target = new URL(rawLocation);
    if (
      target.protocol === "app.tazkle.desktop:" &&
      !target.host &&
      target.pathname === "/oauth/callback" &&
      !target.hash
    ) {
      return target.toString();
    }
  } catch {
    return undefined;
  }
  return undefined;
}

async function authenticateAndSign(
  context: Context,
  accessTokens: AccessTokenVerifier,
  internalActors: InternalActorSigner,
): Promise<string> {
  try {
    const token = readBearerToken(context.req.header("Authorization"));
    const actor = await accessTokens.verify(token);
    return internalActors.sign(actor, context.get("requestId") as string);
  } catch {
    throw new AuthenticationError();
  }
}

function internalHeaders(internalToken: string): Record<string, string> {
  return {
    Accept: "application/json",
    Authorization: `Bearer ${internalToken}`,
  };
}

async function fetchInternal(
  url: URL,
  init: RequestInit,
  fetchImplementation: typeof fetch,
): Promise<Response> {
  try {
    return await fetchImplementation(url, {
      ...init,
      redirect: "error",
      signal: AbortSignal.timeout(5_000),
    });
  } catch {
    throw new GatewayRequestError(
      503,
      "PROJECT_CORE_UNAVAILABLE",
      "El servicio de proyectos no está disponible.",
    );
  }
}

async function proxyProjectResponse(
  context: Context,
  response: Response,
  successSchema: ZodType,
): Promise<Response> {
  const requestId = context.get("requestId") as string;
  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    throw new GatewayRequestError(
      503,
      "INVALID_INTERNAL_RESPONSE",
      "El servicio de proyectos devolvió una respuesta inválida.",
    );
  }

  if (!response.ok) {
    const internalError = errorEnvelopeSchema.safeParse(payload);
    if (!internalError.success) {
      throw new GatewayRequestError(
        503,
        "INVALID_INTERNAL_RESPONSE",
        "El servicio de proyectos devolvió una respuesta inválida.",
      );
    }
    return context.json(
      createErrorEnvelope(
        internalError.data.error.code,
        internalError.data.error.message,
        requestId,
      ),
      normalizeInternalStatus(response.status),
    );
  }

  const parsed = successSchema.safeParse(payload);
  if (!parsed.success) {
    throw new GatewayRequestError(
      503,
      "INVALID_INTERNAL_RESPONSE",
      "El servicio de proyectos devolvió una respuesta inválida.",
    );
  }
  return context.json(parsed.data, response.status === 201 ? 201 : 200);
}

function requireJSONAccept(accept: string | undefined): void {
  if (
    accept &&
    !accept.includes("application/json") &&
    !accept.includes("*/*")
  ) {
    throw new GatewayRequestError(
      406,
      "NOT_ACCEPTABLE",
      "La API solamente produce application/json.",
    );
  }
}

function requireJSONContentType(contentType: string | undefined): void {
  if (!contentType || !/^application\/json(?:\s*;|$)/i.test(contentType)) {
    throw new GatewayRequestError(
      415,
      "UNSUPPORTED_MEDIA_TYPE",
      "La petición debe utilizar application/json.",
    );
  }
}

function gatewayOperationError(context: Context, error: unknown): Response {
  const requestId = context.get("requestId") as string;
  if (error instanceof AuthenticationError) {
    return context.json(
      createErrorEnvelope(
        "UNAUTHORIZED",
        "La sesión no es válida o ha expirado.",
        requestId,
      ),
      401,
    );
  }
  if (error instanceof GatewayRequestError) {
    return context.json(
      createErrorEnvelope(error.code, error.message, requestId),
      error.status,
    );
  }
  if (error instanceof ZodError || error instanceof SyntaxError) {
    return context.json(
      createErrorEnvelope(
        "INVALID_REQUEST",
        "La petición no cumple el contrato esperado.",
        requestId,
      ),
      400,
    );
  }
  throw error;
}

class GatewayRequestError extends Error {
  constructor(
    readonly status: 406 | 415 | 503,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "GatewayRequestError";
  }
}

function normalizeInternalStatus(
  status: number,
): 400 | 401 | 403 | 409 | 415 | 422 | 503 {
  if ([400, 401, 403, 409, 415, 422, 503].includes(status)) {
    return status as 400 | 401 | 403 | 409 | 415 | 422 | 503;
  }
  return 503;
}

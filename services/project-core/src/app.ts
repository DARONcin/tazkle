import {
  createProjectCommandSchema,
  idempotencyKeySchema,
  projectListResponseSchema,
  type DependencyStatus,
  type InternalActorClaims,
} from "@tazkle/platform-contracts";
import {
  createErrorEnvelope,
  createServiceApp,
} from "@tazkle/service-kit";
import type { Context } from "hono";
import { ZodError } from "zod";
import {
  InternalAuthenticationError,
  readInternalBearerToken,
  type InternalActorVerifier,
} from "./identity.js";
import {
  ProjectOperationError,
  type ProjectRepository,
} from "./projects.js";

type ProjectCoreAppOptions = {
  databaseProbe: () => Promise<DependencyStatus[]>;
  actorVerifier: InternalActorVerifier;
  projects: ProjectRepository;
};

export function createProjectCoreApp({
  databaseProbe,
  actorVerifier,
  projects,
}: ProjectCoreAppOptions) {
  const app = createServiceApp({
    service: "project-core",
    readiness: databaseProbe,
  });

  app.get("/internal/capabilities", (context) => {
    return context.json({
      service: "project-core",
      authority: "domain",
      writesDomain: true,
      externalEgress: false,
    });
  });

  app.get("/internal/v1/projects", async (context) => {
    try {
      const actor = await authenticateInternalRequest(context, actorVerifier);
      return context.json(
        projectListResponseSchema.parse({
          projects: await projects.list(actor),
        }),
      );
    } catch (error) {
      return operationErrorResponse(context, error);
    }
  });

  app.post("/internal/v1/projects", async (context) => {
    try {
      requireJSONContentType(context.req.header("Content-Type"));
      const actor = await authenticateInternalRequest(context, actorVerifier);
      const idempotencyKey = idempotencyKeySchema.parse(
        context.req.header("Idempotency-Key"),
      );
      const command = createProjectCommandSchema.parse(await context.req.json());
      const response = await projects.create(
        actor,
        command,
        idempotencyKey,
      );
      return context.json(response, response.replayed ? 200 : 201);
    } catch (error) {
      return operationErrorResponse(context, error);
    }
  });

  return app;
}

async function authenticateInternalRequest(
  context: Context,
  verifier: InternalActorVerifier,
): Promise<InternalActorClaims> {
  const token = readInternalBearerToken(context.req.header("Authorization"));
  return verifier.verify(token);
}

function requireJSONContentType(contentType: string | undefined): void {
  if (!contentType || !/^application\/json(?:\s*;|$)/i.test(contentType)) {
    throw new RequestValidationError(
      415,
      "UNSUPPORTED_MEDIA_TYPE",
      "La petición debe utilizar application/json.",
    );
  }
}

function operationErrorResponse(context: Context, error: unknown): Response {
  const requestId = context.get("requestId") as string;

  if (error instanceof InternalAuthenticationError) {
    return context.json(
      createErrorEnvelope(
        "UNAUTHORIZED",
        "La identidad interna no es válida.",
        requestId,
      ),
      401,
    );
  }
  if (error instanceof ProjectOperationError) {
    return context.json(
      createErrorEnvelope(error.code, error.message, requestId),
      error.status,
    );
  }
  if (error instanceof RequestValidationError) {
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

class RequestValidationError extends Error {
  constructor(
    readonly status: 415,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "RequestValidationError";
  }
}

import {
  createProjectCommandSchema,
  idempotencyKeySchema,
  membersListResponseSchema,
  organizationPlanningDefaultsSchema,
  projectListResponseSchema,
  replaceProjectGraphCommandSchema,
  roleRatesListResponseSchema,
  updateOrganizationPlanningDefaultsCommandSchema,
  upsertRoleRateCommandSchema,
  type DependencyStatus,
  type InternalActorClaims,
} from "@tazkle/platform-contracts";
import {
  createErrorEnvelope,
  createServiceApp,
} from "@tazkle/service-kit";
import type { Context } from "hono";
import { ZodError } from "zod";
import { ProjectOperationError } from "./errors.js";
import type { GraphRepository } from "./graph.js";
import {
  InternalAuthenticationError,
  readInternalBearerToken,
  type InternalActorVerifier,
} from "./identity.js";
import type { MemberRepository } from "./members.js";
import type { OrganizationPlanningRepository } from "./organization-planning.js";
import type { ProjectRepository } from "./projects.js";
import type { RoleRateRepository } from "./role-rates.js";

const projectIdParamSchema = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const organizationIdParamSchema = projectIdParamSchema;

type ProjectCoreAppOptions = {
  databaseProbe: () => Promise<DependencyStatus[]>;
  actorVerifier: InternalActorVerifier;
  projects: ProjectRepository;
  graph: GraphRepository;
  members: MemberRepository;
  roleRates: RoleRateRepository;
  organizationPlanning: OrganizationPlanningRepository;
};

export function createProjectCoreApp({
  databaseProbe,
  actorVerifier,
  projects,
  graph,
  members,
  roleRates,
  organizationPlanning,
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

  app.get("/internal/v1/projects/:projectId/graph", async (context) => {
    try {
      const actor = await authenticateInternalRequest(context, actorVerifier);
      const projectId = requireProjectId(context.req.param("projectId"));
      const response = await graph.get(actor, projectId);
      return context.json(response);
    } catch (error) {
      return operationErrorResponse(context, error);
    }
  });

  app.put("/internal/v1/projects/:projectId/graph", async (context) => {
    try {
      requireJSONContentType(context.req.header("Content-Type"));
      const actor = await authenticateInternalRequest(context, actorVerifier);
      const projectId = requireProjectId(context.req.param("projectId"));
      const idempotencyKey = idempotencyKeySchema.parse(
        context.req.header("Idempotency-Key"),
      );
      const command = replaceProjectGraphCommandSchema.parse(
        await context.req.json(),
      );
      const response = await graph.replace(
        actor,
        projectId,
        command,
        idempotencyKey,
      );
      return context.json(response, response.replayed ? 200 : 201);
    } catch (error) {
      return operationErrorResponse(context, error);
    }
  });

  app.get("/internal/v1/members", async (context) => {
    try {
      const actor = await authenticateInternalRequest(context, actorVerifier);
      const response = await members.list(actor);
      return context.json(membersListResponseSchema.parse(response));
    } catch (error) {
      return operationErrorResponse(context, error);
    }
  });

  app.get("/internal/v1/role-rates", async (context) => {
    try {
      const actor = await authenticateInternalRequest(context, actorVerifier);
      const response = await roleRates.list(actor);
      return context.json(roleRatesListResponseSchema.parse(response));
    } catch (error) {
      return operationErrorResponse(context, error);
    }
  });

  app.put("/internal/v1/role-rates", async (context) => {
    try {
      requireJSONContentType(context.req.header("Content-Type"));
      const actor = await authenticateInternalRequest(context, actorVerifier);
      const idempotencyKey = idempotencyKeySchema.parse(
        context.req.header("Idempotency-Key"),
      );
      const command = upsertRoleRateCommandSchema.parse(
        await context.req.json(),
      );
      const response = await roleRates.upsert(actor, command, idempotencyKey);
      return context.json(response, response.replayed ? 200 : 201);
    } catch (error) {
      return operationErrorResponse(context, error);
    }
  });

  app.get(
    "/internal/v1/organizations/:organizationId/planning-defaults",
    async (context) => {
      try {
        const actor = await authenticateInternalRequest(context, actorVerifier);
        const organizationId = requireOrganizationId(
          context.req.param("organizationId"),
        );
        const response = await organizationPlanning.get(actor, organizationId);
        return context.json(organizationPlanningDefaultsSchema.parse(response));
      } catch (error) {
        return operationErrorResponse(context, error);
      }
    },
  );

  app.put(
    "/internal/v1/organizations/:organizationId/planning-defaults",
    async (context) => {
      try {
        requireJSONContentType(context.req.header("Content-Type"));
        const actor = await authenticateInternalRequest(context, actorVerifier);
        const organizationId = requireOrganizationId(
          context.req.param("organizationId"),
        );
        const idempotencyKey = idempotencyKeySchema.parse(
          context.req.header("Idempotency-Key"),
        );
        const command = updateOrganizationPlanningDefaultsCommandSchema.parse(
          await context.req.json(),
        );
        const response = await organizationPlanning.update(
          actor,
          organizationId,
          command,
          idempotencyKey,
        );
        return context.json(response, response.replayed ? 200 : 201);
      } catch (error) {
        return operationErrorResponse(context, error);
      }
    },
  );

  return app;
}

function requireProjectId(value: string | undefined): string {
  if (!value || !projectIdParamSchema.test(value)) {
    throw new RequestValidationError(
      400,
      "INVALID_PROJECT_ID",
      "El identificador de proyecto no es válido.",
    );
  }
  return value;
}

function requireOrganizationId(value: string | undefined): string {
  if (!value || !organizationIdParamSchema.test(value)) {
    throw new RequestValidationError(
      400,
      "INVALID_ORGANIZATION_ID",
      "El identificador de organización no es válido.",
    );
  }
  return value;
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
    readonly status: 400 | 415,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "RequestValidationError";
  }
}

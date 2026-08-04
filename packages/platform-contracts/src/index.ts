import { z } from "zod";

export const serviceNameSchema = z.enum([
  "identity",
  "gateway",
  "project-core",
  "tazki",
  "automation",
]);

export type ServiceName = z.infer<typeof serviceNameSchema>;

export const dependencyStatusSchema = z.object({
  name: z.string().min(1).max(80),
  status: z.enum(["available", "unavailable", "not-configured"]),
  detail: z.string().min(1).max(240).optional(),
});

export type DependencyStatus = z.infer<typeof dependencyStatusSchema>;

export const healthResponseSchema = z.object({
  service: serviceNameSchema,
  status: z.enum(["ok", "degraded"]),
  version: z.string().min(1).max(40),
  dependencies: z.array(dependencyStatusSchema),
});

export type HealthResponse = z.infer<typeof healthResponseSchema>;

export const errorEnvelopeSchema = z.object({
  error: z.object({
    code: z.string().regex(/^[A-Z0-9_]{3,64}$/),
    message: z.string().min(1).max(240),
    requestId: z.string().uuid(),
  }),
});

export type ErrorEnvelope = z.infer<typeof errorEnvelopeSchema>;

export const platformStatusSchema = z.object({
  status: z.enum(["ok", "degraded"]),
  services: z.array(healthResponseSchema),
});

export type PlatformStatus = z.infer<typeof platformStatusSchema>;

export const serviceCapabilitySchema = z.object({
  service: serviceNameSchema,
  authority: z.enum([
    "identity",
    "edge",
    "domain",
    "proposal-only",
    "automation",
  ]),
  writesDomain: z.boolean(),
  externalEgress: z.boolean(),
});

export type ServiceCapability = z.infer<typeof serviceCapabilitySchema>;

export const platformCapabilitiesSchema = z.object({
  services: z.array(serviceCapabilitySchema).length(5),
});

export type PlatformCapabilities = z.infer<typeof platformCapabilitiesSchema>;

export const projectTemplateKeySchema = z.enum([
  "web-application",
  "blank-canvas",
]);

export type ProjectTemplateKey = z.infer<typeof projectTemplateKeySchema>;

export const createProjectCommandSchema = z
  .object({
    name: z.string().trim().min(1).max(120),
    templateKey: projectTemplateKeySchema,
    organizationId: z.string().uuid().optional(),
  })
  .strict();

export type CreateProjectCommand = z.infer<typeof createProjectCommandSchema>;

export const projectSummarySchema = z
  .object({
    id: z.string().uuid(),
    organizationId: z.string().uuid(),
    responsibleUserId: z.string().uuid(),
    name: z.string().min(1).max(120),
    templateKey: projectTemplateKeySchema,
    lifecycleStatus: z.enum(["draft", "active", "archived"]),
    rowVersion: z.number().int().positive(),
    createdAt: z.string().datetime({ offset: true }),
  })
  .strict();

export type ProjectSummary = z.infer<typeof projectSummarySchema>;

export const createProjectResponseSchema = z
  .object({
    project: projectSummarySchema,
    replayed: z.boolean(),
  })
  .strict();

export type CreateProjectResponse = z.infer<
  typeof createProjectResponseSchema
>;

export const projectListResponseSchema = z
  .object({
    projects: z.array(projectSummarySchema).max(500),
  })
  .strict();

export type ProjectListResponse = z.infer<typeof projectListResponseSchema>;

export const blockFamilySchema = z.enum([
  "strategy",
  "product",
  "process",
  "technology",
  "people",
  "economy",
  "governance",
]);

export const blockStateSchema = z.enum([
  "draft",
  "ready",
  "warning",
  "approved",
]);

export const architectureLayerSchema = z.enum([
  "experience",
  "services",
  "data",
  "infrastructure",
]);

export const connectionPortSchema = z.enum([
  "top",
  "right",
  "bottom",
  "left",
]);

export const relationTypeSchema = z.enum([
  "contains",
  "dependsOn",
  "implements",
  "requires",
  "produces",
  "validates",
  "assigns",
  "finances",
  "blocks",
]);

function hasControlCharacters(value: string): boolean {
  for (const character of value) {
    const codePoint = character.codePointAt(0) ?? 0;
    if (codePoint < 0x20 || codePoint === 0x7f) {
      return true;
    }
  }
  return false;
}

export const blockSchema = z
  .object({
    id: z.string().uuid(),
    title: z
      .string()
      .trim()
      .min(1)
      .max(80)
      .refine((value) => !hasControlCharacters(value), {
        message: "El texto incluye caracteres de control no permitidos.",
      }),
    summary: z
      .string()
      .max(500)
      .refine((value) => !hasControlCharacters(value), {
        message: "El texto incluye caracteres de control no permitidos.",
      }),
    family: blockFamilySchema,
    state: blockStateSchema,
    architectureLayer: architectureLayerSchema.nullable(),
    position: z
      .object({
        x: z.number().finite().min(-1_000_000).max(1_000_000),
        y: z.number().finite().min(-1_000_000).max(1_000_000),
      })
      .strict(),
    rowVersion: z.number().int().positive(),
  })
  .strict();

export type ProjectBlock = z.infer<typeof blockSchema>;

export const relationSchema = z
  .object({
    id: z.string().uuid(),
    sourceId: z.string().uuid(),
    targetId: z.string().uuid(),
    sourcePort: connectionPortSchema,
    targetPort: connectionPortSchema,
    type: relationTypeSchema,
    isCritical: z.boolean(),
    rowVersion: z.number().int().positive(),
  })
  .strict()
  .refine((relation) => relation.sourceId !== relation.targetId, {
    message: "Un bloque no puede relacionarse consigo mismo.",
    path: ["targetId"],
  });

export type ProjectRelation = z.infer<typeof relationSchema>;

export const projectGraphSchema = z
  .object({
    blocks: z.array(blockSchema).max(500),
    relations: z.array(relationSchema).max(1_000),
  })
  .strict()
  .superRefine((graph, ctx) => {
    const blockIds = new Set<string>();
    for (const block of graph.blocks) {
      if (blockIds.has(block.id)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Dos bloques comparten el mismo identificador.",
          path: ["blocks"],
        });
        return;
      }
      blockIds.add(block.id);
    }

    const relationIds = new Set<string>();
    const semanticRelations = new Set<string>();
    for (const relation of graph.relations) {
      if (relationIds.has(relation.id)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Dos relaciones comparten el mismo identificador.",
          path: ["relations"],
        });
        return;
      }
      relationIds.add(relation.id);

      if (!blockIds.has(relation.sourceId) || !blockIds.has(relation.targetId)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "La relación apunta a un bloque inexistente.",
          path: ["relations"],
        });
        return;
      }

      const semanticKey = `${relation.sourceId}|${relation.type}|${relation.targetId}`;
      if (semanticRelations.has(semanticKey)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Esta relación ya existe.",
          path: ["relations"],
        });
        return;
      }
      semanticRelations.add(semanticKey);
    }
  });

export type ProjectGraph = z.infer<typeof projectGraphSchema>;

export const replaceProjectGraphCommandSchema = z
  .object({
    expectedRowVersion: z.number().int().positive(),
    graph: projectGraphSchema,
  })
  .strict();

export type ReplaceProjectGraphCommand = z.infer<
  typeof replaceProjectGraphCommandSchema
>;

export const projectGraphResponseSchema = z
  .object({
    graph: projectGraphSchema,
    rowVersion: z.number().int().positive(),
    replayed: z.boolean(),
  })
  .strict();

export type ProjectGraphResponse = z.infer<typeof projectGraphResponseSchema>;

export const organizationRoleSchema = z.enum([
  "organization-admin",
  "project-manager",
  "product",
  "technical-lead",
  "design",
  "development",
  "qa",
  "finance",
  "collaborator",
  "client",
  "observer",
]);

export const membershipStatusSchema = z.enum([
  "invited",
  "active",
  "suspended",
  "revoked",
]);

export const organizationMemberSchema = z
  .object({
    organizationId: z.string().uuid(),
    userId: z.string().uuid(),
    displayName: z.string().max(120).nullable(),
    role: organizationRoleSchema,
    status: membershipStatusSchema,
    createdAt: z.string().datetime({ offset: true }),
  })
  .strict();

export type OrganizationMember = z.infer<typeof organizationMemberSchema>;

export const membersListResponseSchema = z
  .object({
    members: z.array(organizationMemberSchema).max(1_000),
  })
  .strict();

export type MembersListResponse = z.infer<typeof membersListResponseSchema>;

export const roleRateSchema = z
  .object({
    organizationId: z.string().uuid(),
    role: organizationRoleSchema,
    hourlyRateMXN: z.number().int().min(0).max(100_000),
    updatedAt: z.string().datetime({ offset: true }),
  })
  .strict();

export type RoleRate = z.infer<typeof roleRateSchema>;

export const roleRatesListResponseSchema = z
  .object({
    rates: z.array(roleRateSchema).max(1_000),
  })
  .strict();

export type RoleRatesListResponse = z.infer<typeof roleRatesListResponseSchema>;

export const upsertRoleRateCommandSchema = z
  .object({
    organizationId: z.string().uuid(),
    role: organizationRoleSchema,
    hourlyRateMXN: z.number().int().min(0).max(100_000),
  })
  .strict();

export type UpsertRoleRateCommand = z.infer<typeof upsertRoleRateCommandSchema>;

export const upsertRoleRateResponseSchema = z
  .object({
    rate: roleRateSchema,
    replayed: z.boolean(),
  })
  .strict();

export type UpsertRoleRateResponse = z.infer<typeof upsertRoleRateResponseSchema>;

export const organizationPlanningDefaultsSchema = z
  .object({
    organizationId: z.string().uuid(),
    riskReservePercent: z.number().int().min(0).max(100),
    targetMarginPercent: z.number().int().min(0).max(100),
    workdayHours: z.number().int().min(1).max(24),
    updatedAt: z.string().datetime({ offset: true }),
  })
  .strict();

export type OrganizationPlanningDefaults = z.infer<
  typeof organizationPlanningDefaultsSchema
>;

export const updateOrganizationPlanningDefaultsCommandSchema = z
  .object({
    riskReservePercent: z.number().int().min(0).max(100),
    targetMarginPercent: z.number().int().min(0).max(100),
    workdayHours: z.number().int().min(1).max(24),
  })
  .strict();

export type UpdateOrganizationPlanningDefaultsCommand = z.infer<
  typeof updateOrganizationPlanningDefaultsCommandSchema
>;

export const updateOrganizationPlanningDefaultsResponseSchema = z
  .object({
    defaults: organizationPlanningDefaultsSchema,
    replayed: z.boolean(),
  })
  .strict();

export type UpdateOrganizationPlanningDefaultsResponse = z.infer<
  typeof updateOrganizationPlanningDefaultsResponseSchema
>;

export const externalActorSchema = z
  .object({
    issuer: z.string().url().max(512),
    subject: z.string().min(1).max(255),
    displayName: z.string().trim().min(1).max(120).optional(),
  })
  .strict();

export type ExternalActor = z.infer<typeof externalActorSchema>;

export const internalActorClaimsSchema = z
  .object({
    subject: z.string().min(1).max(255),
    identityIssuer: z.string().url().max(512),
    displayName: z.string().trim().min(1).max(120).optional(),
    requestId: z.string().uuid(),
  })
  .strict();

export type InternalActorClaims = z.infer<typeof internalActorClaimsSchema>;

export const idempotencyKeySchema = z
  .string()
  .min(16)
  .max(128)
  .regex(/^[A-Za-z0-9._~-]+$/);

export const HTTP_HEADERS = {
  requestId: "X-Request-ID",
  parentRequestId: "X-Parent-Request-ID",
  clientVersion: "X-Client-Version",
  idempotencyKey: "Idempotency-Key",
  trustedClientIp: "X-Tazkle-Client-IP",
} as const;

export const MAX_JSON_BODY_BYTES = 1_048_576;

export function createHealthResponse(
  service: ServiceName,
  dependencies: DependencyStatus[] = [],
): HealthResponse {
  const status = dependencies.some((dependency) => dependency.status === "unavailable")
    ? "degraded"
    : "ok";

  return healthResponseSchema.parse({
    service,
    status,
    version: "0.1.0",
    dependencies,
  });
}

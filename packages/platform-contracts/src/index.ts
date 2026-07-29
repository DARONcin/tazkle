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

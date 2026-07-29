import {
  externalActorSchema,
  type ExternalActor,
} from "@tazkle/platform-contracts";
import {
  createRemoteJWKSet,
  jwtVerify,
  SignJWT,
  type JWTVerifyGetKey,
  type JWTPayload,
} from "jose";

const ACCESS_TOKEN_ALGORITHMS = ["RS256", "ES256"] as const;
const INTERNAL_ISSUER = "tazkle-gateway";
const INTERNAL_AUDIENCE = "tazkle-project-core";
const MAX_AUTHORIZATION_HEADER_BYTES = 8_192;

export type AccessTokenVerifier = {
  verify: (token: string) => Promise<ExternalActor>;
};

export type InternalActorSigner = {
  sign: (actor: ExternalActor, requestId: string) => Promise<string>;
};

type OIDCConfiguration = {
  issuer: string;
  audience: string;
  jwksURL: URL;
};

export class AuthenticationError extends Error {
  constructor() {
    super("Authentication failed");
    this.name = "AuthenticationError";
  }
}

export function createOIDCAccessTokenVerifier(
  configuration: OIDCConfiguration,
  keySet: JWTVerifyGetKey = createRemoteJWKSet(configuration.jwksURL, {
    timeoutDuration: 2_000,
    cooldownDuration: 30_000,
    cacheMaxAge: 10 * 60_000,
  }),
): AccessTokenVerifier {
  return {
    verify: async (token) => {
      try {
        const { payload } = await jwtVerify(token, keySet, {
          issuer: configuration.issuer,
          audience: configuration.audience,
          algorithms: [...ACCESS_TOKEN_ALGORITHMS],
          requiredClaims: ["iss", "sub", "aud", "exp"],
          clockTolerance: 5,
        });

        return actorFromVerifiedPayload(payload);
      } catch {
        throw new AuthenticationError();
      }
    },
  };
}

export function createInternalActorSigner(
  secret: string | undefined,
): InternalActorSigner {
  const key = internalIdentityKey(secret);

  return {
    sign: async (actor, requestId) => {
      return new SignJWT({
        identityIssuer: actor.issuer,
        displayName: actor.displayName,
        requestId,
      })
        .setProtectedHeader({ alg: "HS256", typ: "JWT" })
        .setIssuer(INTERNAL_ISSUER)
        .setAudience(INTERNAL_AUDIENCE)
        .setSubject(actor.subject)
        .setJti(requestId)
        .setIssuedAt()
        .setExpirationTime("30s")
        .sign(key);
    },
  };
}

export function oidcConfigurationFromEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): OIDCConfiguration {
  const allowInsecureLocalOIDC =
    environment.ALLOW_INSECURE_LOCAL_OIDC === "true";
  const issuerURL = requireOIDCURL(
    environment.OIDC_ISSUER,
    "OIDC_ISSUER",
    allowInsecureLocalOIDC,
    ["127.0.0.1", "localhost", "::1"],
  );
  const jwksURL = requireOIDCURL(
    environment.OIDC_JWKS_URL,
    "OIDC_JWKS_URL",
    allowInsecureLocalOIDC,
    ["127.0.0.1", "localhost", "::1", "identity"],
  );
  const audience = environment.OIDC_AUDIENCE?.trim();

  if (!audience || audience.length > 256) {
    throw new Error("OIDC_AUDIENCE must contain between 1 and 256 characters");
  }

  return {
    issuer: issuerURL.toString().replace(/\/$/, ""),
    audience,
    jwksURL,
  };
}

export function readBearerToken(
  authorizationHeader: string | undefined,
): string {
  if (
    !authorizationHeader ||
    Buffer.byteLength(authorizationHeader, "utf8") >
      MAX_AUTHORIZATION_HEADER_BYTES
  ) {
    throw new AuthenticationError();
  }

  const match = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/i.exec(
    authorizationHeader,
  );
  if (!match?.[1]) {
    throw new AuthenticationError();
  }

  return match[1];
}

function actorFromVerifiedPayload(payload: JWTPayload): ExternalActor {
  const displayName = firstSafeDisplayName([
    payload.name,
    payload.preferred_username,
    payload.email,
  ]);

  return externalActorSchema.parse({
    issuer: payload.iss,
    subject: payload.sub,
    displayName,
  });
}

function firstSafeDisplayName(candidates: unknown[]): string | undefined {
  for (const candidate of candidates) {
    if (typeof candidate !== "string") {
      continue;
    }
    const normalized = candidate.trim();
    if (
      normalized.length >= 1 &&
      normalized.length <= 120 &&
      !/[\u0000-\u001F\u007F]/.test(normalized)
    ) {
      return normalized;
    }
  }
  return undefined;
}

function requireOIDCURL(
  rawValue: string | undefined,
  variableName: string,
  allowInsecureLocalOIDC: boolean,
  allowedHTTPHosts: string[],
): URL {
  if (!rawValue) {
    throw new Error(`${variableName} is required`);
  }

  const url = new URL(rawValue);
  const allowedLocalHTTP =
    allowInsecureLocalOIDC &&
    url.protocol === "http:" &&
    allowedHTTPHosts.includes(url.hostname);
  if (
    (url.protocol !== "https:" && !allowedLocalHTTP) ||
    url.username ||
    url.password ||
    url.search ||
    url.hash
  ) {
    throw new Error(
      `${variableName} must be a fixed HTTPS URL without credentials, query, or fragment; explicit local mode accepts only allowlisted HTTP hosts`,
    );
  }
  return url;
}

function internalIdentityKey(secret: string | undefined): Uint8Array {
  if (!secret || Buffer.byteLength(secret, "utf8") < 32) {
    throw new Error(
      "INTERNAL_IDENTITY_SECRET must contain at least 32 bytes",
    );
  }
  return new TextEncoder().encode(secret);
}

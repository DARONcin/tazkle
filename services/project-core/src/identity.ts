import {
  internalActorClaimsSchema,
  type InternalActorClaims,
} from "@tazkle/platform-contracts";
import { jwtVerify } from "jose";

const INTERNAL_ISSUER = "tazkle-gateway";
const INTERNAL_AUDIENCE = "tazkle-project-core";

export type InternalActorVerifier = {
  verify: (token: string) => Promise<InternalActorClaims>;
};

export class InternalAuthenticationError extends Error {
  constructor() {
    super("Internal authentication failed");
    this.name = "InternalAuthenticationError";
  }
}

export function createInternalActorVerifier(
  secret: string | undefined,
): InternalActorVerifier {
  const key = internalIdentityKey(secret);

  return {
    verify: async (token) => {
      try {
        const { payload } = await jwtVerify(token, key, {
          issuer: INTERNAL_ISSUER,
          audience: INTERNAL_AUDIENCE,
          algorithms: ["HS256"],
          requiredClaims: [
            "iss",
            "sub",
            "aud",
            "exp",
            "iat",
            "jti",
            "identityIssuer",
            "requestId",
          ],
          clockTolerance: 2,
        });

        if (payload.jti !== payload.requestId) {
          throw new InternalAuthenticationError();
        }

        return internalActorClaimsSchema.parse({
          subject: payload.sub,
          identityIssuer: payload.identityIssuer,
          displayName: payload.displayName,
          requestId: payload.requestId,
        });
      } catch {
        throw new InternalAuthenticationError();
      }
    },
  };
}

export function readInternalBearerToken(
  authorizationHeader: string | undefined,
): string {
  const match =
    /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(
      authorizationHeader ?? "",
    );
  if (!match?.[1] || Buffer.byteLength(match[1], "utf8") > 8_192) {
    throw new InternalAuthenticationError();
  }
  return match[1];
}

function internalIdentityKey(secret: string | undefined): Uint8Array {
  if (!secret || Buffer.byteLength(secret, "utf8") < 32) {
    throw new Error(
      "INTERNAL_IDENTITY_SECRET must contain at least 32 bytes",
    );
  }
  return new TextEncoder().encode(secret);
}

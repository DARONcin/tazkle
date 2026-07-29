import { readSecretValue } from "@tazkle/service-kit";
import type { PoolConfig } from "pg";

const DEFAULT_BASE_PATH = "/api/auth";
const DEFAULT_CLIENT_ID = "tazkle-macos";
const DEFAULT_REDIRECT_URI = "app.tazkle.desktop:/oauth/callback";
const DEFAULT_AUDIENCE = "tazkle-local";

export type IdentityConfiguration = {
  publicBaseURL: URL;
  publicOrigin: string;
  basePath: string;
  secret: string;
  database: PoolConfig;
  macOSClient: {
    id: string;
    redirectURI: string;
  };
  audience: string;
  secureCookies: boolean;
  socialProviders: {
    google?: OAuthProviderCredentials;
    microsoft?: OAuthProviderCredentials & {
      tenantID: string;
    };
  };
};

export type SocialProviderID = "google" | "microsoft";

type OAuthProviderCredentials = {
  clientID: string;
  clientSecret: string;
};

export function identityConfigurationFromEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): IdentityConfiguration {
  const basePath = normalizedBasePath(
    environment.BETTER_AUTH_BASE_PATH ?? DEFAULT_BASE_PATH,
  );
  const publicBaseURL = requirePublicBaseURL(
    environment.BETTER_AUTH_URL,
    basePath,
    environment.ALLOW_INSECURE_LOCAL_OIDC === "true",
  );
  const clientID = requireBoundedValue(
    environment.TAZKLE_OIDC_CLIENT_ID ?? DEFAULT_CLIENT_ID,
    "TAZKLE_OIDC_CLIENT_ID",
    256,
  );
  const redirectURI = requireNativeRedirectURI(
    environment.TAZKLE_OIDC_REDIRECT_URI ?? DEFAULT_REDIRECT_URI,
  );
  const audience = requireBoundedValue(
    environment.TAZKLE_OIDC_AUDIENCE ?? DEFAULT_AUDIENCE,
    "TAZKLE_OIDC_AUDIENCE",
    256,
  );
  const google = optionalOAuthProviderCredentials(
    environment.GOOGLE_CLIENT_ID,
    environment.GOOGLE_CLIENT_SECRET,
    environment.GOOGLE_CLIENT_SECRET_FILE,
    "Google",
  );
  const microsoft = optionalOAuthProviderCredentials(
    environment.MICROSOFT_CLIENT_ID,
    environment.MICROSOFT_CLIENT_SECRET,
    environment.MICROSOFT_CLIENT_SECRET_FILE,
    "Microsoft",
  );

  return {
    publicBaseURL,
    publicOrigin: publicBaseURL.origin,
    basePath,
    secret: readSecretValue(
      environment.BETTER_AUTH_SECRET,
      environment.BETTER_AUTH_SECRET_FILE,
      "Better Auth secret",
    ),
    database: databasePoolConfiguration(environment),
    macOSClient: {
      id: clientID,
      redirectURI,
    },
    audience,
    secureCookies: publicBaseURL.protocol === "https:",
    socialProviders: {
      ...(google ? { google } : {}),
      ...(microsoft
        ? {
            microsoft: {
              ...microsoft,
              tenantID: requireBoundedValue(
                environment.MICROSOFT_TENANT_ID ?? "common",
                "MICROSOFT_TENANT_ID",
                128,
              ),
            },
          }
        : {}),
    },
  };
}

export function enabledSocialProviders(
  configuration: IdentityConfiguration,
): SocialProviderID[] {
  const providers: SocialProviderID[] = [];
  if (configuration.socialProviders.google) {
    providers.push("google");
  }
  if (configuration.socialProviders.microsoft) {
    providers.push("microsoft");
  }
  return providers;
}

function requirePublicBaseURL(
  rawValue: string | undefined,
  basePath: string,
  allowInsecureLocalOIDC: boolean,
): URL {
  if (!rawValue) {
    throw new Error("BETTER_AUTH_URL is required");
  }

  const url = new URL(rawValue);
  const isDevelopmentLoopback =
    allowInsecureLocalOIDC &&
    url.protocol === "http:" &&
    ["127.0.0.1", "localhost", "::1"].includes(url.hostname);
  if (
    (url.protocol !== "https:" && !isDevelopmentLoopback) ||
    url.username ||
    url.password ||
    url.search ||
    url.hash ||
    normalizePath(url.pathname) !== basePath
  ) {
    throw new Error(
      `BETTER_AUTH_URL must be HTTPS and end in ${basePath}; explicit local mode accepts HTTP only on loopback`,
    );
  }
  return new URL(url.toString().replace(/\/$/, ""));
}

function databasePoolConfiguration(environment: NodeJS.ProcessEnv): PoolConfig {
  const searchPath = "-c search_path=auth,public";
  if (environment.DATABASE_URL) {
    return {
      connectionString: environment.DATABASE_URL,
      options: searchPath,
    };
  }
  if (!environment.PGHOST || !environment.PGUSER || !environment.PGDATABASE) {
    throw new Error("Identity PostgreSQL configuration is required");
  }

  const port = Number(environment.PGPORT ?? "5432");
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error("PGPORT must be an integer between 1 and 65535");
  }

  return {
    host: environment.PGHOST,
    port,
    user: environment.PGUSER,
    password: readSecretValue(
      environment.PGPASSWORD,
      environment.PGPASSWORD_FILE,
      "Identity PostgreSQL password",
    ),
    database: environment.PGDATABASE,
    options: searchPath,
  };
}

function normalizedBasePath(value: string): string {
  const normalized = normalizePath(value.trim());
  if (
    normalized.length < 2 ||
    normalized.length > 80 ||
    !/^\/[a-z0-9/-]+$/i.test(normalized)
  ) {
    throw new Error("BETTER_AUTH_BASE_PATH is invalid");
  }
  return normalized;
}

function normalizePath(value: string): string {
  const withLeadingSlash = value.startsWith("/") ? value : `/${value}`;
  return withLeadingSlash.replace(/\/+$/, "") || "/";
}

function requireNativeRedirectURI(rawValue: string): string {
  const value = rawValue.trim();
  const url = new URL(value);
  if (
    url.protocol !== "app.tazkle.desktop:" ||
    url.username ||
    url.password ||
    url.host ||
    url.pathname !== "/oauth/callback" ||
    url.search ||
    url.hash
  ) {
    throw new Error(
      "TAZKLE_OIDC_REDIRECT_URI must be app.tazkle.desktop:/oauth/callback",
    );
  }
  return value;
}

function requireBoundedValue(
  rawValue: string,
  variableName: string,
  maximumLength: number,
): string {
  const value = rawValue.trim();
  if (
    !value ||
    value.length > maximumLength ||
    /[\u0000-\u001F\u007F]/.test(value)
  ) {
    throw new Error(
      `${variableName} must contain between 1 and ${maximumLength} safe characters`,
    );
  }
  return value;
}

function optionalOAuthProviderCredentials(
  rawClientID: string | undefined,
  rawClientSecret: string | undefined,
  clientSecretFile: string | undefined,
  providerName: string,
): OAuthProviderCredentials | undefined {
  const hasClientID = Boolean(rawClientID?.trim());
  const hasClientSecret = Boolean(rawClientSecret || clientSecretFile);

  if (!hasClientID && !hasClientSecret) {
    return undefined;
  }
  if (!hasClientID || !hasClientSecret) {
    throw new Error(
      `${providerName} OAuth requires both client ID and client secret`,
    );
  }

  return {
    clientID: requireBoundedValue(
      rawClientID as string,
      `${providerName.toUpperCase()}_CLIENT_ID`,
      512,
    ),
    clientSecret: readSecretValue(
      rawClientSecret,
      clientSecretFile,
      `${providerName} OAuth client secret`,
    ),
  };
}

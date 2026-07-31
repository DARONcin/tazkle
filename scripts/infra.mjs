import { createHash, randomBytes } from "node:crypto";
import {
  access,
  chmod,
  lstat,
  mkdir,
  readFile,
  readlink,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const action = process.argv[2];
const actions = {
  config: ["config", "--quiet"],
  "domain-smoke": ["--profile", "test", "run", "--rm", "domain-smoke"],
  down: ["down"],
  up: ["up", "--build"],
  "up-detached": ["up", "--build", "-d"],
  logs: ["logs", "--no-color", "--timestamps"],
};

if (action !== "init" && !(action in actions)) {
  console.error(
    "Uso: node scripts/infra.mjs <init|config|domain-smoke|up|up-detached|down|logs>",
  );
  process.exit(2);
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const composeFile = path.join(root, "infrastructure", "compose.yaml");
const envFile = path.join(root, "infrastructure", ".env.local");
const repositoryKey = createHash("sha256")
  .update(root)
  .digest("hex")
  .slice(0, 10);

if (action === "init") {
  await initializeLocalEnvironment(envFile);
  process.exit(0);
}

async function asciiBuildContext() {
  if (/^[\x00-\x7F]+$/.test(root)) {
    return root;
  }

  const linkPath = path.join("/tmp", `tazkle-build-${repositoryKey}`);

  try {
    const entry = await lstat(linkPath);
    if (!entry.isSymbolicLink() || (await readlink(linkPath)) !== root) {
      throw new Error(`${linkPath} existe y no pertenece a este repositorio`);
    }
  } catch (error) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
    await symlink(root, linkPath, "dir");
  }

  console.info(`Docker: contexto ASCII temporal ${linkPath}`);
  return linkPath;
}

const buildContext = await asciiBuildContext();
const composeArgs = ["compose"];
const childEnvironment = await environmentWithLocalFile(process.env);
const secretDirectory = await prepareSecretFiles(childEnvironment);

try {
  await access(envFile);
  composeArgs.push("--env-file", envFile);
} catch {
  // Compose mostrará la variable obligatoria ausente o utilizará el entorno.
}

composeArgs.push("-f", composeFile, ...actions[action]);
const result = spawnSync(
  "docker",
  composeArgs,
  {
    cwd: root,
    env: {
      ...childEnvironment,
      TAZKLE_BUILD_CONTEXT: buildContext,
      TAZKLE_SECRETS_DIR: secretDirectory,
    },
    stdio: "inherit",
  },
);

if (result.error) {
  console.error(`No fue posible ejecutar Docker Compose: ${result.error.message}`);
  process.exit(1);
}

if (action === "down" && result.status === 0) {
  await rm(secretDirectory, { recursive: true, force: true });
}

process.exit(result.status ?? 1);

async function environmentWithLocalFile(baseEnvironment) {
  const merged = { ...baseEnvironment };
  try {
    const contents = await readFile(envFile, "utf8");
    for (const rawLine of contents.split(/\r?\n/)) {
      const line = rawLine.trim();
      if (!line || line.startsWith("#")) {
        continue;
      }
      const match = /^([A-Z][A-Z0-9_]*)=(.*)$/.exec(line);
      if (!match) {
        throw new Error("infrastructure/.env.local contains an invalid line");
      }
      const [, name, rawValue] = match;
      if (!(name in merged)) {
        merged[name] = unquote(rawValue.trim());
      }
    }
  } catch (error) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
  }
  return merged;
}

async function initializeLocalEnvironment(destination) {
  try {
    await access(destination);
    console.info("La configuración local ya existe; no se modificó.");
    return;
  } catch (error) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
  }

  const secret = () => randomBytes(36).toString("base64url");
  const contents = [
    "# Generado localmente por npm run infra:init. No confirmar en Git.",
    `TAZKLE_POSTGRES_ADMIN_PASSWORD=${secret()}`,
    `TAZKLE_APP_DATABASE_PASSWORD=${secret()}`,
    `TAZKLE_IDENTITY_DATABASE_PASSWORD=${secret()}`,
    `TAZKLE_INTERNAL_IDENTITY_SECRET=${secret()}`,
    `TAZKLE_BETTER_AUTH_SECRET=${secret()}`,
    "TAZKLE_RESEND_API_KEY=",
    "TAZKLE_AUTH_EMAIL_FROM=Tazkle <onboarding@resend.dev>",
    "TAZKLE_BETTER_AUTH_URL=http://127.0.0.1:8787/api/auth",
    "TAZKLE_OIDC_ISSUER=http://127.0.0.1:8787/api/auth",
    "TAZKLE_OIDC_AUDIENCE=tazkle-local",
    "TAZKLE_OIDC_JWKS_URL=http://identity:8791/api/auth/jwks",
    "TAZKLE_ALLOW_INSECURE_LOCAL_OIDC=true",
    "TAZKLE_OIDC_CLIENT_ID=tazkle-macos",
    "TAZKLE_OIDC_RESOURCE=tazkle-local",
    "TAZKLE_GATEWAY_PORT=8787",
    "",
  ].join("\n");

  await writeFile(destination, contents, {
    encoding: "utf8",
    mode: 0o600,
    flag: "wx",
  });
  await chmod(destination, 0o600);
  console.info("Configuración local creada sin exponer secretos.");
}

function unquote(value) {
  if (
    value.length >= 2 &&
    ((value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'")))
  ) {
    return value.slice(1, -1);
  }
  return value;
}

async function prepareSecretFiles(environment) {
  const secretDirectory = path.join(
    "/tmp",
    `tazkle-secrets-${repositoryKey}`,
  );
  const secrets = {
    "postgres-admin-password": environment.TAZKLE_POSTGRES_ADMIN_PASSWORD,
    "postgres-app-password": environment.TAZKLE_APP_DATABASE_PASSWORD,
    "identity-db-password": environment.TAZKLE_IDENTITY_DATABASE_PASSWORD,
    "internal-identity-secret": environment.TAZKLE_INTERNAL_IDENTITY_SECRET,
    "better-auth-secret": environment.TAZKLE_BETTER_AUTH_SECRET,
    "resend-api-key": environment.TAZKLE_RESEND_API_KEY,
    "google-oauth-secret": optionalProviderSecret(
      environment.TAZKLE_GOOGLE_CLIENT_ID,
      environment.TAZKLE_GOOGLE_CLIENT_SECRET,
      "TAZKLE_GOOGLE_CLIENT_SECRET",
    ),
    "microsoft-oauth-secret": optionalProviderSecret(
      environment.TAZKLE_MICROSOFT_CLIENT_ID,
      environment.TAZKLE_MICROSOFT_CLIENT_SECRET,
      "TAZKLE_MICROSOFT_CLIENT_SECRET",
    ),
  };

  try {
    const entry = await lstat(secretDirectory);
    if (!entry.isDirectory() || entry.isSymbolicLink()) {
      throw new Error(`${secretDirectory} is not a trusted directory`);
    }
  } catch (error) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
    await mkdir(secretDirectory, { mode: 0o700 });
  }
  await chmod(secretDirectory, 0o700);

  for (const [filename, value] of Object.entries(secrets)) {
    if (
      !value ||
      Buffer.byteLength(value, "utf8") < 32 ||
      value.includes("\0") ||
      /[\r\n]/.test(value) ||
      Buffer.byteLength(value, "utf8") > 4_096
    ) {
      throw new Error(`${filename} is missing or invalid`);
    }
    const destination = path.join(secretDirectory, filename);
    try {
      const entry = await lstat(destination);
      if (!entry.isFile() || entry.isSymbolicLink()) {
        throw new Error(`${destination} is not a trusted secret file`);
      }
    } catch (error) {
      if (error?.code !== "ENOENT") {
        throw error;
      }
    }
    await writeFile(destination, value, { mode: 0o600 });
    await chmod(destination, 0o600);
  }

  return secretDirectory;
}

function optionalProviderSecret(clientID, clientSecret, variableName) {
  if (clientID && !clientSecret) {
    throw new Error(`${variableName} is required when its provider is enabled`);
  }
  return clientSecret || randomBytes(36).toString("base64url");
}

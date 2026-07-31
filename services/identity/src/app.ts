import { serviceCapabilitySchema } from "@tazkle/platform-contracts";
import { createServiceApp } from "@tazkle/service-kit";
import type { DependencyStatus } from "@tazkle/platform-contracts";
import {
  accountClientScript,
  consentClientScript,
  deleteAccountClientScript,
} from "./client-scripts.js";
import {
  consentPage,
  deleteAccountPage,
  signInPage,
  signUpPage,
} from "./pages.js";
import type { SocialProviderID } from "./config.js";

type IdentityHandler = {
  handler: (request: Request) => Promise<Response>;
};

type IdentityAppOptions = {
  auth: IdentityHandler;
  readiness?: () => Promise<DependencyStatus[]>;
  socialProviders?: readonly SocialProviderID[];
  accountDeletion?: {
    userExists: (userID: string) => Promise<boolean>;
  };
};

export function createIdentityApp({
  auth,
  readiness = async () => [],
  socialProviders = [],
  accountDeletion,
}: IdentityAppOptions) {
  const app = createServiceApp({
    service: "identity",
    readiness,
  });

  app.get("/internal/capabilities", (context) => {
    return context.json(
      serviceCapabilitySchema.parse({
        service: "identity",
        authority: "identity",
        writesDomain: false,
        externalEgress: true,
      }),
    );
  });

  app.get("/sign-in", (context) => {
    return identityHTMLResponse(context.req.url, (search) =>
      signInPage(search, socialProviders),
    );
  });

  app.get("/sign-up", (context) => {
    return identityHTMLResponse(context.req.url, (search) =>
      signUpPage(search, socialProviders),
    );
  });

  app.get("/consent", (context) => {
    return identityHTMLResponse(context.req.url, consentPage);
  });

  app.get("/account/delete", (context) => {
    return identityHTMLResponse(context.req.url, deleteAccountPage);
  });

  app.get("/identity/client/account.js", () => {
    return identityScriptResponse(accountClientScript);
  });

  app.get("/identity/client/consent.js", () => {
    return identityScriptResponse(consentClientScript);
  });

  app.get("/identity/client/delete-account.js", () => {
    return identityScriptResponse(deleteAccountClientScript);
  });

  app.get(
    "/.well-known/oauth-authorization-server/api/auth",
    (context) => auth.handler(context.req.raw),
  );

  app.post("/api/auth/tazkle-delete-user", (context) => {
    return confirmedAccountDeletion(
      context.req.raw,
      auth,
      accountDeletion,
    );
  });

  app.on(["GET", "POST"], "/api/auth/*", (context) => {
    return auth.handler(context.req.raw);
  });

  return app;
}

async function confirmedAccountDeletion(
  request: Request,
  auth: IdentityHandler,
  accountDeletion: IdentityAppOptions["accountDeletion"],
): Promise<Response> {
  if (!accountDeletion) {
    return deletionError(
      503,
      "REMOTE_DELETION_UNAVAILABLE",
      "No fue posible verificar el borrado remoto.",
    );
  }

  const contentType = request.headers.get("Content-Type") ?? "";
  if (!contentType.toLowerCase().startsWith("application/json")) {
    return deletionError(
      415,
      "UNSUPPORTED_MEDIA_TYPE",
      "La confirmación debe enviarse como JSON.",
    );
  }

  let body: unknown;
  try {
    const rawBody = await request.text();
    if (rawBody.length > 128) {
      return deletionError(
        413,
        "PAYLOAD_TOO_LARGE",
        "La confirmación es demasiado grande.",
      );
    }
    body = JSON.parse(rawBody);
  } catch {
    return deletionError(
      400,
      "INVALID_CONFIRMATION",
      "La confirmación no es válida.",
    );
  }

  if (
    !body ||
    typeof body !== "object" ||
    Array.isArray(body) ||
    Object.keys(body).length !== 1 ||
    !("confirmation" in body) ||
    body.confirmation !== "ELIMINAR"
  ) {
    return deletionError(
      400,
      "INVALID_CONFIRMATION",
      "Escribe exactamente ELIMINAR.",
    );
  }

  const sessionRequest = identityAuthRequest(
    request,
    "/api/auth/get-session",
    "GET",
  );
  const sessionResponse = await auth.handler(sessionRequest);
  const sessionPayload = await boundedJSON(sessionResponse, 32_768);
  const userID = authenticatedUserID(sessionPayload);
  if (!sessionResponse.ok || !userID) {
    return deletionError(
      401,
      "UNAUTHORIZED",
      "La sesión no es válida.",
    );
  }

  const deleteRequest = identityAuthRequest(
    request,
    "/api/auth/delete-user",
    "POST",
    "{}",
  );
  const deleteResponse = await auth.handler(deleteRequest);
  const deletePayload = await boundedJSON(deleteResponse.clone(), 8_192);
  if (
    !deleteResponse.ok ||
    !deletePayload ||
    typeof deletePayload !== "object" ||
    !("success" in deletePayload) ||
    deletePayload.success !== true ||
    !("message" in deletePayload) ||
    deletePayload.message !== "User deleted"
  ) {
    return deleteResponse;
  }

  try {
    if (await accountDeletion.userExists(userID)) {
      return deletionError(
        503,
        "REMOTE_DELETION_UNCONFIRMED",
        "Identity no pudo confirmar el borrado remoto. Los datos locales se conservaron.",
      );
    }
  } catch {
    return deletionError(
      503,
      "REMOTE_DELETION_UNCONFIRMED",
      "Identity no pudo confirmar el borrado remoto. Los datos locales se conservaron.",
    );
  }

  return deleteResponse;
}

function identityAuthRequest(
  source: Request,
  path: string,
  method: "GET" | "POST",
  body?: string,
): Request {
  const headers = new Headers();
  for (const name of [
    "Cookie",
    "Origin",
    "User-Agent",
    "Sec-Fetch-Dest",
    "Sec-Fetch-Mode",
    "Sec-Fetch-Site",
  ]) {
    const value = source.headers.get(name);
    if (value) {
      headers.set(name, value);
    }
  }
  headers.set("Accept", "application/json");
  if (body !== undefined) {
    headers.set("Content-Type", "application/json");
  }
  return new Request(new URL(path, source.url), {
    method,
    headers,
    ...(body === undefined ? {} : { body }),
  });
}

async function boundedJSON(
  response: Response,
  maximumBytes: number,
): Promise<unknown> {
  const text = await response.text();
  if (Buffer.byteLength(text, "utf8") > maximumBytes) {
    return undefined;
  }
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

function authenticatedUserID(payload: unknown): string | undefined {
  if (
    !payload ||
    typeof payload !== "object" ||
    !("user" in payload) ||
    !payload.user ||
    typeof payload.user !== "object" ||
    !("id" in payload.user) ||
    typeof payload.user.id !== "string"
  ) {
    return undefined;
  }
  const value = payload.user.id.trim();
  if (
    value.length < 1 ||
    value.length > 255 ||
    /[\u0000-\u001F\u007F]/.test(value)
  ) {
    return undefined;
  }
  return value;
}

function deletionError(
  status: 400 | 401 | 413 | 415 | 503,
  code: string,
  message: string,
): Response {
  return Response.json(
    {
      code,
      message,
    },
    {
      status,
      headers: {
        "Cache-Control": "no-store",
      },
    },
  );
}

function identityScriptResponse(script: string): Response {
  return new Response(script, {
    status: 200,
    headers: {
      "Content-Type": "application/javascript; charset=utf-8",
      "Cache-Control": "no-store",
      "Cross-Origin-Resource-Policy": "same-origin",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function identityHTMLResponse(
  requestURL: string,
  render: (search: string) => {
    body: string;
    contentSecurityPolicy: string;
  },
): Response {
  const page = render(new URL(requestURL).search);
  return new Response(page.body, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Content-Security-Policy": page.contentSecurityPolicy,
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Resource-Policy": "same-origin",
      "X-Frame-Options": "DENY",
      "Cache-Control": "no-store",
    },
  });
}

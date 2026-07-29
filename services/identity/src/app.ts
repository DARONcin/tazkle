import { serviceCapabilitySchema } from "@tazkle/platform-contracts";
import { createServiceApp } from "@tazkle/service-kit";
import type { DependencyStatus } from "@tazkle/platform-contracts";
import {
  accountClientScript,
  consentClientScript,
} from "./client-scripts.js";
import { consentPage, signInPage, signUpPage } from "./pages.js";
import type { SocialProviderID } from "./config.js";

type IdentityHandler = {
  handler: (request: Request) => Promise<Response>;
};

type IdentityAppOptions = {
  auth: IdentityHandler;
  readiness?: () => Promise<DependencyStatus[]>;
  socialProviders?: readonly SocialProviderID[];
};

export function createIdentityApp({
  auth,
  readiness = async () => [],
  socialProviders = [],
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
        externalEgress: false,
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

  app.get("/identity/client/account.js", () => {
    return identityScriptResponse(accountClientScript);
  });

  app.get("/identity/client/consent.js", () => {
    return identityScriptResponse(consentClientScript);
  });

  app.get(
    "/.well-known/oauth-authorization-server/api/auth",
    (context) => auth.handler(context.req.raw),
  );

  app.on(["GET", "POST"], "/api/auth/*", (context) => {
    return auth.handler(context.req.raw);
  });

  return app;
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

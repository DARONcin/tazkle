import {
  createServiceApp,
  probeHTTPDependency,
} from "@tazkle/service-kit";

type TazkiAppOptions = {
  projectCoreURL: URL;
  fetchImplementation?: typeof fetch;
};

export function createTazkiApp({
  projectCoreURL,
  fetchImplementation = fetch,
}: TazkiAppOptions) {
  const app = createServiceApp({
    service: "tazki",
    readiness: async () => [
      await probeHTTPDependency(
        "project-core",
        new URL("/health/live", projectCoreURL),
        fetchImplementation,
      ),
    ],
  });

  app.get("/internal/capabilities", (context) => {
    return context.json({
      service: "tazki",
      authority: "proposal-only",
      writesDomain: false,
      externalEgress: true,
    });
  });

  app.post("/internal/proposals", (context) => {
    return context.json(
      {
        error: {
          code: "PROVIDER_NOT_CONFIGURED",
          message: "El proveedor de IA todavía no está configurado.",
          requestId: context.get("requestId"),
        },
      },
      503,
    );
  });

  return app;
}

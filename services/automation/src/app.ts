import {
  createServiceApp,
  probeHTTPDependency,
} from "@tazkle/service-kit";

type AutomationAppOptions = {
  projectCoreURL: URL;
  fetchImplementation?: typeof fetch;
};

export function createAutomationApp({
  projectCoreURL,
  fetchImplementation = fetch,
}: AutomationAppOptions) {
  const app = createServiceApp({
    service: "automation",
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
      service: "automation",
      authority: "automation",
      writesDomain: false,
      externalEgress: false,
    });
  });

  app.post("/internal/jobs", (context) => {
    return context.json(
      {
        error: {
          code: "QUEUE_NOT_CONFIGURED",
          message: "La cola de trabajos todavía no está configurada.",
          requestId: context.get("requestId"),
        },
      },
      503,
    );
  });

  return app;
}

import {
  requireInternalServiceURL,
  startService,
} from "@tazkle/service-kit";
import { createAutomationApp } from "./app.js";

const app = createAutomationApp({
  projectCoreURL: requireInternalServiceURL(
    process.env.PROJECT_CORE_URL,
    "PROJECT_CORE_URL",
  ),
});

startService(app, "automation");

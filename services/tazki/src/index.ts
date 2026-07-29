import {
  requireInternalServiceURL,
  startService,
} from "@tazkle/service-kit";
import { createTazkiApp } from "./app.js";

const app = createTazkiApp({
  projectCoreURL: requireInternalServiceURL(
    process.env.PROJECT_CORE_URL,
    "PROJECT_CORE_URL",
  ),
});

startService(app, "tazki");

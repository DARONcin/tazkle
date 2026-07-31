import { startService } from "@tazkle/service-kit";
import { createIdentityApp } from "./app.js";
import { createIdentityAuth } from "./auth.js";
import {
  enabledSocialProviders,
  identityConfigurationFromEnvironment,
} from "./config.js";
import { createIdentityDatabase } from "./database.js";

const configuration = identityConfigurationFromEnvironment();
const database = createIdentityDatabase(configuration);
const auth = createIdentityAuth(configuration, database.pool);
const app = createIdentityApp({
  auth,
  readiness: database.probe,
  socialProviders: enabledSocialProviders(configuration),
  accountDeletion: {
    userExists: database.userExists,
  },
});

startService(app, "identity");

const closeDatabase = (): void => {
  void database.close();
};

process.once("SIGINT", closeDatabase);
process.once("SIGTERM", closeDatabase);

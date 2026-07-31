import { readSecretValue, startService } from "@tazkle/service-kit";
import { createProjectCoreApp } from "./app.js";
import { createDatabaseConnection } from "./database.js";
import { createInternalActorVerifier } from "./identity.js";

const database = createDatabaseConnection(process.env);
const app = createProjectCoreApp({
  databaseProbe: database.probe,
  actorVerifier: createInternalActorVerifier(
    readSecretValue(
      process.env.INTERNAL_IDENTITY_SECRET,
      process.env.INTERNAL_IDENTITY_SECRET_FILE,
      "Internal identity secret",
    ),
  ),
  projects: database.projects,
  graph: database.graph,
  members: database.members,
});

startService(app, "project-core");

const closeDatabase = (): void => {
  void database.close();
};
process.once("SIGINT", closeDatabase);
process.once("SIGTERM", closeDatabase);

import { createIdentityAuth } from "./auth.js";
import { identityConfigurationFromEnvironment } from "./config.js";
import { createIdentityDatabase } from "./database.js";

const configuration = identityConfigurationFromEnvironment();
const database = createIdentityDatabase(configuration);

export const auth = createIdentityAuth(configuration, database.pool);

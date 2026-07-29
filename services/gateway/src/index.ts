import { readSecretValue, startService } from "@tazkle/service-kit";
import { createGatewayApp, gatewayURLsFromEnvironment } from "./app.js";
import {
  createInternalActorSigner,
  createOIDCAccessTokenVerifier,
  oidcConfigurationFromEnvironment,
} from "./authentication.js";

const app = createGatewayApp({
  urls: gatewayURLsFromEnvironment(),
  accessTokens: createOIDCAccessTokenVerifier(
    oidcConfigurationFromEnvironment(),
  ),
  internalActors: createInternalActorSigner(
    readSecretValue(
      process.env.INTERNAL_IDENTITY_SECRET,
      process.env.INTERNAL_IDENTITY_SECRET_FILE,
      "Internal identity secret",
    ),
  ),
});

startService(app, "gateway");

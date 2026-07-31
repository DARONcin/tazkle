import { oauthProvider } from "@better-auth/oauth-provider";
import { betterAuth } from "better-auth";
import { emailOTP, jwt, twoFactor } from "better-auth/plugins";
import type { Pool } from "pg";
import type { IdentityConfiguration } from "./config.js";
import {
  createAuthenticationEmailSender,
  type AuthenticationEmailSender,
} from "./email.js";

export const authorizationCodeLifetimeSeconds = 60 * 10;

export function createIdentityAuth(
  configuration: IdentityConfiguration,
  database: Pool,
  emailSender: AuthenticationEmailSender =
    createAuthenticationEmailSender(configuration),
) {
  const google = configuration.socialProviders.google;
  const microsoft = configuration.socialProviders.microsoft;

  return betterAuth({
    appName: "Tazkle",
    baseURL: configuration.publicBaseURL.toString(),
    basePath: configuration.basePath,
    secret: configuration.secret,
    database,
    emailAndPassword: {
      enabled: true,
      minPasswordLength: 12,
      maxPasswordLength: 128,
      requireEmailVerification: true,
    },
    emailVerification: {
      sendOnSignUp: false,
      sendOnSignIn: false,
      autoSignInAfterVerification: true,
    },
    user: {
      deleteUser: {
        enabled: true,
      },
    },
    socialProviders: {
      ...(google
        ? {
            google: {
              clientId: google.clientID,
              clientSecret: google.clientSecret,
              prompt: "select_account" as const,
            },
          }
        : {}),
      ...(microsoft
        ? {
            microsoft: {
              clientId: microsoft.clientID,
              clientSecret: microsoft.clientSecret,
              tenantId: microsoft.tenantID,
              authority: "https://login.microsoftonline.com",
              prompt: "select_account" as const,
            },
          }
        : {}),
    },
    session: {
      expiresIn: 60 * 60 * 24 * 30,
      updateAge: 60 * 60 * 24,
      cookieCache: {
        enabled: false,
      },
    },
    rateLimit: {
      enabled: true,
      storage: "database",
      window: 60,
      max: 60,
      customRules: {
        "/sign-in/email": {
          window: 60,
          max: 10,
        },
        "/sign-up/email": {
          window: 60 * 10,
          max: 5,
        },
      },
    },
    trustedOrigins: [
      configuration.publicOrigin,
      configuration.macOSClient.redirectURI,
    ],
    advanced: {
      cookiePrefix: "tazkle",
      useSecureCookies: configuration.secureCookies,
      disableCSRFCheck: false,
      disableOriginCheck: false,
      ipAddress: {
        ipAddressHeaders: ["x-tazkle-client-ip"],
      },
    },
    plugins: [
      emailOTP({
        async sendVerificationOTP({ email, otp, type }) {
          await emailSender.sendOTP({
            to: email,
            otp,
            kind:
              type === "sign-in"
                ? "two-factor"
                : type,
          });
        },
        otpLength: 6,
        expiresIn: 5 * 60,
        allowedAttempts: 5,
        storeOTP: "hashed",
        resendStrategy: "rotate",
        disableSignUp: true,
        overrideDefaultEmailVerification: true,
        rateLimit: {
          window: 60,
          max: 3,
        },
      }),
      twoFactor({
        issuer: "Tazkle",
        skipVerificationOnEnable: true,
        twoFactorCookieMaxAge: 10 * 60,
        trustDeviceMaxAge: 30 * 24 * 60 * 60,
        totpOptions: {
          disable: true,
        },
        otpOptions: {
          async sendOTP({ user, otp }) {
            await emailSender.sendOTP({
              to: user.email,
              otp,
              kind: "two-factor",
            });
          },
          digits: 6,
          period: 5,
          allowedAttempts: 5,
          storeOTP: "hashed",
        },
        backupCodeOptions: {
          amount: 8,
          length: 10,
          storeBackupCodes: "encrypted",
        },
        accountLockout: {
          enabled: true,
          maxFailedAttempts: 5,
          durationSeconds: 15 * 60,
        },
      }),
      jwt({
        disableSettingJwtHeader: true,
        jwks: {
          jwksPath: "/jwks",
          keyPairConfig: {
            alg: "ES256",
          },
          rotationInterval: 60 * 60 * 24 * 30,
          gracePeriod: 60 * 60 * 24 * 30,
        },
        jwt: {
          issuer: configuration.publicBaseURL.toString(),
          audience: configuration.audience,
          expirationTime: "15m",
        },
      }),
      oauthProvider({
        loginPage: "/sign-in",
        consentPage: "/consent",
        signup: {
          page: "/sign-up",
        },
        scopes: ["openid", "profile", "email", "offline_access"],
        validAudiences: [configuration.audience],
        accessTokenExpiresIn: 60 * 15,
        idTokenExpiresIn: 60 * 15,
        refreshTokenExpiresIn: 60 * 60 * 24 * 30,
        codeExpiresIn: authorizationCodeLifetimeSeconds,
        grantTypes: ["authorization_code", "refresh_token"],
        allowDynamicClientRegistration: false,
        allowUnauthenticatedClientRegistration: false,
        allowPublicClientPrelogin: false,
        storeTokens: "hashed",
        storeClientSecret: "hashed",
        requirePKCE: true,
        silenceWarnings: {
          oauthAuthServerConfig: true,
        },
        customAccessTokenClaims: ({ user }) => {
          if (!user) {
            return {};
          }
          return {
            name: user.name,
            email: user.email,
            email_verified: user.emailVerified,
          };
        },
      }),
    ],
  });
}

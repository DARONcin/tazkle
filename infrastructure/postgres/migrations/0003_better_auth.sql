-- Generated with Better Auth CLI 1.6.25, then scoped to the dedicated auth
-- schema and least-privilege runtime role.
create schema if not exists auth;
revoke all on schema auth from public;
revoke all on schema auth from tazkle_app;
grant usage on schema auth to tazkle_identity;
set local search_path = auth, public;

create table "user" ("id" text not null primary key, "name" text not null, "email" text not null unique, "emailVerified" boolean not null, "image" text, "createdAt" timestamptz default CURRENT_TIMESTAMP not null, "updatedAt" timestamptz default CURRENT_TIMESTAMP not null);

create table "session" ("id" text not null primary key, "expiresAt" timestamptz not null, "token" text not null unique, "createdAt" timestamptz default CURRENT_TIMESTAMP not null, "updatedAt" timestamptz not null, "ipAddress" text, "userAgent" text, "userId" text not null references "user" ("id") on delete cascade);

create table "account" ("id" text not null primary key, "accountId" text not null, "providerId" text not null, "userId" text not null references "user" ("id") on delete cascade, "accessToken" text, "refreshToken" text, "idToken" text, "accessTokenExpiresAt" timestamptz, "refreshTokenExpiresAt" timestamptz, "scope" text, "password" text, "createdAt" timestamptz default CURRENT_TIMESTAMP not null, "updatedAt" timestamptz not null);

create table "verification" ("id" text not null primary key, "identifier" text not null, "value" text not null, "expiresAt" timestamptz not null, "createdAt" timestamptz default CURRENT_TIMESTAMP not null, "updatedAt" timestamptz default CURRENT_TIMESTAMP not null);

create table "jwks" ("id" text not null primary key, "publicKey" text not null, "privateKey" text not null, "createdAt" timestamptz not null, "expiresAt" timestamptz);

create table "oauthClient" ("id" text not null primary key, "clientId" text not null unique, "clientSecret" text, "disabled" boolean, "skipConsent" boolean, "enableEndSession" boolean, "subjectType" text, "scopes" jsonb, "userId" text references "user" ("id") on delete cascade, "createdAt" timestamptz, "updatedAt" timestamptz, "name" text, "uri" text, "icon" text, "contacts" jsonb, "tos" text, "policy" text, "softwareId" text, "softwareVersion" text, "softwareStatement" text, "redirectUris" jsonb not null, "postLogoutRedirectUris" jsonb, "tokenEndpointAuthMethod" text, "grantTypes" jsonb, "responseTypes" jsonb, "public" boolean, "type" text, "requirePKCE" boolean, "referenceId" text, "metadata" jsonb);

create table "oauthRefreshToken" ("id" text not null primary key, "token" text not null unique, "clientId" text not null references "oauthClient" ("clientId") on delete cascade, "sessionId" text references "session" ("id") on delete set null, "userId" text not null references "user" ("id") on delete cascade, "referenceId" text, "expiresAt" timestamptz not null, "createdAt" timestamptz not null, "revoked" timestamptz, "authTime" timestamptz, "scopes" jsonb not null);

create table "oauthAccessToken" ("id" text not null primary key, "token" text not null unique, "clientId" text not null references "oauthClient" ("clientId") on delete cascade, "sessionId" text references "session" ("id") on delete set null, "userId" text references "user" ("id") on delete cascade, "referenceId" text, "refreshId" text references "oauthRefreshToken" ("id") on delete cascade, "expiresAt" timestamptz not null, "createdAt" timestamptz not null, "scopes" jsonb not null);

create table "oauthConsent" ("id" text not null primary key, "clientId" text not null references "oauthClient" ("clientId") on delete cascade, "userId" text references "user" ("id") on delete cascade, "referenceId" text, "scopes" jsonb not null, "createdAt" timestamptz not null, "updatedAt" timestamptz not null);

create table "rateLimit" ("id" text not null primary key, "key" text not null unique, "count" integer not null, "lastRequest" bigint not null);

create index "session_userId_idx" on "session" ("userId");

create index "account_userId_idx" on "account" ("userId");

create index "verification_identifier_idx" on "verification" ("identifier");

create index "oauthClient_userId_idx" on "oauthClient" ("userId");

create index "oauthRefreshToken_clientId_idx" on "oauthRefreshToken" ("clientId");

create index "oauthRefreshToken_sessionId_idx" on "oauthRefreshToken" ("sessionId");

create index "oauthRefreshToken_userId_idx" on "oauthRefreshToken" ("userId");

create index "oauthAccessToken_clientId_idx" on "oauthAccessToken" ("clientId");

create index "oauthAccessToken_sessionId_idx" on "oauthAccessToken" ("sessionId");

create index "oauthAccessToken_userId_idx" on "oauthAccessToken" ("userId");

create index "oauthAccessToken_refreshId_idx" on "oauthAccessToken" ("refreshId");

create index "oauthConsent_clientId_idx" on "oauthConsent" ("clientId");

create index "oauthConsent_userId_idx" on "oauthConsent" ("userId");

insert into "oauthClient" (
  "id",
  "clientId",
  "clientSecret",
  "disabled",
  "skipConsent",
  "enableEndSession",
  "subjectType",
  "scopes",
  "createdAt",
  "updatedAt",
  "name",
  "redirectUris",
  "tokenEndpointAuthMethod",
  "grantTypes",
  "responseTypes",
  "public",
  "type",
  "requirePKCE"
) values (
  'tazkle_macos_public_v1',
  'tazkle-macos',
  null,
  false,
  false,
  true,
  'public',
  '["openid","profile","email","offline_access"]'::jsonb,
  now(),
  now(),
  'Tazkle para macOS',
  '["app.tazkle.desktop:/oauth/callback"]'::jsonb,
  'none',
  '["authorization_code","refresh_token"]'::jsonb,
  '["code"]'::jsonb,
  true,
  'native',
  true
);

revoke all on all tables in schema auth from public;
revoke all on all tables in schema auth from tazkle_app;
grant select, insert, update, delete on all tables in schema auth to tazkle_identity;
alter default privileges in schema auth
  grant select, insert, update, delete on tables to tazkle_identity;

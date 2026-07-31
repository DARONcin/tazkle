-- Better Auth 1.6.25 email verification and two-factor schema.
set local search_path = auth, public;

alter table auth."user"
  add column "twoFactorEnabled" boolean not null default false;

create table auth."twoFactor" (
  "id" text not null primary key,
  "secret" text not null,
  "backupCodes" text not null,
  "userId" text not null references auth."user" ("id") on delete cascade,
  "verified" boolean not null default true,
  "failedVerificationCount" integer not null default 0,
  "lockedUntil" timestamptz
);

create index "twoFactor_secret_idx"
  on auth."twoFactor" ("secret");

create index "twoFactor_userId_idx"
  on auth."twoFactor" ("userId");

revoke all on auth."twoFactor" from public;
revoke all on auth."twoFactor" from tazkle_app;
grant select, insert, update, delete
  on auth."twoFactor"
  to tazkle_identity;

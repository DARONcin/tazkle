FROM node:22.19.0-alpine3.21 AS build

WORKDIR /workspace

COPY package.json package-lock.json tsconfig.base.json ./
COPY packages/platform-contracts/package.json packages/platform-contracts/package.json
COPY packages/service-kit/package.json packages/service-kit/package.json
COPY services/identity/package.json services/identity/package.json
COPY services/gateway/package.json services/gateway/package.json
COPY services/project-core/package.json services/project-core/package.json
COPY services/tazki/package.json services/tazki/package.json
COPY services/automation/package.json services/automation/package.json

RUN npm ci

COPY packages/platform-contracts packages/platform-contracts
COPY packages/service-kit packages/service-kit
COPY services/identity services/identity
COPY services/gateway services/gateway
COPY services/project-core services/project-core
COPY services/tazki services/tazki
COPY services/automation services/automation

RUN npm run build:services

FROM node:22.19.0-alpine3.21 AS runtime

ENV NODE_ENV=production
WORKDIR /workspace

COPY package.json package-lock.json ./
COPY packages/platform-contracts/package.json packages/platform-contracts/package.json
COPY packages/service-kit/package.json packages/service-kit/package.json
COPY services/identity/package.json services/identity/package.json
COPY services/gateway/package.json services/gateway/package.json
COPY services/project-core/package.json services/project-core/package.json
COPY services/tazki/package.json services/tazki/package.json
COPY services/automation/package.json services/automation/package.json

RUN npm ci --omit=dev && npm cache clean --force

COPY --from=build /workspace/packages/platform-contracts/dist packages/platform-contracts/dist
COPY --from=build /workspace/packages/service-kit/dist packages/service-kit/dist
COPY --from=build /workspace/services/identity/dist services/identity/dist
COPY --from=build /workspace/services/gateway/dist services/gateway/dist
COPY --from=build /workspace/services/project-core/dist services/project-core/dist
COPY --from=build /workspace/services/tazki/dist services/tazki/dist
COPY --from=build /workspace/services/automation/dist services/automation/dist
COPY infrastructure/postgres/migrations infrastructure/postgres/migrations

USER node

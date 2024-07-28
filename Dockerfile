FROM --platform=linux/amd64 node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS build

# Disabling Telemetry
ENV NEXT_TELEMETRY_DISABLED 1
RUN apk add --no-cache libc6-compat curl python3 py3-pip
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libc6-compat curl python3 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


FROM base AS deps
WORKDIR /app

COPY package.json ./
COPY pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
COPY ./databases ./databases
RUN ls -lash ./databases

RUN if [ -f ".pyra/migrate.sh" ]; then \
        chmod +x .pyra/migrate.sh && \
        ./.pyra/migrate.sh && \
        pnpm run build; \
    else \
        pnpm run build; \
    fi


FROM base AS runner
RUN corepack enable

ENV NODE_ENV production

# Set environment variables for UID and GID
ARG UID=1001
ARG GID=1001

# Create group and user with the specific IDs
RUN groupadd -g ${GID} nodejs
RUN    useradd -m -u ${UID} -g nodejs nextjs

COPY --from=builder /app/drizzle ./drizzle
COPY --from=builder /app/drizzle.config.ts ./drizzle.config.ts
COPY --from=builder /app/src/models ./src/models
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.pyra ./.pyra
RUN mkdir .next
RUN mkdir -p /data && chown -R nextjs:nodejs /data
RUN chown nextjs:nodejs .
RUN chown nextjs:nodejs .next

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"
ENV NODE_ENV production

CMD ["node", "server.js"]
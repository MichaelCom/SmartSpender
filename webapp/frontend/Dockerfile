# ---- Build stage ----
FROM node:20-alpine AS build
WORKDIR /app

# Install deps (cached unless package manifests change)
COPY package.json package-lock.json* ./
RUN npm install

# Build the app. VITE_API_URL is baked at build time (Vite inlines env vars),
# so the orchestrator can pass --build-arg VITE_API_URL=... in compose.
ARG VITE_API_URL=http://localhost:4000
ENV VITE_API_URL=${VITE_API_URL}

COPY . .
RUN npm run build

# ---- Runtime stage ----
# Serve the static build with Vite's preview server on 5173.
FROM node:20-alpine AS runtime
WORKDIR /app

COPY --from=build /app/package.json /app/package-lock.json* ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/vite.config.ts ./vite.config.ts

EXPOSE 5173
# --host binds 0.0.0.0 so the container is reachable from the host.
CMD ["npm", "run", "preview"]

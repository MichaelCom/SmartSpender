# SmartSpender API — Node 20 + TypeScript, listens on 4000.
# DB connection comes from env (DATABASE_URL or discrete POSTGRES_* vars).
# Startup performs a wait-for-db retry (see src/db/pool.ts).
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=4000
COPY package.json package-lock.json* ./
RUN npm install --omit=dev
COPY --from=build /app/dist ./dist
EXPOSE 4000
CMD ["node", "dist/index.js"]

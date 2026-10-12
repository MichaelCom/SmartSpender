import { createApp } from "./app";
import { pool, waitForDb } from "./db/pool";

const PORT = Number(process.env.PORT ?? "4000");

async function main() {
  // Wait-for-db retry so the api survives compose start-up races.
  await waitForDb();
  const app = createApp();
  const server = app.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`[api] SmartSpender API listening on :${PORT}`);
  });

  const shutdown = async (signal: string) => {
    // eslint-disable-next-line no-console
    console.log(`[api] ${signal} received, shutting down`);
    server.close(() => undefined);
    await pool.end().catch(() => undefined);
    process.exit(0);
  };
  process.on("SIGTERM", () => void shutdown("SIGTERM"));
  process.on("SIGINT", () => void shutdown("SIGINT"));
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("[api] fatal startup error:", err);
  process.exit(1);
});

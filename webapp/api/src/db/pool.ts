import { Pool, PoolConfig } from "pg";

// Builds a pg Pool from either DATABASE_URL or discrete POSTGRES_* env vars.
function buildConfig(): PoolConfig {
  const url = process.env.DATABASE_URL;
  if (url && url.trim() !== "") {
    return { connectionString: url };
  }
  return {
    host: process.env.POSTGRES_HOST ?? "db",
    port: Number(process.env.POSTGRES_PORT ?? "5432"),
    user: process.env.POSTGRES_USER ?? "smartspender",
    password: process.env.POSTGRES_PASSWORD ?? "smartspender",
    database: process.env.POSTGRES_DB ?? "smartspender",
  };
}

export const pool = new Pool(buildConfig());

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Waits for Postgres to accept connections, retrying with backoff. Used on
 * startup so the api survives `docker compose up` races before db is ready.
 */
export async function waitForDb(opts: {
  retries?: number;
  delayMs?: number;
} = {}): Promise<void> {
  const retries = opts.retries ?? 30;
  const delayMs = opts.delayMs ?? 2000;
  let lastErr: unknown;
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const client = await pool.connect();
      try {
        await client.query("SELECT 1");
        return;
      } finally {
        client.release();
      }
    } catch (err) {
      lastErr = err;
      // eslint-disable-next-line no-console
      console.log(
        `[db] not ready (attempt ${attempt}/${retries}): ${
          (err as Error).message
        }`
      );
      await sleep(delayMs);
    }
  }
  throw new Error(
    `Database never became ready after ${retries} attempts: ${
      (lastErr as Error)?.message
    }`
  );
}

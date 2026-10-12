import { Request, Response } from "express";

// Shared helpers for route handlers.

export class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export function badRequest(message: string): HttpError {
  return new HttpError(400, message);
}
export function notFound(message = "Not found"): HttpError {
  return new HttpError(404, message);
}

/** Wrap an async handler so thrown errors become JSON error responses. */
export function wrap(
  fn: (req: Request, res: Response) => Promise<void> | void
) {
  return async (req: Request, res: Response) => {
    try {
      await fn(req, res);
    } catch (err) {
      if (err instanceof HttpError) {
        res.status(err.status).json({ error: err.message });
        return;
      }
      // eslint-disable-next-line no-console
      console.error(err);
      res.status(500).json({ error: (err as Error).message ?? "Server error" });
    }
  };
}

export function parseId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw badRequest(`Invalid id: ${raw}`);
  }
  return id;
}

export function parseType(raw: unknown): "income" | "expense" | undefined {
  if (raw == null) return undefined;
  if (raw === "income" || raw === "expense") return raw;
  throw badRequest(`Invalid type: ${String(raw)}`);
}

export function parseFrequency(
  raw: unknown
): "daily" | "weekly" | "monthly" | "yearly" {
  if (
    raw === "daily" ||
    raw === "weekly" ||
    raw === "monthly" ||
    raw === "yearly"
  )
    return raw;
  throw badRequest(`Invalid frequency: ${String(raw)}`);
}

export function parsePeriod(raw: unknown): "weekly" | "monthly" | "yearly" {
  if (raw === "weekly" || raw === "monthly" || raw === "yearly") return raw;
  throw badRequest(`Invalid period: ${String(raw)}`);
}

/** Parse an ISO date string into a Date, throwing 400 on invalid input. */
export function parseDate(raw: unknown, field: string): Date {
  if (typeof raw !== "string" || raw.trim() === "") {
    throw badRequest(`Missing or invalid ${field}`);
  }
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) {
    throw badRequest(`Invalid ${field}: ${raw}`);
  }
  return d;
}

export function parseOptionalDate(
  raw: unknown,
  field: string
): Date | null {
  if (raw == null || raw === "") return null;
  return parseDate(raw, field);
}

export function requireNumber(raw: unknown, field: string): number {
  const n = Number(raw);
  if (raw == null || raw === "" || Number.isNaN(n)) {
    throw badRequest(`Missing or invalid ${field}`);
  }
  return n;
}

/** Optional ISO date from a querystring value (string or undefined). */
export function queryDate(raw: unknown): Date | undefined {
  if (raw == null || raw === "") return undefined;
  const d = new Date(String(raw));
  if (Number.isNaN(d.getTime())) {
    throw badRequest(`Invalid date in query: ${String(raw)}`);
  }
  return d;
}

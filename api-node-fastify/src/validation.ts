import { z } from "zod";
import { badRequest, notFound } from "./errors.js";

const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;
const MAX_DESCRIPTION_LENGTH = 255;

const PAGINATION_ERROR =
  "'page' must be >= 1 and 'page_size' must be between 1 and 100";

// Missing or empty values fall back to the default; anything else must be a
// plain positive integer within range.
const positiveIntParam = (fallback: number, max: number) =>
  z
    .string()
    .regex(/^\d*$/)
    .optional()
    .transform((v) => (v ? Number(v) : fallback))
    .pipe(z.number().int().min(1).max(max));

const paginationSchema = z.object({
  page: positiveIntParam(1, 2 ** 32 - 1),
  page_size: positiveIntParam(DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE),
});

export type Pagination = z.infer<typeof paginationSchema>;

export function parsePagination(query: unknown): Pagination {
  const result = paginationSchema.safeParse(query);
  if (!result.success) throw badRequest(PAGINATION_ERROR);
  return result.data;
}

export function pageBounds({ page, page_size }: Pagination) {
  return { limit: page_size, offset: (page - 1) * page_size };
}

/**
 * Numeric path id. Non-numeric ids can never match a resource, so they are
 * reported as 404 rather than 400.
 */
export function parseId(raw: string | undefined): number {
  const id = Number(raw);
  if (!raw || !/^-?\d+$/.test(raw) || !Number.isSafeInteger(id)) {
    throw notFound("not found");
  }
  return id;
}

// Validated field by field; any problem with a field gets that field's message.
const FIELD_ERRORS: Record<string, string> = {
  type: "'type' must be either 'credit' or 'debit'",
  amount: "'amount' must be a positive integer (minor units, e.g. cents)",
  description: `'description' must be a string of at most ${MAX_DESCRIPTION_LENGTH} characters`,
};

const newTransactionSchema = z.object({
  type: z.enum(["credit", "debit"]),
  amount: z.number().int().positive().max(Number.MAX_SAFE_INTEGER),
  description: z
    .string()
    // Count code points, not UTF-16 units, to match the VARCHAR limit.
    .refine((s) => [...s].length <= MAX_DESCRIPTION_LENGTH)
    .nullish()
    .transform((s) => s || null),
});

export type NewTransaction = z.infer<typeof newTransactionSchema>;

export function parseNewTransaction(body: unknown): NewTransaction {
  const result = newTransactionSchema.safeParse(body);
  if (!result.success) {
    // Issues come in field order, so the first one is the one to report.
    const field = String(result.error.issues[0]?.path[0] ?? "");
    throw badRequest(FIELD_ERRORS[field] ?? "request body must be a JSON object");
  }
  return result.data;
}

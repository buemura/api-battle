import { t } from "elysia";
import { badRequest, notFound } from "./errors";

const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;
const MAX_PAGE = 2 ** 32 - 1;
const MAX_DESCRIPTION_LENGTH = 255;

export const PAGINATION_ERROR =
  "'page' must be >= 1 and 'page_size' must be between 1 and 100";

// Query values stay strings so missing or empty ones can fall back to the
// default; anything else must be a plain integer, range-checked below.
const digits = t.Optional(t.String({ pattern: "^\\d*$", error: PAGINATION_ERROR }));

export const paginationQuery = t.Object(
  { page: digits, page_size: digits },
  { error: PAGINATION_ERROR },
);

export type Pagination = { page: number; page_size: number };

export function parsePagination(query: { page?: string; page_size?: string }): Pagination {
  const page = query.page ? Number(query.page) : 1;
  const page_size = query.page_size ? Number(query.page_size) : DEFAULT_PAGE_SIZE;
  if (page < 1 || page > MAX_PAGE || page_size < 1 || page_size > MAX_PAGE_SIZE) {
    throw badRequest(PAGINATION_ERROR);
  }
  return { page, page_size };
}

export function pageBounds({ page, page_size }: Pagination) {
  return { limit: page_size, offset: (page - 1) * page_size };
}

/**
 * Numeric path id. Non-numeric ids can never match a resource, so they are
 * reported as 404 rather than 400.
 */
export function parseId(raw: string): number {
  const id = Number(raw);
  if (!/^-?\d+$/.test(raw) || !Number.isSafeInteger(id)) {
    throw notFound("not found");
  }
  return id;
}

// Validated field by field; any problem with a field gets that field's message.
const DESCRIPTION_ERROR = `'description' must be a string of at most ${MAX_DESCRIPTION_LENGTH} characters`;

export const newTransactionBody = t.Object(
  {
    type: t.UnionEnum(["credit", "debit"], {
      error: "'type' must be either 'credit' or 'debit'",
    }),
    // Not t.Integer: Elysia's variant also accepts numeric strings.
    amount: t.Number({
      multipleOf: 1,
      minimum: 1,
      maximum: Number.MAX_SAFE_INTEGER,
      error: "'amount' must be a positive integer (minor units, e.g. cents)",
    }),
    description: t.Optional(t.Nullable(t.String({ error: DESCRIPTION_ERROR }), { error: DESCRIPTION_ERROR })),
  },
  { error: "request body must be a JSON object" },
);

/**
 * Parses the body as JSON whatever its content type, and rejects anything but
 * an object up front: Elysia replaces a non-object body with defaults before
 * validating it, which would misreport it as a field error.
 */
export async function parseJsonObject({ request }: { request: Request }): Promise<unknown> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    throw badRequest("request body must be JSON");
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    throw badRequest("request body must be a JSON object");
  }
  return body;
}

export type NewTransaction = {
  type: "credit" | "debit";
  amount: number;
  description: string | null;
};

export function normalizeNewTransaction(body: typeof newTransactionBody.static): NewTransaction {
  const description = body.description || null;
  // Count code points, not UTF-16 units, to match the VARCHAR limit.
  if (description && [...description].length > MAX_DESCRIPTION_LENGTH) {
    throw badRequest(DESCRIPTION_ERROR);
  }
  return { type: body.type, amount: body.amount, description };
}

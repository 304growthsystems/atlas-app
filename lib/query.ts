import "server-only";

export class ApplicationQueryError extends Error {
  constructor(public readonly operation: string) { super("APPLICATION_QUERY_FAILED"); this.name = "ApplicationQueryError"; }
}

export function requireQueryData<T>(operation: string, result: { data: T | null; error: unknown }): T {
  if (result.error) {
    const error = result.error as { code?: unknown; message?: unknown };
    console.error("Supabase query failed", { operation, code: error?.code, message: error?.message });
    throw new ApplicationQueryError(operation);
  }
  return result.data as T;
}

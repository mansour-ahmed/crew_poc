import { buildCSRFHeaders } from "../../ash_rpc";

export type Mutable<T extends readonly unknown[]> = [...T];

export async function unwrap<T>(
  label: string,
  call: Promise<{ success: true; data: T } | { success: false }>,
): Promise<T> {
  const result = await call;
  if (!result.success) throw new Error(`Failed to ${label}`);
  return result.data;
}

export const fetchHeaders = () => ({ headers: buildCSRFHeaders() });

import { z } from "zod";
import { dollarsToCents } from "@/lib/money";

const optionalText = z.string().trim().max(200).optional().default("");
const authEmail = z.string().trim().max(320, "Email is too long.").pipe(z.email("Enter a valid email."));
const authPassword = z.string().min(1, "Password is required.").min(8, "Password must be at least 8 characters.").max(128, "Password is too long.");
export const loginSchema = z.object({ email: authEmail, password: authPassword });
export const signupSchema = z.object({ email: authEmail, password: authPassword });

export function codePointLength(value: string): number {
  return Array.from(value).length;
}

export function isValidAdvertiserEmail(value: string): boolean {
  const email = value.trim();
  if (codePointLength(email) > 254 || /\s/.test(email)) return false;

  const separator = email.indexOf("@");
  if (separator <= 0 || separator !== email.lastIndexOf("@")) return false;

  const local = email.slice(0, separator);
  const domain = email.slice(separator + 1);
  if (codePointLength(local) < 1 || codePointLength(local) > 64 || codePointLength(domain) < 1 || codePointLength(domain) > 253) return false;
  if (local.startsWith(".") || local.endsWith(".") || local.includes("..")) return false;

  const labels = domain.split(".");
  return labels.length >= 2 && labels.every(
    (label) => codePointLength(label) >= 1 && codePointLength(label) <= 63 && /^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$/.test(label),
  );
}

const advertiserEmail = z.string().transform((value) => value.trim()).refine(
  (value) => value === "" || isValidAdvertiserEmail(value),
  "Enter a valid email.",
);
export const advertiserSchema = z.object({
  businessName: z.string().trim().min(1, "Business name is required.").max(160),
  category: z.string().trim().min(1, "Category is required.").max(80),
  contactName: z.string().trim().min(1).max(160), email: advertiserEmail, phone: z.string().trim().max(40),
  addressLine1: z.string().trim().min(1).max(200), addressLine2: optionalText, city: z.string().trim().min(1).max(100), state: z.string().trim().min(1).max(100), postalCode: z.string().trim().min(1).max(20),
});
const date = z.iso.date();
const canonicalInteger = (minimum: number, maximum: number) => z.string()
  .regex(/^(0|[1-9]\d*)$/, "Enter a whole number using digits only.")
  .transform(Number)
  .pipe(z.number().int().min(minimum).max(maximum));
export const campaignSchema = z.object({
  name: z.string().trim().min(1).max(160), territory: z.string().trim().min(1).max(160), productType: z.string().trim().min(1).max(100),
  publicationDate: date, salesDeadline: date, artworkDeadline: date, proofDeadline: date, printDeadline: date,
  mailingQuantity: canonicalInteger(0, 10_000_000), slotCount: canonicalInteger(1, 500),
  estimatedPrintingCost: z.string().transform((v, ctx) => money(v, ctx)).pipe(z.number().int().min(0).max(100_000_000_000)), estimatedPostageCost: z.string().transform((v, ctx) => money(v, ctx)).pipe(z.number().int().min(0).max(100_000_000_000)),
  standardSlotPrice: z.string().transform((v, ctx) => money(v, ctx)).pipe(z.number().int().min(0).max(100_000_000_000)), categoryExclusivity: z.boolean(),
}).superRefine((v, ctx) => {
  const dates = [v.salesDeadline, v.artworkDeadline, v.proofDeadline, v.printDeadline, v.publicationDate];
  if (dates.some((d, i) => i > 0 && d < dates[i - 1])) ctx.addIssue({ code: "custom", path: ["salesDeadline"], message: "Deadlines must follow sales, artwork, proof, print, publication order." });
});
function money(v: string, ctx: z.RefinementCtx) { try { return dollarsToCents(v); } catch (e) { ctx.addIssue({ code: "custom", message: (e as Error).message }); return z.NEVER; } }
export const reservationSchema = z.object({ slotId: z.uuid(), advertiserId: z.uuid(), salePrice: z.string().transform((v, ctx) => money(v, ctx)) });
export type ActionState = { success?: boolean; message?: string; errors?: Record<string, string[]> };

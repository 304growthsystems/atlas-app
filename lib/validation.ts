import { z } from "zod";

import { dollarsToCents } from "@/lib/money";

const optionalText = z.string().trim().max(200).optional().default("");

const authEmail = z
  .string()
  .trim()
  .max(320, "Email is too long.")
  .pipe(z.email("Enter a valid email."));

const authPassword = z
  .string()
  .min(1, "Password is required.")
  .min(8, "Password must be at least 8 characters.")
  .max(128, "Password is too long.");

export const loginSchema = z.object({
  email: authEmail,
  password: authPassword,
});

export const signupSchema = z.object({
  email: authEmail,
  password: authPassword,
});

export function codePointLength(value: string): number {
  return Array.from(value).length;
}

export function isValidAdvertiserEmail(value: string): boolean {
  const email = value.trim();

  if (codePointLength(email) > 254 || /\s/.test(email)) {
    return false;
  }

  const separator = email.indexOf("@");

  if (separator <= 0 || separator !== email.lastIndexOf("@")) {
    return false;
  }

  const local = email.slice(0, separator);
  const domain = email.slice(separator + 1);

  if (
    codePointLength(local) < 1 ||
    codePointLength(local) > 64 ||
    codePointLength(domain) < 1 ||
    codePointLength(domain) > 253
  ) {
    return false;
  }

  if (
    local.startsWith(".") ||
    local.endsWith(".") ||
    local.includes("..")
  ) {
    return false;
  }

  const labels = domain.split(".");

  return (
    labels.length >= 2 &&
    labels.every(
      (label) =>
        codePointLength(label) >= 1 &&
        codePointLength(label) <= 63 &&
        /^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$/.test(label),
    )
  );
}

const advertiserEmail = z
  .string()
  .transform((value) => value.trim())
  .refine(
    (value) => value === "" || isValidAdvertiserEmail(value),
    "Enter a valid email.",
  );

export const advertiserSchema = z.object({
  businessName: z
    .string()
    .trim()
    .min(1, "Business name is required.")
    .max(160),

  category: z
    .string()
    .trim()
    .min(1, "Category is required.")
    .max(80),

  contactName: z.string().trim().min(1).max(160),

  email: advertiserEmail,

  phone: z.string().trim().max(40),

  addressLine1: z.string().trim().min(1).max(200),

  addressLine2: optionalText,

  city: z.string().trim().min(1).max(100),

  state: z.string().trim().min(1).max(100),

  postalCode: z.string().trim().min(1).max(20),
});

const canonicalDate = z.iso.date();

const canonicalInteger = (minimum: number, maximum: number) =>
  z
    .string()
    .regex(
      /^(0|[1-9]\d*)$/,
      "Enter a whole number using digits only.",
    )
    .transform(Number)
    .pipe(z.number().int().min(minimum).max(maximum));

function money(value: string, context: z.RefinementCtx) {
  try {
    return dollarsToCents(value);
  } catch (error) {
    context.addIssue({
      code: "custom",
      message:
        error instanceof Error
          ? error.message
          : "Enter a valid dollar amount.",
    });

    return z.NEVER;
  }
}

export const campaignSchema = z
  .object({
    name: z
      .string()
      .trim()
      .min(1, "Campaign name is required.")
      .max(160),

    territory: z
      .string()
      .trim()
      .min(1, "Territory is required.")
      .max(160),

    productType: z
      .string()
      .trim()
      .min(1, "Product type is required.")
      .max(100),

    publicationDate: canonicalDate,
    salesDeadline: canonicalDate,
    artworkDeadline: canonicalDate,
    proofDeadline: canonicalDate,
    printDeadline: canonicalDate,

    mailingQuantity: canonicalInteger(0, 10_000_000),

    slotCount: canonicalInteger(1, 500),

    estimatedPrintingCost: z
      .string()
      .transform((value, context) => money(value, context))
      .pipe(
        z
          .number()
          .int()
          .min(0)
          .max(100_000_000_000),
      ),

    estimatedPostageCost: z
      .string()
      .transform((value, context) => money(value, context))
      .pipe(
        z
          .number()
          .int()
          .min(0)
          .max(100_000_000_000),
      ),

    standardSlotPrice: z
      .string()
      .transform((value, context) => money(value, context))
      .pipe(
        z
          .number()
          .int()
          .min(0)
          .max(100_000_000_000),
      ),

    categoryExclusivity: z.boolean(),
  })
  .superRefine((values, context) => {
    const dates = [
      ["salesDeadline", values.salesDeadline],
      ["artworkDeadline", values.artworkDeadline],
      ["proofDeadline", values.proofDeadline],
      ["printDeadline", values.printDeadline],
      ["publicationDate", values.publicationDate],
    ] as const;

    dates.slice(1).forEach(([field, value], index) => {
      const previousValue = dates[index][1];

      if (value < previousValue) {
        context.addIssue({
          code: "custom",
          path: [field],
          message:
            "Dates must follow sales, artwork, proof, print, then publication order.",
        });
      }
    });
  });

export const reservationSchema = z.object({
  slotId: z.uuid(),
  advertiserId: z.uuid(),

  salePrice: z
    .string()
    .transform((value, context) => money(value, context)),
});

export const cancellationSchema = z.object({
  placementId: z.uuid(),

  reason: z
    .string()
    .trim()
    .min(1, "A cancellation reason is required.")
    .max(500, "Cancellation reason must be 500 characters or fewer."),
});

/**
 * Advertiser record statuses.
 *
 * These are separate from Campaign statuses. Combining the two schemas caused
 * advertiser archive and restore requests to be rejected before reaching the
 * database.
 */
export const advertiserStatuses = [
  "active",
  "archived",
] as const;

export const advertiserStatusSchema = z.object({
  id: z.uuid(),

  status: z.enum(advertiserStatuses, {
    message: "Select a supported advertiser status.",
  }),
});

/**
 * Campaign lifecycle statuses.
 */
export const campaignStatuses = [
  "draft",
  "selling",
  "artwork_collection",
  "proofing",
  "ready_for_print",
  "sent_to_printer",
  "mailed_or_published",
  "completed",
  "canceled",
] as const;

export const campaignStatusSchema = z.object({
  id: z.uuid(),

  status: z.enum(campaignStatuses, {
    message: "Select a supported campaign status.",
  }),
});

// Backward-compatible name used by existing campaign validation tests.
export const statusSchema = campaignStatusSchema;

export const campaignCancellationSchema = z.object({
  campaignId: z.uuid(),

  reason: z
    .string()
    .trim()
    .min(1, "A cancellation reason is required.")
    .max(
      500,
      "Cancellation reason must be 500 characters or fewer.",
    ),
});

export type ActionState = {
  success?: boolean;
  message?: string;
  errors?: Record<string, string[]>;
  values?: Record<string, string | boolean>;
};
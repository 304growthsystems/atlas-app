export const MUTATION_ROLES = ["owner", "administrator", "sales_manager"] as const;
export type InternalRole = "owner"|"administrator"|"sales_manager"|"salesperson"|"designer"|"finance";
export function canManageFirstSlice(role: string): boolean { return (MUTATION_ROLES as readonly string[]).includes(role); }
export function isInternalRole(role: string): role is InternalRole { return role !== "advertiser" && ["owner","administrator","sales_manager","salesperson","designer","finance"].includes(role); }
export function safeErrorMessage(error: unknown): string {
  const code = typeof error === "object" && error && "code" in error ? String(error.code) : "";
  const message = typeof error === "object" && error && "message" in error ? String(error.message) : "";
  if (message.includes("DUPLICATE_ADVERTISER") || code === "23505") return "An advertiser with that name already exists in this organization.";
  if (message.includes("CATEGORY_CONFLICT")) return "Another advertiser in this category already has an active placement in this campaign.";
  if (message.includes("RESERVATION_UNAVAILABLE")) return "This slot cannot be reserved. Refresh the campaign and try again.";
  if (message.includes("ONBOARDING_ALREADY_COMPLETE")) return "Your account already belongs to an organization.";
  if (message.includes("NOT_AUTHORIZED") || code === "42501") return "You are not authorized to perform this action.";
  if (message.includes("INVALID_" ) || code === "22023") return "The submitted information is invalid. Review the form and try again.";
  return "The request could not be completed. Please try again.";
}
export function getAuthCallbackUrl(appUrl = process.env.APP_URL): string {
  return getTrustedAppUrl("/auth/callback", appUrl);
}
export function getTrustedAppUrl(path: string, appUrl = process.env.APP_URL): string {
  if (!appUrl) throw new Error("APP_URL is not configured.");
  let url: URL;
  try { url = new URL(appUrl); } catch { throw new Error("APP_URL must be a canonical HTTP(S) origin."); }
  if (!['http:','https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash || url.pathname !== "/") {
    throw new Error("APP_URL must be a canonical HTTP(S) origin with pathname '/'.");
  }
  return new URL(path, url).toString();
}

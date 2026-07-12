export const MUTATION_ROLES = ["owner", "administrator", "sales_manager"] as const;
export type InternalRole = "owner"|"administrator"|"sales_manager"|"salesperson"|"designer"|"finance";
export function canManageFirstSlice(role: string): boolean { return (MUTATION_ROLES as readonly string[]).includes(role); }
export const CAMPAIGN_TRANSITIONS:Record<string,Partial<Record<InternalRole,string[]>>>={
  draft:{owner:["selling"],administrator:["selling"],sales_manager:["selling"]},
  selling:{owner:["artwork_collection"],administrator:["artwork_collection"],sales_manager:["artwork_collection"]},
  artwork_collection:{owner:["proofing"],administrator:["proofing"],sales_manager:["proofing"]},
  proofing:{owner:["ready_for_print"],administrator:["ready_for_print"],designer:["ready_for_print"]},
  ready_for_print:{owner:["sent_to_printer"],administrator:["sent_to_printer"],designer:["sent_to_printer"]},
  sent_to_printer:{owner:["mailed_or_published"],administrator:["mailed_or_published"]},
  mailed_or_published:{owner:["completed"],administrator:["completed"]},
};
export function permittedCampaignTransitions(role:string,status:string):string[]{return isInternalRole(role)?CAMPAIGN_TRANSITIONS[status]?.[role]??[]:[]}
export function canCancelCampaign(role:string,status:string):boolean{return ["owner","administrator"].includes(role)||role==="sales_manager"&&["draft","selling","artwork_collection"].includes(status)}
export function canViewCampaignFinancials(role:string):boolean{return ["owner","administrator","finance"].includes(role)}
export function isInternalRole(role: string): role is InternalRole { return role !== "advertiser" && ["owner","administrator","sales_manager","salesperson","designer","finance"].includes(role); }
export function safeErrorMessage(error: unknown): string {
  const code = typeof error === "object" && error && "code" in error ? String(error.code) : "";
  const message = typeof error === "object" && error && "message" in error ? String(error.message) : "";
  if (message.includes("DUPLICATE_ADVERTISER") || code === "23505") return "An advertiser with that name already exists in this organization.";
  if (message.includes("CATEGORY_CONFLICT")) return "Another advertiser in this category already has an active placement in this campaign.";
  if (message.includes("RESERVATION_UNAVAILABLE")) return "This slot cannot be reserved. Refresh the campaign and try again.";
  if (message.includes("ADVERTISER_HAS_ACTIVE_RESERVATIONS")) return "Cancel active reservations before archiving this advertiser.";
  if (message.includes("SLOT_COUNT_BELOW_OCCUPIED")) return "Slot count cannot be reduced below occupied inventory.";
  if (message.includes("CAMPAIGN_NOT_EDITABLE")) return "This campaign can no longer be edited.";
  if (message.includes("INVALID_CAMPAIGN_TRANSITION")) return "That campaign status transition is not permitted.";
  if (message.includes("CAMPAIGN_TRANSITION_NOT_AUTHORIZED")) return "Your role cannot perform that campaign transition.";
  if (message.includes("CAMPAIGN_ALREADY_TERMINAL")) return "This campaign is already terminal.";
  if (message.includes("RESERVATION_ALREADY_CANCELED")) return "This reservation has already been canceled.";
  if (message.includes("CANCELLATION_NOT_ALLOWED")) return "This reservation can no longer be canceled.";
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

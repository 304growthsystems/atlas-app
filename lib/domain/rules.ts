export type PlacementStatus = "held" | "reserved" | "confirmed" | "completed" | "canceled";
export function isSlotAvailable(slotStatus: string, activePlacements: number) { return slotStatus === "available" && activePlacements === 0; }
export function categoryConflicts(enabled: boolean, requestedAdvertiserId: string, requestedCategory: string | null, active: { advertiserId: string; category: string | null; status: PlacementStatus }[]) {
  if (!enabled || !requestedCategory) return false;
  return active.some((p) => p.status !== "canceled" && p.advertiserId !== requestedAdvertiserId && p.category?.trim().toLowerCase() === requestedCategory.trim().toLowerCase());
}
export function calculateCampaignMetrics(campaigns: { status: string; slots: { status: string }[]; placements: { status: string; salePriceCents: number }[] }[]) {
  return { activeCampaigns: campaigns.filter((c) => !["completed", "canceled"].includes(c.status)).length, availableSlots: campaigns.flatMap((c) => c.slots).filter((s) => s.status === "available").length, reservedSlots: campaigns.flatMap((c) => c.slots).filter((s) => s.status === "reserved").length, projectedRevenueCents: campaigns.flatMap((c) => c.placements).filter((p) => ["reserved", "confirmed", "completed"].includes(p.status)).reduce((n, p) => n + p.salePriceCents, 0) };
}
export function assertOrganizationScoped<T extends { organization_id: string }>(record: T, organizationId: string): T { if (record.organization_id !== organizationId) throw new Error("Record is outside the current organization."); return record; }

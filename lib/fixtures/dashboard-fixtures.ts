import type { DashboardViewModel } from "@/lib/view-models/dashboard";

export const dashboardFixture = {
  metrics: [
    { id: "revenue", label: "Revenue Collected", value: "$495", detail: "Across active campaigns" },
    { id: "outstanding", label: "Outstanding", value: "$495", detail: "Reserved but not paid" },
    { id: "open-slots", label: "Open Ad Slots", value: "14", detail: "Inventory still available" },
    { id: "profit", label: "Projected Profit", value: "-$1,460", detail: "Revenue minus campaign costs" },
  ],
  priorities: [
    { id: "outstanding-payment", title: "$495 outstanding", detail: "Follow up on reserved advertising positions." },
    { id: "incomplete-artwork", title: "1 artwork package incomplete", detail: "Collect the advertiser logo, offer, and contact details." },
    { id: "open-inventory", title: "14 advertising slots remain open", detail: "Unsold inventory becomes an expensive blank rectangle." },
    { id: "campaign-attention", title: "Wayne County campaign needs attention", detail: "Review inventory and production deadlines." },
  ],
  campaigns: [
    {
      id: "wayne-county-august-2026",
      name: "Wayne County August 2026",
      territory: "Wayne County",
      mailDate: "August 20, 2026",
      soldSlots: 2,
      totalSlots: 16,
      collectedAmount: "$495",
      status: "needs-attention",
    },
  ],
} as const satisfies DashboardViewModel;

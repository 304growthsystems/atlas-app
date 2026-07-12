import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { MetricCard } from "@/components/dashboard/metric-card";
import { getCurrentContext } from "@/lib/auth";
import { formatCurrency } from "@/lib/money";
import { requireQueryData } from "@/lib/query";
import { canViewCampaignFinancials } from "@/lib/security";

export default async function ReportsPage() {
  const { supabase, organizationId, membership } = await getCurrentContext();
  const financial = canViewCampaignFinancials(membership.role);
  const campaignQuery = financial
    ? supabase.from("campaigns").select("status,configured_slot_count,standard_slot_price_cents,estimated_printing_cost_cents,estimated_postage_cost_cents").eq("organization_id", organizationId)
    : supabase.from("campaigns").select("status,configured_slot_count,standard_slot_price_cents").eq("organization_id", organizationId);
  const [a, c, s, p, o] = await Promise.all([
    supabase.from("advertisers").select("status").eq("organization_id", organizationId),
    campaignQuery,
    supabase.from("campaign_slots").select("status").eq("organization_id", organizationId),
    supabase.from("placements").select("status,sale_price_cents").eq("organization_id", organizationId).in("status", ["held", "reserved", "confirmed", "completed"]),
    supabase.from("opportunities").select("stage").eq("organization_id", organizationId),
  ]);
  const advertisers = requireQueryData("report advertisers", a), campaigns = requireQueryData("report campaigns", c), slots = requireQueryData("report slots", s), placements = requireQueryData("report placements", p), opportunities = requireQueryData("report opportunities", o);
  const available = slots.filter((x) => x.status === "available").length, reserved = slots.filter((x) => ["held", "reserved", "sold"].includes(x.status)).length;
  const estimatedRevenue = campaigns.reduce((n, x) => n + x.configured_slot_count * x.standard_slot_price_cents, 0), reservedRevenue = placements.reduce((n, x) => n + x.sale_price_cents, 0);
  const base: Array<[string, string | number]> = [["Total advertisers", advertisers.length], ["Active advertisers", advertisers.filter((x) => x.status === "active").length], ["Active campaigns", campaigns.filter((x) => !["completed", "canceled"].includes(x.status)).length], ["Campaigns selling", campaigns.filter((x) => x.status === "selling").length], ["Total slots", slots.length], ["Available slots", available], ["Reserved slots", reserved], ["Occupancy", slots.length ? `${Math.round(reserved * 100 / slots.length)}%` : "0%"], ["Reserved revenue", formatCurrency(reservedRevenue)], ["Estimated revenue", formatCurrency(estimatedRevenue)]];
  if (financial) { const costs = campaigns.reduce((n, x) => n + ("estimated_printing_cost_cents" in x ? Number(x.estimated_printing_cost_cents) : 0) + ("estimated_postage_cost_cents" in x ? Number(x.estimated_postage_cost_cents) : 0), 0); base.push(["Estimated gross margin", formatCurrency(estimatedRevenue - costs)]); }
  const metrics = base.map(([label, value], i) => ({ id: String(i), label, value: String(value), detail: "Current organization only" }));
  const stages = Object.entries(opportunities.reduce<Record<string, number>>((all, x) => ({ ...all, [x.stage]: (all[x.stage] ?? 0) + 1 }), {}));
  return <><ApplicationHeader title="Reports"/><PageContainer><div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{metrics.map((x) => <MetricCard key={x.id} metric={x}/>)}</div><section className="rounded-2xl border bg-white p-5"><h2 className="text-xl font-bold">Opportunities by status</h2>{stages.length ? <ul className="mt-3 grid gap-2 sm:grid-cols-2">{stages.map(([stage, count]) => <li key={stage} className="flex justify-between rounded bg-slate-50 p-3 capitalize"><span>{stage.replaceAll("_", " ")}</span><strong>{count}</strong></li>)}</ul> : <p className="mt-2 text-sm text-slate-500">No opportunities yet.</p>}</section></PageContainer></>;
}

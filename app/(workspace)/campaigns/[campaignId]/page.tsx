import { notFound } from "next/navigation";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { ReserveForm } from "@/components/campaigns/reserve-form";
import { CampaignCancellationControl, CancellationControl, StatusControl } from "@/components/campaigns/management-controls";
import { getCurrentContext } from "@/lib/auth";
import { formatCurrency } from "@/lib/money";
import { requireQueryData } from "@/lib/query";
import { canCancelCampaign, canManageFirstSlice, permittedCampaignTransitions } from "@/lib/security";

export default async function CampaignDetail({ params }: { params: Promise<{ campaignId: string }> }) {
  const { campaignId } = await params;
  const { supabase, organizationId, membership } = await getCurrentContext();
  const canManage = canManageFirstSlice(membership.role);
  const [cr, sr, ar, pr] = await Promise.all([
    supabase.from("campaigns").select("*").eq("organization_id", organizationId).eq("id", campaignId).maybeSingle(),
    supabase.from("campaign_slots").select("*").eq("organization_id", organizationId).eq("campaign_id", campaignId).order("identifier"),
    supabase.from("advertisers").select("id,name").eq("organization_id", organizationId).eq("status", "active").order("name"),
    supabase.from("placements").select("id,campaign_slot_id,sale_price_cents,status,opportunity_id,advertisers(name),opportunities(stage)").eq("organization_id", organizationId).eq("campaign_id", campaignId).in("status", ["held", "reserved", "confirmed"]),
  ]);
  const c = requireQueryData("campaign detail", cr); if (!c) notFound();
  const slots = requireQueryData("campaign slots", sr), advertisers = requireQueryData("campaign advertisers", ar), placements = requireQueryData("campaign placements", pr);
  const bySlot = new Map(placements.map((p) => [p.campaign_slot_id, p]));
  const available = slots.filter((s) => s.status === "available").length, reserved = slots.filter((s) => s.status === "reserved").length, confirmed = slots.filter((s) => s.status === "sold").length;
  const reservedRevenue = placements.reduce((n, p) => n + p.sale_price_cents, 0), grossRevenue = c.standard_slot_price_cents * c.configured_slot_count, remaining = c.standard_slot_price_cents * available, margin = grossRevenue - c.estimated_printing_cost_cents - c.estimated_postage_cost_cents;
  const metrics = [["Status", c.status.replaceAll("_", " ")], ["Product type", c.product_type], ["Publication", c.publication_date], ["Mailing quantity", String(c.mailing_quantity)], ["Slots", String(c.configured_slot_count)], ["Available", String(available)], ["Reserved", String(reserved)], ["Confirmed", String(confirmed)], ["Standard slot price", formatCurrency(c.standard_slot_price_cents, c.currency)], ["Printing cost", formatCurrency(c.estimated_printing_cost_cents, c.currency)], ["Postage cost", formatCurrency(c.estimated_postage_cost_cents, c.currency)], ["Estimated gross revenue", formatCurrency(grossRevenue, c.currency)], ["Reserved revenue", formatCurrency(reservedRevenue, c.currency)], ["Remaining inventory value", formatCurrency(remaining, c.currency)], ["Gross margin estimate", formatCurrency(margin, c.currency)], ["Category exclusivity", c.category_exclusivity_enabled ? "Enabled" : "Disabled"]];
  return <><ApplicationHeader title={c.name} eyebrow={c.territory} actions={canManage && ["draft", "selling"].includes(c.status) ? [{ label: "Edit campaign", variant: "primary", href: `/campaigns/${campaignId}/edit` }] : []}/><PageContainer>
    <section className="grid gap-4 rounded-2xl border bg-white p-5 sm:grid-cols-3 xl:grid-cols-4">{metrics.map(([l, v]) => <div key={l}><p className="text-xs text-slate-500">{l}</p><p className="font-bold capitalize">{v}</p></div>)}</section>
    <section className="rounded-2xl border bg-white p-5"><h2 className="text-xl font-bold">Deadlines</h2><div className="mt-3 grid gap-3 sm:grid-cols-5">{[["Sales", c.sales_deadline], ["Artwork", c.artwork_deadline], ["Proof", c.proof_deadline], ["Print", c.print_deadline], ["Publication", c.publication_date]].map(([l, v]) => <div key={l}><p className="text-xs text-slate-500">{l}</p><p className="font-semibold">{v}</p></div>)}</div></section>
    <div className="flex flex-wrap gap-3"><StatusControl kind="campaign" id={campaignId} currentStatus={c.status} next={permittedCampaignTransitions(membership.role, c.status)}/>{canCancelCampaign(membership.role, c.status) && <CampaignCancellationControl campaignId={campaignId} currentStatus={c.status}/>}</div>
    <section><h2 className="mb-3 text-xl font-bold">Campaign slots</h2><div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">{slots.map((s) => { const p = bySlot.get(s.id); return <article key={s.id} className="rounded-2xl border bg-white p-5"><div className="flex justify-between"><div><h3 className="font-bold">{s.identifier}</h3><p className="text-sm text-slate-500">{s.side_or_section}</p></div><span className="rounded-full bg-slate-100 px-2 py-1 text-xs font-bold capitalize">{s.status}</span></div>{p ? <div className="mt-4 text-sm"><p>Advertiser: <strong>{(p.advertisers as unknown as {name:string})?.name}</strong></p><p>Placement: <strong className="capitalize">{p.status}</strong></p><p>Opportunity: <strong className="capitalize">{(p.opportunities as unknown as {stage:string})?.stage?.replaceAll("_", " ")}</strong></p><p>Sale price: <strong>{formatCurrency(p.sale_price_cents, c.currency)}</strong></p>{canManage && !["mailed_or_published", "completed"].includes(c.status) && <CancellationControl placementId={p.id} campaignId={campaignId}/>}</div> : canManage && c.status === "selling" && advertisers.length ? <ReserveForm campaignId={campaignId} slotId={s.id} price={s.standard_price_cents} advertisers={advertisers}/> : <p className="mt-4 text-sm text-slate-500">No active reservation.</p>}</article> })}</div></section>
  </PageContainer></>;
}

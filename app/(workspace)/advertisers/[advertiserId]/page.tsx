import Link from "next/link";
import { notFound } from "next/navigation";

import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { StatusControl } from "@/components/campaigns/management-controls";
import { getCurrentContext } from "@/lib/auth";
import { requireQueryData } from "@/lib/query";
import { canManageFirstSlice } from "@/lib/security";

const currencyFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
});

function formatCurrency(cents: number | string | null | undefined): string {
  const value = Number(cents);

  if (!Number.isFinite(value)) {
    return "$0.00";
  }

  return currencyFormatter.format(value / 100);
}

export default async function AdvertiserDetail({
  params,
}: {
  params: Promise<{ advertiserId: string }>;
}) {
  const { advertiserId } = await params;
  const { supabase, organizationId, membership } =
    await getCurrentContext();

  const [
    advertiserResult,
    contactResult,
    locationResult,
    opportunityResult,
    placementResult,
    campaignResult,
  ] = await Promise.all([
    supabase
      .from("advertisers")
      .select("*")
      .eq("organization_id", organizationId)
      .eq("id", advertiserId)
      .maybeSingle(),

    supabase
      .from("advertiser_contacts")
      .select("*")
      .eq("organization_id", organizationId)
      .eq("advertiser_id", advertiserId)
      .eq("is_primary", true)
      .maybeSingle(),

    supabase
      .from("advertiser_locations")
      .select("*")
      .eq("organization_id", organizationId)
      .eq("advertiser_id", advertiserId)
      .eq("is_primary", true)
      .maybeSingle(),

    supabase
      .from("opportunities")
      .select("id,stage,campaign_id")
      .eq("organization_id", organizationId)
      .eq("advertiser_id", advertiserId),

    supabase
      .from("placements")
      .select("id,status,campaign_id,campaign_slot_id,sale_price_cents")
      .eq("organization_id", organizationId)
      .eq("advertiser_id", advertiserId),

    supabase
      .from("campaigns")
      .select("id,name,status")
      .eq("organization_id", organizationId),
  ]);

  const advertiser = requireQueryData(
    "advertiser detail",
    advertiserResult,
  );

  if (!advertiser) {
    notFound();
  }

  const contact = requireQueryData(
    "advertiser contact",
    contactResult,
  );

  const location = requireQueryData(
    "advertiser location",
    locationResult,
  );

  const opportunities = requireQueryData(
    "advertiser opportunities",
    opportunityResult,
  );

  const placements = requireQueryData(
    "advertiser placements",
    placementResult,
  );

  const campaigns = requireQueryData(
    "advertiser campaigns",
    campaignResult,
  );

  const campaignIds = new Set([
    ...opportunities.map((opportunity) => opportunity.campaign_id),
    ...placements.map((placement) => placement.campaign_id),
  ]);

  const relatedCampaigns = campaigns.filter((campaign) =>
    campaignIds.has(campaign.id),
  );

  const activePlacements = placements.filter((placement) =>
    ["held", "reserved", "confirmed"].includes(placement.status),
  );

  const canManage = canManageFirstSlice(membership.role);

  return (
    <>
      <ApplicationHeader
        title={advertiser.name}
        eyebrow={advertiser.category}
        actions={
          canManage
            ? [
                {
                  label: "Edit advertiser",
                  variant: "primary",
                  href: `/advertisers/${advertiserId}/edit`,
                },
              ]
            : []
        }
      />

      <PageContainer>
        <section className="grid gap-4 rounded-2xl border bg-white p-5 sm:grid-cols-3">
          <Item label="Status" value={advertiser.status} />
          <Item label="Primary contact" value={contact?.name} />
          <Item label="Email" value={contact?.email} />
          <Item label="Phone" value={contact?.phone} />
          <Item
            label="Location"
            value={
              location
                ? `${location.address_line_1}${
                    location.address_line_2
                      ? `, ${location.address_line_2}`
                      : ""
                  }, ${location.city}, ${location.state} ${location.postal_code}`
                : undefined
            }
          />
          <Item
            label="Created"
            value={new Date(advertiser.created_at).toLocaleDateString()}
          />
          <Item
            label="Updated"
            value={new Date(advertiser.updated_at).toLocaleDateString()}
          />
        </section>

        {canManage && (
          <StatusControl
            kind="advertiser"
            id={advertiserId}
            next={[
              advertiser.status === "active"
                ? "archived"
                : "active",
            ]}
          />
        )}

        <Related
          title="Opportunities"
          rows={opportunities.map((opportunity) =>
            opportunity.stage.replaceAll("_", " "),
          )}
        />

        <Related
          title="Placements"
          rows={placements.map(
            (placement) =>
              `${placement.status.replaceAll("_", " ")} · ${formatCurrency(
                placement.sale_price_cents,
              )}`,
          )}
        />

        <section>
          <h2 className="text-xl font-bold">Related campaigns</h2>

          {relatedCampaigns.length ? (
            <ul className="mt-3 space-y-2">
              {relatedCampaigns.map((campaign) => (
                <li key={campaign.id}>
                  <Link
                    className="text-red-700 underline"
                    href={`/campaigns/${campaign.id}`}
                  >
                    {campaign.name}
                  </Link>
                  {" · "}
                  {campaign.status.replaceAll("_", " ")}
                </li>
              ))}
            </ul>
          ) : (
            <p className="mt-2 text-sm text-slate-500">
              No related campaigns.
            </p>
          )}
        </section>

        <Related
          title="Current active reservations"
          rows={activePlacements.map(
            (placement) =>
              `${placement.status.replaceAll("_", " ")} · ${formatCurrency(
                placement.sale_price_cents,
              )}`,
          )}
        />
      </PageContainer>
    </>
  );
}

function Item({
  label,
  value,
}: {
  label: string;
  value?: string | null;
}) {
  return (
    <div>
      <p className="text-xs text-slate-500">{label}</p>
      <p className="font-semibold capitalize">{value || "—"}</p>
    </div>
  );
}

function Related({
  title,
  rows,
}: {
  title: string;
  rows: string[];
}) {
  return (
    <section>
      <h2 className="text-xl font-bold">{title}</h2>

      {rows.length ? (
        <ul className="mt-3 list-disc pl-5">
          {rows.map((row, index) => (
            <li key={index} className="capitalize">
              {row}
            </li>
          ))}
        </ul>
      ) : (
        <p className="mt-2 text-sm text-slate-500">None.</p>
      )}
    </section>
  );
}
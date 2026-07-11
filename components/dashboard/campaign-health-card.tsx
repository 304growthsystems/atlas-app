import type { CampaignHealth } from "@/lib/domain/campaign";

interface CampaignHealthCardProps {
  campaigns: readonly CampaignHealth[];
}

export function CampaignHealthCard({ campaigns }: CampaignHealthCardProps) {
  return (
    <article className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div className="mb-5">
        <h2 className="text-xl font-bold">Campaign health</h2>
        <p className="mt-1 text-sm text-slate-500">
          Current campaigns and inventory progress.
        </p>
      </div>

      <div className="space-y-4">
        {campaigns.map((campaign) => {
          const percentage = Math.round(
            (campaign.soldSlots / campaign.totalSlots) * 100,
          );

          return (
            <section
              key={campaign.id}
              className="rounded-xl border border-slate-200 p-4"
            >
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="font-bold">{campaign.name}</h3>
                  <p className="mt-1 text-sm text-slate-500">
                    {campaign.territory}
                  </p>
                </div>
                <span className="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-bold text-amber-800">
                  Needs Attention
                </span>
              </div>

              <div
                className="mt-5 h-2 overflow-hidden rounded-full bg-slate-200"
                role="progressbar"
                aria-label={`${campaign.name} inventory sold`}
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={percentage}
              >
                <div
                  className="h-full rounded-full bg-red-700"
                  style={{ width: `${percentage}%` }}
                />
              </div>

              <div className="mt-4 grid grid-cols-3 gap-3 text-sm">
                <div>
                  <p className="text-xs text-slate-500">Slots sold</p>
                  <p className="mt-1 font-bold">
                    {campaign.soldSlots}/{campaign.totalSlots}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-slate-500">Collected</p>
                  <p className="mt-1 font-bold">{campaign.collectedAmount}</p>
                </div>
                <div>
                  <p className="text-xs text-slate-500">Mail date</p>
                  <p className="mt-1 font-bold">{campaign.mailDate}</p>
                </div>
              </div>
            </section>
          );
        })}
      </div>
    </article>
  );
}

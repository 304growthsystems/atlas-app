import type { Metadata } from "next";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { CampaignHealthCard } from "@/components/dashboard/campaign-health-card";
import { MetricCard } from "@/components/dashboard/metric-card";
import { PriorityList } from "@/components/dashboard/priority-list";
import { getDashboardViewModel } from "@/lib/repositories/dashboard-repository";

export const metadata: Metadata = { title: "Dashboard" };

const headerActions = [
  { label: "Add Advertiser", variant: "secondary" },
  { label: "New Campaign", variant: "primary" },
] as const;

export default function DashboardPage() {
  const dashboard = getDashboardViewModel();

  return (
    <>
      <ApplicationHeader title="Dashboard" actions={headerActions} />
      <PageContainer>
        <section aria-labelledby="business-overview-heading">
          <div className="mb-4">
            <h2 id="business-overview-heading" className="text-lg font-bold">
              Business overview
            </h2>
            <p className="text-sm text-slate-500">
              The numbers that deserve your attention today.
            </p>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {dashboard.metrics.map((metric) => (
              <MetricCard key={metric.id} metric={metric} />
            ))}
          </div>
        </section>

        <section className="grid gap-6 xl:grid-cols-[1.35fr_1fr]">
          <PriorityList priorities={dashboard.priorities} />
          <CampaignHealthCard campaigns={dashboard.campaigns} />
        </section>
      </PageContainer>
    </>
  );
}

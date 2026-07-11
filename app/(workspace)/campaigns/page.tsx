import type { Metadata } from "next";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { ModuleEmptyState } from "@/components/modules/module-empty-state";

export const metadata: Metadata = { title: "Campaigns" };

export default function CampaignsPage() {
  return <><ApplicationHeader title="Campaigns" /><PageContainer><ModuleEmptyState moduleName="Campaigns" description="Plan each local advertising campaign, track its territory and mail date, and manage available advertising inventory." emptyMessage="Campaign records will appear here once campaign creation is implemented." /></PageContainer></>;
}

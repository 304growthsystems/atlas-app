import type { Metadata } from "next";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { ModuleEmptyState } from "@/components/modules/module-empty-state";

export const metadata: Metadata = { title: "Advertisers" };

export default function AdvertisersPage() {
  return <><ApplicationHeader title="Advertisers" /><PageContainer><ModuleEmptyState moduleName="Advertisers" description="Maintain the local businesses, contacts, offers, and campaign relationships that power advertising sales." emptyMessage="Advertiser records will appear here once advertiser management is implemented." /></PageContainer></>;
}

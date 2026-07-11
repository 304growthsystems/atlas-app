import type { Metadata } from "next";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { ModuleEmptyState } from "@/components/modules/module-empty-state";

export const metadata: Metadata = { title: "Reports" };

export default function ReportsPage() {
  return <><ApplicationHeader title="Reports" /><PageContainer><ModuleEmptyState moduleName="Reports" description="Turn campaign, inventory, sales, artwork, and payment records into useful operating insight." emptyMessage="Reports will appear here once Atlas has persistent business data to analyze." /></PageContainer></>;
}

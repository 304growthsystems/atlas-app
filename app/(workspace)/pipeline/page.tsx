import type { Metadata } from "next";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { ModuleEmptyState } from "@/components/modules/module-empty-state";

export const metadata: Metadata = { title: "Sales Pipeline" };

export default function PipelinePage() {
  return <><ApplicationHeader title="Sales Pipeline" /><PageContainer><ModuleEmptyState moduleName="Opportunities" description="Move prospective advertisers from first contact through reservation, commitment, and campaign placement." emptyMessage="Sales opportunities will appear here when pipeline tracking is implemented." /></PageContainer></>;
}

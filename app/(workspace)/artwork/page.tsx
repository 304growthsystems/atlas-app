import type { Metadata } from "next";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { ModuleEmptyState } from "@/components/modules/module-empty-state";

export const metadata: Metadata = { title: "Artwork" };

export default function ArtworkPage() {
  return <><ApplicationHeader title="Artwork" /><PageContainer><ModuleEmptyState moduleName="Artwork packages" description="Coordinate logos, offers, contact details, proofs, revisions, and final approval before production." emptyMessage="Artwork requirements and review statuses will appear here once the workflow is implemented." /></PageContainer></>;
}

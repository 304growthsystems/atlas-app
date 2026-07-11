import type { Metadata } from "next";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { ModuleEmptyState } from "@/components/modules/module-empty-state";

export const metadata: Metadata = { title: "Payments" };

export default function PaymentsPage() {
  return <><ApplicationHeader title="Payments" /><PageContainer><ModuleEmptyState moduleName="Payments" description="Track amounts invoiced, collected, and outstanding across advertisers and active campaigns." emptyMessage="Payment activity will appear here after financial workflows are designed and implemented." /></PageContainer></>;
}

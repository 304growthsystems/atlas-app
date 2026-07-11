import type { Metadata } from "next";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { ModuleEmptyState } from "@/components/modules/module-empty-state";

export const metadata: Metadata = { title: "Tasks" };

export default function TasksPage() {
  return <><ApplicationHeader title="Tasks" /><PageContainer><ModuleEmptyState moduleName="Tasks" description="Organize follow-ups and deadline-sensitive work across sales, artwork, payment, and production." emptyMessage="Operational tasks will appear here once task management is implemented." /></PageContainer></>;
}

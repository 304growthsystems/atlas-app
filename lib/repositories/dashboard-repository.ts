import { dashboardFixture } from "@/lib/fixtures/dashboard-fixtures";
import type { DashboardViewModel } from "@/lib/view-models/dashboard";

export function getDashboardViewModel(): DashboardViewModel {
  return dashboardFixture;
}

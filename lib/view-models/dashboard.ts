import type { CampaignHealth } from "@/lib/domain/campaign";

export interface MetricViewModel {
  id: string;
  label: string;
  value: string;
  detail: string;
}

export interface PriorityViewModel {
  id: string;
  title: string;
  detail: string;
}

export interface DashboardViewModel {
  metrics: readonly MetricViewModel[];
  priorities: readonly PriorityViewModel[];
  campaigns: readonly CampaignHealth[];
}

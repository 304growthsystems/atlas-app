import type { MetricViewModel } from "@/lib/view-models/dashboard";

interface MetricCardProps {
  metric: MetricViewModel;
}

export function MetricCard({ metric }: MetricCardProps) {
  return (
    <article className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <p className="text-sm font-medium text-slate-500">{metric.label}</p>
      <p className="mt-2 text-3xl font-black tracking-tight">{metric.value}</p>
      <p className="mt-2 text-xs text-slate-500">{metric.detail}</p>
    </article>
  );
}

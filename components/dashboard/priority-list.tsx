import type { PriorityViewModel } from "@/lib/view-models/dashboard";

interface PriorityListProps {
  priorities: readonly PriorityViewModel[];
}

export function PriorityList({ priorities }: PriorityListProps) {
  return (
    <article className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
      <div className="mb-5">
        <p className="text-xs font-bold uppercase tracking-[0.18em] text-red-700">
          Today&apos;s Fires
        </p>
        <h2 className="mt-1 text-xl font-bold">What needs attention</h2>
        <p className="mt-1 text-sm text-slate-500">
          Problems most likely to delay money or mailing.
        </p>
      </div>

      <ol className="space-y-3">
        {priorities.map((priority, index) => (
          <li
            key={priority.id}
            className="flex gap-3 rounded-xl border border-slate-200 p-4"
          >
            <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-red-100 text-sm font-black text-red-800">
              {index + 1}
            </span>
            <div>
              <p className="font-bold">{priority.title}</p>
              <p className="mt-1 text-sm text-slate-500">{priority.detail}</p>
            </div>
          </li>
        ))}
      </ol>
    </article>
  );
}

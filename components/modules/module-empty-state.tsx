interface ModuleEmptyStateProps {
  moduleName: string;
  description: string;
  emptyMessage: string;
}

export function ModuleEmptyState({
  moduleName,
  description,
  emptyMessage,
}: ModuleEmptyStateProps) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-10">
      <div className="mx-auto max-w-xl text-center">
        <div
          aria-hidden="true"
          className="mx-auto grid h-12 w-12 place-items-center rounded-xl bg-red-100 text-lg font-black text-red-800"
        >
          {moduleName.charAt(0)}
        </div>
        <h2 className="mt-5 text-xl font-bold">No {moduleName.toLowerCase()} yet</h2>
        <p className="mt-2 text-sm leading-6 text-slate-500">{emptyMessage}</p>
        <div className="mx-auto mt-6 max-w-md border-t border-slate-200 pt-6">
          <p className="text-sm leading-6 text-slate-600">{description}</p>
        </div>
      </div>
    </section>
  );
}

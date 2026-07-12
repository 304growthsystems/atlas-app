interface HeaderAction {
  label: string;
  variant: "primary" | "secondary";
  href?: string;
}

interface ApplicationHeaderProps {
  title: string;
  eyebrow?: string;
  actions?: readonly HeaderAction[];
}

export function ApplicationHeader({
  title,
  eyebrow = "304 Biz Connect",
  actions = [],
}: ApplicationHeaderProps) {
  return (
    <header className="flex flex-col gap-4 border-b border-slate-200 bg-white px-6 py-5 sm:flex-row sm:items-center sm:justify-between lg:px-8">
      <div>
        <p className="text-xs font-bold uppercase tracking-[0.2em] text-red-700">
          {eyebrow}
        </p>
        <h1 className="mt-1 text-2xl font-bold">{title}</h1>
      </div>

      {actions.length > 0 && (
        <div className="flex gap-3">
          {actions.map((action) => (
            <a
              key={action.label}
              href={action.href ?? "#"}
              className={
                action.variant === "primary"
                  ? "rounded-lg bg-red-700 px-4 py-2.5 text-sm font-bold text-white"
                  : "rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm font-bold"
              }
            >
              {action.label}
            </a>
          ))}
        </div>
      )}
    </header>
  );
}

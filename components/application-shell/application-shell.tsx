import { Sidebar } from "./sidebar";

interface ApplicationShellProps {
  children: React.ReactNode;
}

export function ApplicationShell({ children }: ApplicationShellProps) {
  return (
    <div className="min-h-screen bg-slate-100 text-slate-950 lg:grid lg:grid-cols-[250px_1fr]">
      <Sidebar />
      <main className="min-w-0">{children}</main>
    </div>
  );
}

import { SidebarNavigation } from "./sidebar-navigation";
import { signout } from "@/app/actions";

export function Sidebar() {
  return (
    <aside className="bg-slate-950 px-5 py-6 text-white">
      <div className="flex items-center gap-3 border-b border-white/10 pb-6">
        <div className="grid h-11 w-11 place-items-center rounded-xl bg-red-700 text-xl font-black">
          A
        </div>
        <div>
          <p className="text-xl font-bold">Atlas</p>
          <p className="text-xs text-slate-400">Campaign Operating System</p>
        </div>
      </div>

      <SidebarNavigation />

      <div className="mt-8 border-t border-white/10 pt-5 text-xs text-slate-500 lg:mt-20">
        <p>Project Atlas</p>
        <p className="mt-1">Prototype Build 0.1</p>
      </div>
      <form action={signout} className="mt-4"><button className="text-sm font-semibold text-slate-300 hover:text-white">Sign out</button></form>
    </aside>
  );
}

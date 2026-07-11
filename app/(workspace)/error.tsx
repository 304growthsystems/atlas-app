"use client";
export default function WorkspaceError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <main className="m-6 rounded-2xl border bg-white p-8 text-center"><h1 className="text-xl font-bold">Atlas could not load this workspace</h1><p className="mt-2 text-slate-600">Your data was not changed. Please retry, or return later if the problem continues.</p><button className="mt-4 rounded-lg bg-red-700 px-4 py-2 text-sm font-bold text-white" onClick={reset}>Try again</button></main>;
}

"use client";
export default function ApplicationError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <main className="grid min-h-screen place-items-center bg-slate-100 p-6"><section className="max-w-lg rounded-2xl bg-white p-8 text-center shadow"><h1 className="text-xl font-bold">Atlas could not load this page</h1><p className="mt-2 text-slate-600">No changes were made. Please retry, or return later if the problem continues.</p><button className="mt-4 rounded-lg bg-red-700 px-4 py-2 text-sm font-bold text-white" onClick={reset}>Try again</button></section></main>;
}

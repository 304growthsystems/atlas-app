const navigationItems = [
  "Dashboard",
  "Campaigns",
  "Advertisers",
  "Sales Pipeline",
  "Artwork",
  "Payments",
  "Tasks",
  "Reports",
];

const metrics = [
  {
    label: "Revenue Collected",
    value: "$495",
    detail: "Across active campaigns",
  },
  {
    label: "Outstanding",
    value: "$495",
    detail: "Reserved but not paid",
  },
  {
    label: "Open Ad Slots",
    value: "14",
    detail: "Inventory still available",
  },
  {
    label: "Projected Profit",
    value: "-$1,460",
    detail: "Revenue minus campaign costs",
  },
];

const priorities = [
  {
    title: "$495 outstanding",
    detail: "Follow up on reserved advertising positions.",
  },
  {
    title: "1 artwork package incomplete",
    detail: "Collect the advertiser logo, offer, and contact details.",
  },
  {
    title: "14 advertising slots remain open",
    detail: "Unsold inventory becomes an expensive blank rectangle.",
  },
  {
    title: "Wayne County campaign needs attention",
    detail: "Review inventory and production deadlines.",
  },
];

const campaigns = [
  {
    name: "Wayne County August 2026",
    territory: "Wayne County",
    mailDate: "August 20, 2026",
    sold: 2,
    total: 16,
    collected: "$495",
  },
];

export default function Home() {
  return (
    <main className="min-h-screen bg-slate-100 text-slate-950">
      <div className="min-h-screen lg:grid lg:grid-cols-[250px_1fr]">
        <aside className="bg-slate-950 px-5 py-6 text-white">
          <div className="flex items-center gap-3 border-b border-white/10 pb-6">
            <div className="grid h-11 w-11 place-items-center rounded-xl bg-red-700 text-xl font-black">
              A
            </div>

            <div>
              <h1 className="text-xl font-bold">Atlas</h1>
              <p className="text-xs text-slate-400">Campaign Operating System</p>
            </div>
          </div>

          <nav className="mt-6 grid grid-cols-2 gap-2 lg:grid-cols-1">
            {navigationItems.map((item, index) => (
              <button
                key={item}
                className={`rounded-lg px-3 py-2.5 text-left text-sm font-medium transition ${
                  index === 0
                    ? "bg-white/10 text-white"
                    : "text-slate-400 hover:bg-white/5 hover:text-white"
                }`}
              >
                {item}
              </button>
            ))}
          </nav>

          <div className="mt-8 border-t border-white/10 pt-5 text-xs text-slate-500 lg:mt-20">
            <p>Project Atlas</p>
            <p className="mt-1">Prototype Build 0.1</p>
          </div>
        </aside>

        <section className="min-w-0">
          <header className="flex flex-col gap-4 border-b border-slate-200 bg-white px-6 py-5 sm:flex-row sm:items-center sm:justify-between lg:px-8">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.2em] text-red-700">
                304 Biz Connect
              </p>
              <h2 className="mt-1 text-2xl font-bold">Dashboard</h2>
            </div>

            <div className="flex gap-3">
              <button className="rounded-lg border border-slate-300 bg-white px-4 py-2.5 text-sm font-bold hover:bg-slate-50">
                Add Advertiser
              </button>

              <button className="rounded-lg bg-red-700 px-4 py-2.5 text-sm font-bold text-white hover:bg-red-800">
                New Campaign
              </button>
            </div>
          </header>

          <div className="space-y-6 p-6 lg:p-8">
            <section>
              <div className="mb-4">
                <h3 className="text-lg font-bold">Business overview</h3>
                <p className="text-sm text-slate-500">
                  The numbers that deserve your attention today.
                </p>
              </div>

              <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                {metrics.map((metric) => (
                  <article
                    key={metric.label}
                    className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
                  >
                    <p className="text-sm font-medium text-slate-500">
                      {metric.label}
                    </p>

                    <p className="mt-2 text-3xl font-black tracking-tight">
                      {metric.value}
                    </p>

                    <p className="mt-2 text-xs text-slate-500">
                      {metric.detail}
                    </p>
                  </article>
                ))}
              </div>
            </section>

            <section className="grid gap-6 xl:grid-cols-[1.35fr_1fr]">
              <article className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                <div className="mb-5">
                  <p className="text-xs font-bold uppercase tracking-[0.18em] text-red-700">
                    Today&apos;s Fires
                  </p>
                  <h3 className="mt-1 text-xl font-bold">
                    What needs attention
                  </h3>
                  <p className="mt-1 text-sm text-slate-500">
                    Problems most likely to delay money or mailing.
                  </p>
                </div>

                <ol className="space-y-3">
                  {priorities.map((priority, index) => (
                    <li
                      key={priority.title}
                      className="flex gap-3 rounded-xl border border-slate-200 p-4"
                    >
                      <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-red-100 text-sm font-black text-red-800">
                        {index + 1}
                      </span>

                      <div>
                        <p className="font-bold">{priority.title}</p>
                        <p className="mt-1 text-sm text-slate-500">
                          {priority.detail}
                        </p>
                      </div>
                    </li>
                  ))}
                </ol>
              </article>

              <article className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                <div className="mb-5">
                  <h3 className="text-xl font-bold">Campaign health</h3>
                  <p className="mt-1 text-sm text-slate-500">
                    Current campaigns and inventory progress.
                  </p>
                </div>

                {campaigns.map((campaign) => {
                  const percentage = Math.round(
                    (campaign.sold / campaign.total) * 100,
                  );

                  return (
                    <div
                      key={campaign.name}
                      className="rounded-xl border border-slate-200 p-4"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <p className="font-bold">{campaign.name}</p>
                          <p className="mt-1 text-sm text-slate-500">
                            {campaign.territory}
                          </p>
                        </div>

                        <span className="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-bold text-amber-800">
                          Needs Attention
                        </span>
                      </div>

                      <div className="mt-5 h-2 overflow-hidden rounded-full bg-slate-200">
                        <div
                          className="h-full rounded-full bg-red-700"
                          style={{ width: `${percentage}%` }}
                        />
                      </div>

                      <div className="mt-4 grid grid-cols-3 gap-3 text-sm">
                        <div>
                          <p className="text-xs text-slate-500">Slots sold</p>
                          <p className="mt-1 font-bold">
                            {campaign.sold}/{campaign.total}
                          </p>
                        </div>

                        <div>
                          <p className="text-xs text-slate-500">Collected</p>
                          <p className="mt-1 font-bold">{campaign.collected}</p>
                        </div>

                        <div>
                          <p className="text-xs text-slate-500">Mail date</p>
                          <p className="mt-1 font-bold">{campaign.mailDate}</p>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </article>
            </section>
          </div>
        </section>
      </div>
    </main>
  );
}
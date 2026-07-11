# Project Atlas

Atlas is intended to become an operating system for local advertising businesses. It will bring campaign planning, advertiser relationships, sales progress, artwork readiness, payments, operational tasks, and reporting into one focused workspace.

## Current architecture

This repository is a typed UI prototype built with Next.js 16, React 19, TypeScript, and Tailwind CSS 4.

- The App Router lives in `app/`.
- `app/(workspace)/layout.tsx` provides the shared application shell without changing route URLs.
- Pages and layouts are Server Components by default.
- The sidebar navigation is the only Client Component and uses `usePathname` to expose the active route.
- Focused components live under `components/`.
- Domain types and page view models live under `lib/domain` and `lib/view-models`.
- Demo data lives under `lib/fixtures` and is exposed through a small repository boundary under `lib/repositories`.

The root route redirects to `/dashboard`. The remaining workspace routes currently render purposeful empty states for future modules.

## Local setup

Install dependencies and start the development server:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). The root route redirects to the dashboard.

Quality checks:

```bash
npm run lint
npx tsc --noEmit
npm run build
```

## Current prototype limitations

Atlas currently has no authentication, authorization, database, API routes, Server Actions, or persistent business data. Dashboard values are typed fixtures and the primary actions are intentionally disabled. The module routes are structural placeholders rather than completed workflows. Financial calculations, inventory rules, organization boundaries, roles, and audit behavior still need to be defined before production data is introduced.

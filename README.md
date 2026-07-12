# Project Atlas

Atlas is a Next.js 16 and Supabase vertical slice for organization-scoped advertiser and campaign inventory workflows.

The management slice adds advertiser aggregate editing and archive/restore, Draft/Selling campaign editing with safe slot resizing, forward-only lifecycle controls, reservation cancellation with preserved history, and tenant-scoped campaign reporting. Mutations are limited to Owner, Administrator, and Sales Manager and execute through transactional RPCs.

## Setup

Copy `.env.example` to `.env.local` and configure `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, and server-only `APP_URL` (for example `http://localhost:3000`). `APP_URL` is the sole source for the approved `/auth/callback` URL; request headers and form fields are not trusted. Configure the same callback in Supabase Auth.

```bash
npm install
npm run dev
```

The slice implements email/password authentication, protected Server Component routes, Server Actions, explicit persistent active-organization selection, role-aware UI, RLS, and secured transactional RPCs for onboarding, advertiser creation, campaign/slot creation, and direct reservation. Supabase migrations exist but have not been applied. Review the existing initial migration before applying it. Never expose a service-role key.

## Database tests

With a local Supabase CLI environment available (these commands reset only the local database):

```bash
npx supabase start
npx supabase db reset
npx supabase test db supabase/tests/atlas_security_test.sql
```

Do not link or push merely to run local tests.

These behavioral pgTAP tests require a running local Supabase database. True multi-session races are outside pgTAP's single-session transaction and use the opt-in integration harness instead:

```bash
SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_ANON_KEY=... ATLAS_CONCURRENCY_EMAIL=... ATLAS_CONCURRENCY_PASSWORD=... ATLAS_ONBOARDING_EMAIL=... ATLAS_ONBOARDING_PASSWORD=... npm run test:concurrency
```

PowerShell:

```powershell
$env:SUPABASE_URL='http://127.0.0.1:54321'
$env:SUPABASE_ANON_KEY='local-anon-key'
$env:ATLAS_CONCURRENCY_EMAIL='fixture-user@example.test'
$env:ATLAS_CONCURRENCY_PASSWORD='fixture-password'
$env:ATLAS_ONBOARDING_EMAIL='fresh-user@example.test'
$env:ATLAS_ONBOARDING_PASSWORD='fresh-user-password'
$env:SUPABASE_SERVICE_ROLE_KEY='local-service-role-key'
$env:ATLAS_CONCURRENCY_FIXTURES=Get-Content -Raw .\supabase\tests\concurrency-fixtures.json # copy/edit concurrency-fixtures.example.json with fresh IDs
npm.cmd run test:concurrency
```

Reservation races additionally require `ATLAS_CONCURRENCY_FIXTURES`, a JSON object with fresh `sameSlot`, `competingCategory`, `sameAdvertiser`, and `statusTransition` fixtures. Each contains `orgId`, `campaignId`, `slotA`, optional `slotB`, `advertiserA`, optional `advertiserB`, and optional `salePriceCents`. The status-transition fixture also requires the local-only `SUPABASE_SERVICE_ROLE_KEY`. The harness is excluded from `npm test`, embeds no credentials, and prints explicit PASS, FAIL, or SKIP outcomes. Run against disposable, freshly reset local fixtures because successful reservations mutate them.

## Quality checks

```bash
npm run lint
npx tsc --noEmit
npm test
npm run build
git diff --check
```

## First-slice limitations

Only Owner, Administrator, and Sales Manager mutations are implemented. Salesperson reservation/assignment and commission flows are deferred. Advertiser is retained as a role, but the advertiser portal remains deferred. Finance, artwork, cancellation, and production workflows also remain deferred. Task and membership-management commands are not implemented, and business history has no direct client delete path.

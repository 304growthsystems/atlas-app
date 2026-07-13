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

These behavioral pgTAP tests require a running local Supabase database. True multi-session races are outside pgTAP's single-session transaction and use the local integration harness instead. The harness discovers the running Supabase stack through the CLI, rejects non-loopback API URLs, creates a disposable Auth user, signs in through the anon client, and onboards the user's organization through the application RPC:

```bash
npm run test:concurrency
```

PowerShell:

```powershell
npm.cmd run test:concurrency
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` may be supplied explicitly for a local stack; omitted values come from `supabase status`. The harness embeds and prints no credentials, uses the service role only for disposable local Auth-user administration, verifies committed authorization state before every race, and removes all Auth and database fixtures in `finally` after success or failure. It is excluded from `npm test`.

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

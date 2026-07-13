import { randomBytes, randomUUID } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import { createClient } from "@supabase/supabase-js";

const container = process.env.ATLAS_DB_CONTAINER ?? "supabase_db_atlas-app";
const userIdPlaceholder = "91000000-0000-0000-0000-000000000001";
const advertiserA = randomUUID();
const advertiserB = randomUUID();
const campaignId = randomUUID();
const slotA = randomUUID();
const slotB = randomUUID();
const opportunityId = randomUUID();
const placementId = randomUUID();
const cli = process.platform === "win32" ? "npx.cmd" : "npx";

const quote = (value) => `'${String(value).replaceAll("'", "''")}'`;
const jsonb = (value) => `${quote(JSON.stringify(value))}::jsonb`;

function localSupabaseConfiguration() {
  let url = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL;
  let anonKey = process.env.SUPABASE_ANON_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  let serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !anonKey || !serviceRoleKey) {
    const statusCommand = process.platform === "win32" ? (process.env.ComSpec ?? "cmd.exe") : cli;
    const statusArgs = process.platform === "win32"
      ? ["/d", "/s", "/c", cli, "supabase", "status", "-o", "json"]
      : ["supabase", "status", "-o", "json"];
    const result = spawnSync(statusCommand, statusArgs, {
      encoding: "utf8",
      windowsHide: true,
    });
    if (result.status !== 0) {
      const detail = result.stderr || result.stdout || result.error?.message || "unknown error";
      throw new Error(`local Supabase status unavailable: ${detail.trim()}`);
    }
    let status;
    try { status = JSON.parse(result.stdout); } catch { throw new Error("local Supabase status returned invalid JSON"); }
    const statusUrl = status.API_URL ?? status.api_url;
    if (url && statusUrl && new URL(url).origin !== new URL(statusUrl).origin) {
      throw new Error("fixture prerequisite failed: environment points to a different local Supabase instance");
    }
    url ??= statusUrl;
    anonKey ??= status.ANON_KEY ?? status.PUBLISHABLE_KEY ?? status.anon_key;
    serviceRoleKey ??= status.SERVICE_ROLE_KEY ?? status.SECRET_KEY ?? status.service_role_key;
  }
  if (!url || !anonKey || !serviceRoleKey) throw new Error("fixture prerequisite failed: local Supabase URL and keys are unavailable");
  const parsed = new URL(url);
  if (!["127.0.0.1", "localhost", "::1", "[::1]"].includes(parsed.hostname.toLowerCase())) {
    throw new Error("fixture prerequisite failed: concurrency harness refuses non-loopback Supabase URLs");
  }
  return { url: parsed.origin, anonKey, serviceRoleKey };
}

const psql = (sql) => new Promise((resolve) => {
  const child = spawn("docker", ["exec", "-i", container, "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-Atq"], { stdio: ["pipe", "pipe", "pipe"], windowsHide: true });
  let stdout = "";
  let stderr = "";
  let settled = false;
  const finish = (result) => { if (!settled) { settled = true; resolve(result); } };
  child.stdout.on("data", (chunk) => { stdout += chunk; });
  child.stderr.on("data", (chunk) => { stderr += chunk; });
  child.on("error", (error) => finish({ ok: false, stdout: "", stderr: error.message }));
  child.on("close", (code) => finish({ ok: code === 0, stdout: stdout.trim(), stderr: stderr.trim() }));
  child.stdin.end(sql);
});

const must = async (name, sql) => {
  const result = await psql(sql);
  if (!result.ok) throw new Error(`${name}: ${result.stderr}`);
  return result;
};

let fixtureUserId;
let organizationId;
let membershipId;
let anonClient;
let adminClient;

const authenticatedSql = (statement) => `
  begin;
  set local request.jwt.claim.sub=${quote(fixtureUserId ?? userIdPlaceholder)};
  set local role authenticated;
  ${statement}
  rollback;
`;

const race = async (name, statements, verify, acceptableFailures, assertOutcome) => {
  const results = await Promise.all(statements.map((statement) => psql(`
    set lock_timeout='5s';
    set statement_timeout='10s';
    set request.jwt.claim.sub=${quote(fixtureUserId)};
    set role authenticated;
    ${statement}
  `)));
  for (const result of results.filter((item) => !item.ok)) {
    if (result.stderr.includes("deadlock detected") || result.stderr.includes("lock timeout")) throw new Error(`${name}: lock-order failure: ${result.stderr}`);
    if (!acceptableFailures.some((message) => result.stderr.includes(message))) throw new Error(`${name}: unsafe failure: ${result.stderr}`);
  }
  assertOutcome(results);
  await must(`${name} committed-state verification`, verify(results));
  console.log(`PASS: ${name}`);
};

const commonAuthorizationChecks = () => `
  if not exists(select 1 from auth.users where id=${quote(fixtureUserId)}::uuid) then raise exception 'fixture prerequisite failed: auth user missing from harness database'; end if;
  if not exists(select 1 from public.organizations where id=${quote(organizationId)}::uuid) then raise exception 'fixture prerequisite failed: organization missing'; end if;
  if not exists(select 1 from public.organizations where id=${quote(organizationId)}::uuid and status='active') then raise exception 'fixture prerequisite failed: organization inactive'; end if;
  if not exists(select 1 from public.organization_memberships where organization_id=${quote(organizationId)}::uuid and user_id=${quote(fixtureUserId)}::uuid) then raise exception 'fixture prerequisite failed: membership missing'; end if;
  if not exists(select 1 from public.organization_memberships where organization_id=${quote(organizationId)}::uuid and user_id=${quote(fixtureUserId)}::uuid and status='active') then raise exception 'fixture prerequisite failed: membership inactive'; end if;
  if not exists(select 1 from public.organization_memberships where organization_id=${quote(organizationId)}::uuid and user_id=${quote(fixtureUserId)}::uuid and status='active' and role in ('owner','administrator','sales_manager')) then raise exception 'fixture prerequisite failed: membership role not permitted'; end if;
  if not exists(select 1 from public.profiles where id=${quote(fixtureUserId)}::uuid) then raise exception 'fixture prerequisite failed: profile missing'; end if;
  if not exists(select 1 from public.profiles where id=${quote(fixtureUserId)}::uuid and status='active') then raise exception 'fixture prerequisite failed: profile inactive'; end if;
  if not exists(select 1 from public.profiles where id=${quote(fixtureUserId)}::uuid and status='active' and active_organization_id=${quote(organizationId)}::uuid) then raise exception 'fixture prerequisite failed: active organization mismatch'; end if;
`;

const preflight = async (name, recordChecks, rpcStatements) => {
  const { data: { user }, error } = await anonClient.auth.getUser();
  if (error || !user) throw new Error(`${name} preflight: anon-client session is unavailable`);
  if (user.id !== fixtureUserId) throw new Error(`${name} preflight: session belongs to the wrong disposable user`);
  await must(`${name} authorization preflight`, `do $preflight$ begin ${commonAuthorizationChecks()} ${recordChecks} end $preflight$;`);
  for (const [index, statement] of rpcStatements.entries()) {
    await must(`${name} RPC preflight ${index + 1}`, authenticatedSql(statement));
  }
  console.log(`PASS: ${name} authorization preflight`);
};

const advertiserPayload = (name) => ({
  name, category: "Services", contact_name: "Race Contact", email: "race@local.test", phone: "",
  address_line_1: "2 Race St", address_line_2: "", city: "Atlas", state: "NY", postal_code: "10002",
});
const campaignPayload = (slotCount) => ({
  name: "Cancel Race", territory: "A", product_type: "Postcard", currency: "USD", publication_date: "2028-03-05",
  sales_deadline: "2028-03-01", artwork_deadline: "2028-03-02", proof_deadline: "2028-03-03", print_deadline: "2028-03-04",
  mailing_quantity: 100, estimated_printing_cost_cents: 0, estimated_postage_cost_cents: 0, slot_count: slotCount,
  standard_slot_price_cents: 10000, category_exclusivity_enabled: false,
});

const resetCancellationFixture = async (name) => must(name, `
  begin;
  delete from public.audit_events where organization_id=${quote(organizationId)}::uuid and event_type<>'organization.created';
  delete from public.placements where organization_id=${quote(organizationId)}::uuid and id<>${quote(placementId)}::uuid;
  delete from public.opportunities where organization_id=${quote(organizationId)}::uuid and id<>${quote(opportunityId)}::uuid;
  update public.campaigns set status='selling',configured_slot_count=2 where id=${quote(campaignId)}::uuid;
  update public.placements set status='reserved',canceled_at=null,cancellation_reason=null where id=${quote(placementId)}::uuid;
  update public.opportunities set stage='reserved' where id=${quote(opportunityId)}::uuid;
  update public.campaign_slots set status='reserved' where id=${quote(slotA)}::uuid;
  insert into public.campaign_slots(id,organization_id,campaign_id,identifier,side_or_section,status,standard_price_cents,currency)
    values(${quote(slotB)},${quote(organizationId)},${quote(campaignId)},'Slot 2','Back','available',10000,'USD')
    on conflict(id) do update set status='available';
  commit;
`);

let runError;
try {
  const local = localSupabaseConfiguration();
  adminClient = createClient(local.url, local.serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
  const email = `atlas-concurrency-${randomUUID()}@local.test`;
  const password = randomBytes(24).toString("base64url");
  const { data: created, error: createError } = await adminClient.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { display_name: "Atlas Concurrency" } });
  if (createError || !created.user) throw new Error(`disposable Auth user creation failed: ${createError?.message ?? "user missing"}`);
  fixtureUserId = created.user.id;

  anonClient = createClient(local.url, local.anonKey, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
  const { data: signedIn, error: signInError } = await anonClient.auth.signInWithPassword({ email, password });
  if (signInError || !signedIn.session || signedIn.user.id !== fixtureUserId) throw new Error(`disposable Auth sign-in failed: ${signInError?.message ?? "session mismatch"}`);

  const { data: onboarded, error: onboardingError } = await anonClient.rpc("create_organization_with_owner", { org_name: `Concurrency Local ${randomUUID()}` });
  if (onboardingError || !onboarded) throw new Error(`fixture onboarding failed: ${onboardingError?.message ?? "organization missing"}`);
  organizationId = onboarded;
  const membership = await must("committed onboarding membership lookup", `select id from public.organization_memberships where organization_id=${quote(organizationId)}::uuid and user_id=${quote(fixtureUserId)}::uuid;`);
  membershipId = membership.stdout;
  if (!membershipId) throw new Error("fixture onboarding failed: committed membership missing");

  await must("domain fixture setup", `
    begin;
    insert into public.advertisers(id,organization_id,name,normalized_name,category) values
      (${quote(advertiserA)},${quote(organizationId)},'Race A','race a','Dental'),
      (${quote(advertiserB)},${quote(organizationId)},'Race B','race b','Retail');
    insert into public.advertiser_contacts(organization_id,advertiser_id,name,email,is_primary) values
      (${quote(organizationId)},${quote(advertiserA)},'Race A Contact','race-a@local.test',true),
      (${quote(organizationId)},${quote(advertiserB)},'Race B Contact','race-b@local.test',true);
    insert into public.advertiser_locations(organization_id,advertiser_id,address_line_1,city,state,postal_code,is_primary) values
      (${quote(organizationId)},${quote(advertiserA)},'1 Race A St','Atlas','NY','10001',true),
      (${quote(organizationId)},${quote(advertiserB)},'1 Race B St','Atlas','NY','10001',true);
    insert into public.campaigns(id,organization_id,name,territory,product_type,currency,publication_date,sales_deadline,artwork_deadline,proof_deadline,print_deadline,mailing_quantity,estimated_printing_cost_cents,estimated_postage_cost_cents,configured_slot_count,standard_slot_price_cents,status)
      values(${quote(campaignId)},${quote(organizationId)},'Cancel Race','A','Postcard','USD','2028-03-05','2028-03-01','2028-03-02','2028-03-03','2028-03-04',100,0,0,2,10000,'selling');
    insert into public.campaign_slots(id,organization_id,campaign_id,identifier,side_or_section,status,standard_price_cents,currency) values
      (${quote(slotA)},${quote(organizationId)},${quote(campaignId)},'Slot 1','Front','reserved',10000,'USD'),
      (${quote(slotB)},${quote(organizationId)},${quote(campaignId)},'Slot 2','Back','available',10000,'USD');
    insert into public.opportunities(id,organization_id,advertiser_id,campaign_id,assigned_membership_id,stage)
      values(${quote(opportunityId)},${quote(organizationId)},${quote(advertiserA)},${quote(campaignId)},${quote(membershipId)},'reserved');
    insert into public.placements(id,organization_id,campaign_id,campaign_slot_id,advertiser_id,opportunity_id,assigned_membership_id,status,sale_price_cents,currency,category)
      values(${quote(placementId)},${quote(organizationId)},${quote(campaignId)},${quote(slotA)},${quote(advertiserA)},${quote(opportunityId)},${quote(membershipId)},'reserved',10000,'USD','Dental');
    commit;
  `);

  await preflight("concurrent advertiser normalized-name collision", `
    if (select count(*) from public.advertisers where id in (${quote(advertiserA)},${quote(advertiserB)}) and organization_id=${quote(organizationId)}::uuid and status='active')<>2 then raise exception 'fixture prerequisite failed: advertiser targets missing, inactive, or cross-organization'; end if;
    if (select count(distinct normalized_name) from public.advertisers where id in (${quote(advertiserA)},${quote(advertiserB)}))<>2 then raise exception 'fixture prerequisite failed: advertiser starting names are not distinct'; end if;
    if (select count(*) from public.advertiser_contacts where advertiser_id in (${quote(advertiserA)},${quote(advertiserB)}) and organization_id=${quote(organizationId)}::uuid and status='active' and is_primary)<>2 then raise exception 'fixture prerequisite failed: primary contacts missing'; end if;
    if (select count(*) from public.advertiser_locations where advertiser_id in (${quote(advertiserA)},${quote(advertiserB)}) and organization_id=${quote(organizationId)}::uuid and status='active' and is_primary)<>2 then raise exception 'fixture prerequisite failed: primary locations missing'; end if;
  `, [
    `select public.update_advertiser_with_details(${quote(organizationId)},${quote(advertiserA)},${jsonb(advertiserPayload("Race A"))});`,
    `select public.update_advertiser_with_details(${quote(organizationId)},${quote(advertiserB)},${jsonb(advertiserPayload("Race B"))});`,
  ]);
  await race("concurrent advertiser normalized-name collision", [
    `select public.update_advertiser_with_details(${quote(organizationId)},${quote(advertiserA)},${jsonb(advertiserPayload("Shared Name"))});`,
    `select public.update_advertiser_with_details(${quote(organizationId)},${quote(advertiserB)},${jsonb(advertiserPayload("Shared Name"))});`,
  ], () => `do $verify$ begin
    if (select count(*) from public.advertisers where organization_id=${quote(organizationId)}::uuid and normalized_name='shared name')<>1 then raise exception 'advertiser invariant failed: normalized winner count'; end if;
    if (select count(*) from public.advertisers a join public.advertiser_contacts c on c.advertiser_id=a.id and c.is_primary and c.status='active' join public.advertiser_locations l on l.advertiser_id=a.id and l.is_primary and l.status='active' where a.id in (${quote(advertiserA)},${quote(advertiserB)}) and a.normalized_name='shared name' and c.name='Race Contact' and c.email='race@local.test' and l.address_line_1='2 Race St' and l.postal_code='10002')<>1 then raise exception 'advertiser invariant failed: winning aggregate incomplete'; end if;
    if (select count(*) from public.advertisers a join public.advertiser_contacts c on c.advertiser_id=a.id and c.is_primary and c.status='active' join public.advertiser_locations l on l.advertiser_id=a.id and l.is_primary and l.status='active' where (a.id=${quote(advertiserA)}::uuid and a.name='Race A' and c.name='Race A Contact' and l.address_line_1='1 Race A St') or (a.id=${quote(advertiserB)}::uuid and a.name='Race B' and c.name='Race B Contact' and l.address_line_1='1 Race B St'))<>1 then raise exception 'advertiser invariant failed: losing aggregate partially updated'; end if;
    if (select count(*) from public.audit_events where actor_user_id=${quote(fixtureUserId)}::uuid and event_type='advertiser.updated' and entity_id in (${quote(advertiserA)},${quote(advertiserB)}) and details->>'name'='Shared Name')<>1 then raise exception 'advertiser invariant failed: committed audit count'; end if;
  end $verify$;`, ["DUPLICATE_ADVERTISER", "duplicate key value"], (results) => {
    if (results.filter((result) => result.ok).length !== 1 || results.filter((result) => !result.ok).length !== 1) throw new Error("concurrent advertiser normalized-name collision: expected exactly one success and one duplicate-name failure");
  });

  const campaignRecords = `
    if not exists(select 1 from public.campaigns where id=${quote(campaignId)}::uuid and organization_id=${quote(organizationId)}::uuid and status='selling') then raise exception 'fixture prerequisite failed: campaign missing, cross-organization, or not Selling'; end if;
    if not exists(select 1 from public.campaign_slots where id=${quote(slotB)}::uuid and organization_id=${quote(organizationId)}::uuid and campaign_id=${quote(campaignId)}::uuid and status='available') then raise exception 'fixture prerequisite failed: target slot unavailable or cross-organization'; end if;
    if not exists(select 1 from public.advertisers where id=${quote(advertiserB)}::uuid and organization_id=${quote(organizationId)}::uuid and status='active') then raise exception 'fixture prerequisite failed: reservation advertiser unavailable or cross-organization'; end if;
  `;
  await preflight("campaign transition racing reservation", campaignRecords, [
    `select * from public.transition_campaign_status(${quote(organizationId)},${quote(campaignId)},'artwork_collection');`,
    `select * from public.reserve_campaign_slot(${quote(organizationId)},${quote(slotB)},${quote(advertiserB)},10000);`,
  ]);
  await race("campaign transition racing reservation", [
    `select * from public.transition_campaign_status(${quote(organizationId)},${quote(campaignId)},'artwork_collection');`,
    `select * from public.reserve_campaign_slot(${quote(organizationId)},${quote(slotB)},${quote(advertiserB)},10000);`,
  ], (results) => {
    const reserved = results[1].ok ? 1 : 0;
    return `do $verify$ begin
      if not exists(select 1 from public.campaigns where id=${quote(campaignId)}::uuid and status='artwork_collection') then raise exception 'transition invariant failed: final campaign status'; end if;
      if (select count(*) from public.placements where campaign_slot_id=${quote(slotB)}::uuid and status in ('held','reserved','confirmed'))<>${reserved} then raise exception 'transition invariant failed: reservation committed state'; end if;
      if (select count(*) from public.audit_events where event_type='campaign.status_changed' and entity_id=${quote(campaignId)}::uuid and details->>'new_status'='artwork_collection')<>1 then raise exception 'transition invariant failed: transition audit count'; end if;
      if (select count(*) from public.audit_events where event_type='slot.reserved' and entity_id=${quote(slotB)}::uuid)<>${reserved} then raise exception 'transition invariant failed: reservation audit count'; end if;
    end $verify$;`;
  }, ["RESERVATION_UNAVAILABLE"], (results) => { if (!results[0].ok) throw new Error("campaign transition racing reservation: transition did not commit"); });

  await must("slot reduction race reset", `begin; delete from public.audit_events where organization_id=${quote(organizationId)}::uuid and event_type<>'organization.created'; delete from public.placements where campaign_slot_id=${quote(slotB)}::uuid; delete from public.opportunities where campaign_id=${quote(campaignId)}::uuid and advertiser_id=${quote(advertiserB)}::uuid; update public.campaign_slots set status='available' where id=${quote(slotB)}::uuid; update public.campaigns set status='selling',configured_slot_count=2 where id=${quote(campaignId)}::uuid; commit;`);
  await preflight("slot reduction racing reservation", campaignRecords, [
    `select public.update_campaign_with_slots(${quote(organizationId)},${quote(campaignId)},${jsonb(campaignPayload(1))});`,
    `select * from public.reserve_campaign_slot(${quote(organizationId)},${quote(slotB)},${quote(advertiserB)},10000);`,
  ]);
  await race("slot reduction racing reservation", [
    `select public.update_campaign_with_slots(${quote(organizationId)},${quote(campaignId)},${jsonb(campaignPayload(1))});`,
    `select * from public.reserve_campaign_slot(${quote(organizationId)},${quote(slotB)},${quote(advertiserB)},10000);`,
  ], (results) => results[0].ok
    ? `do $verify$ begin if not exists(select 1 from public.campaigns where id=${quote(campaignId)}::uuid and configured_slot_count=1) or (select count(*) from public.campaign_slots where campaign_id=${quote(campaignId)}::uuid)<>1 or exists(select 1 from public.placements where campaign_slot_id=${quote(slotB)}::uuid) then raise exception 'resize invariant failed: committed reduction'; end if; if (select count(*) from public.audit_events where event_type='campaign.updated' and entity_id=${quote(campaignId)}::uuid)<>1 or exists(select 1 from public.audit_events where event_type='slot.reserved' and entity_id=${quote(slotB)}::uuid) then raise exception 'resize invariant failed: committed audits'; end if; end $verify$;`
    : `do $verify$ begin if not exists(select 1 from public.campaigns where id=${quote(campaignId)}::uuid and configured_slot_count=2) or not exists(select 1 from public.campaign_slots where id=${quote(slotB)}::uuid and status='reserved') or (select count(*) from public.placements where campaign_slot_id=${quote(slotB)}::uuid and status in ('held','reserved','confirmed'))<>1 then raise exception 'resize invariant failed: committed reservation'; end if; if exists(select 1 from public.audit_events where event_type='campaign.updated' and entity_id=${quote(campaignId)}::uuid) or (select count(*) from public.audit_events where event_type='slot.reserved' and entity_id=${quote(slotB)}::uuid)<>1 then raise exception 'resize invariant failed: committed audits'; end if; end $verify$;`,
  ["INVALID_RESERVATION", "RESERVATION_UNAVAILABLE", "SLOT_COUNT_BELOW_OCCUPIED"], (results) => { if (results.filter((result) => result.ok).length !== 1) throw new Error("slot reduction racing reservation: expected exactly one committed operation"); });

  await resetCancellationFixture("repeated cancellation fixture reset");
  const cancellationRecords = `
    if not exists(select 1 from public.campaigns where id=${quote(campaignId)}::uuid and organization_id=${quote(organizationId)}::uuid and status='selling') then raise exception 'fixture prerequisite failed: cancellation campaign unavailable'; end if;
    if not exists(select 1 from public.campaign_slots where id=${quote(slotA)}::uuid and organization_id=${quote(organizationId)}::uuid and campaign_id=${quote(campaignId)}::uuid and status='reserved') then raise exception 'fixture prerequisite failed: cancellation slot unavailable'; end if;
    if not exists(select 1 from public.opportunities where id=${quote(opportunityId)}::uuid and organization_id=${quote(organizationId)}::uuid and campaign_id=${quote(campaignId)}::uuid and stage='reserved') then raise exception 'fixture prerequisite failed: cancellation opportunity unavailable'; end if;
    if not exists(select 1 from public.placements where id=${quote(placementId)}::uuid and organization_id=${quote(organizationId)}::uuid and campaign_id=${quote(campaignId)}::uuid and status='reserved') then raise exception 'fixture prerequisite failed: cancellation placement unavailable'; end if;
  `;
  await preflight("concurrent repeated reservation cancellation", cancellationRecords, [`select * from public.cancel_reservation(${quote(organizationId)},${quote(placementId)},'Preflight');`]);
  await race("concurrent repeated reservation cancellation", [
    `select * from public.cancel_reservation(${quote(organizationId)},${quote(placementId)},'Concurrent cancel A');`,
    `select * from public.cancel_reservation(${quote(organizationId)},${quote(placementId)},'Concurrent cancel B');`,
  ], () => `do $verify$ begin if not exists(select 1 from public.placements where id=${quote(placementId)}::uuid and status='canceled') or not exists(select 1 from public.opportunities where id=${quote(opportunityId)}::uuid and stage='lost') or not exists(select 1 from public.campaign_slots where id=${quote(slotA)}::uuid and status='available') then raise exception 'repeat cancellation invariant failed: aggregate state'; end if; if (select count(*) from public.audit_events where event_type='placement.canceled' and entity_id=${quote(placementId)}::uuid)<>1 or (select count(*) from public.audit_events where event_type='slot.released' and entity_id=${quote(slotA)}::uuid)<>1 then raise exception 'repeat cancellation invariant failed: audit count'; end if; end $verify$;`, ["RESERVATION_ALREADY_CANCELED"], (results) => { if (results.filter((result) => result.ok).length !== 1) throw new Error("concurrent repeated reservation cancellation: expected exactly one success"); });

  await resetCancellationFixture("simultaneous campaign cancellation fixture reset");
  await preflight("two simultaneous campaign cancellations", cancellationRecords, [`select * from public.cancel_campaign(${quote(organizationId)},${quote(campaignId)},'Preflight');`]);
  await race("two simultaneous campaign cancellations", [
    `select * from public.cancel_campaign(${quote(organizationId)},${quote(campaignId)},'Campaign no longer viable');`,
    `select * from public.cancel_campaign(${quote(organizationId)},${quote(campaignId)},'Campaign no longer viable');`,
  ], () => `do $verify$ begin if not exists(select 1 from public.campaigns where id=${quote(campaignId)}::uuid and status='canceled') or not exists(select 1 from public.placements where id=${quote(placementId)}::uuid and status='canceled') or not exists(select 1 from public.opportunities where id=${quote(opportunityId)}::uuid and stage='lost') or not exists(select 1 from public.campaign_slots where id=${quote(slotA)}::uuid and status='available') then raise exception 'campaign cancellation invariant failed: aggregate state'; end if; if (select count(*) from public.audit_events where event_type='campaign.status_changed' and entity_id=${quote(campaignId)}::uuid and details->>'new_status'='canceled')<>1 or (select count(*) from public.audit_events where event_type='placement.canceled' and entity_id=${quote(placementId)}::uuid)<>1 or (select count(*) from public.audit_events where event_type='slot.released' and entity_id=${quote(slotA)}::uuid)<>1 then raise exception 'campaign cancellation invariant failed: audit count'; end if; end $verify$;`, ["CAMPAIGN_ALREADY_TERMINAL"], (results) => { if (results.filter((result) => result.ok).length !== 1) throw new Error("two simultaneous campaign cancellations: expected exactly one success"); });

  await resetCancellationFixture("overlapping cancellation fixture reset");
  await preflight("campaign cancellation overlapping reservation cancellation", cancellationRecords, [
    `select * from public.cancel_campaign(${quote(organizationId)},${quote(campaignId)},'Preflight campaign');`,
    `select * from public.cancel_reservation(${quote(organizationId)},${quote(placementId)},'Preflight reservation');`,
  ]);
  await race("campaign cancellation overlapping reservation cancellation", [
    `select * from public.cancel_campaign(${quote(organizationId)},${quote(campaignId)},'Overlap campaign cancellation');`,
    `select * from public.cancel_reservation(${quote(organizationId)},${quote(placementId)},'Overlap reservation cancellation');`,
  ], () => `do $verify$ begin if not exists(select 1 from public.campaigns where id=${quote(campaignId)}::uuid and status='canceled') or not exists(select 1 from public.placements where id=${quote(placementId)}::uuid and status='canceled') or not exists(select 1 from public.opportunities where id=${quote(opportunityId)}::uuid and stage='lost') or not exists(select 1 from public.campaign_slots where id=${quote(slotA)}::uuid and status='available') then raise exception 'overlap cancellation invariant failed: aggregate state'; end if; if (select count(*) from public.audit_events where event_type='campaign.status_changed' and entity_id=${quote(campaignId)}::uuid and details->>'new_status'='canceled')<>1 or (select count(*) from public.audit_events where event_type='placement.canceled' and entity_id=${quote(placementId)}::uuid)<>1 or (select count(*) from public.audit_events where event_type='slot.released' and entity_id=${quote(slotA)}::uuid)<>1 then raise exception 'overlap cancellation invariant failed: audit count'; end if; end $verify$;`, ["RESERVATION_ALREADY_CANCELED"], (results) => { if (!results[0].ok) throw new Error("campaign cancellation overlapping reservation cancellation: campaign cancellation did not commit"); });

  console.log("PASS: local concurrency harness completed");
} catch (error) {
  runError = error;
} finally {
  const cleanupErrors = [];
  if (organizationId) {
    const cleanup = await psql(`begin; delete from public.audit_events where organization_id=${quote(organizationId)}::uuid; delete from public.placements where organization_id=${quote(organizationId)}::uuid; delete from public.opportunities where organization_id=${quote(organizationId)}::uuid; delete from public.campaign_slots where organization_id=${quote(organizationId)}::uuid; delete from public.campaigns where organization_id=${quote(organizationId)}::uuid; delete from public.advertiser_contacts where organization_id=${quote(organizationId)}::uuid; delete from public.advertiser_locations where organization_id=${quote(organizationId)}::uuid; delete from public.advertisers where organization_id=${quote(organizationId)}::uuid; delete from public.organization_memberships where organization_id=${quote(organizationId)}::uuid; delete from public.profiles where id=${quote(fixtureUserId)}::uuid; delete from public.organizations where id=${quote(organizationId)}::uuid; commit;`);
    if (!cleanup.ok) cleanupErrors.push(`database cleanup failed: ${cleanup.stderr}`);
  }
  if (fixtureUserId && adminClient) {
    const { error } = await adminClient.auth.admin.deleteUser(fixtureUserId);
    if (error) cleanupErrors.push(`Auth cleanup failed: ${error.message}`);
  }
  if (fixtureUserId || organizationId) {
    const verify = await psql(`do $cleanup$ begin if ${fixtureUserId ? `exists(select 1 from auth.users where id=${quote(fixtureUserId)}::uuid) or exists(select 1 from public.profiles where id=${quote(fixtureUserId)}::uuid) or` : ""} ${organizationId ? `exists(select 1 from public.organizations where id=${quote(organizationId)}::uuid) or exists(select 1 from public.organization_memberships where organization_id=${quote(organizationId)}::uuid) or exists(select 1 from public.advertisers where organization_id=${quote(organizationId)}::uuid) or exists(select 1 from public.advertiser_contacts where organization_id=${quote(organizationId)}::uuid) or exists(select 1 from public.advertiser_locations where organization_id=${quote(organizationId)}::uuid) or exists(select 1 from public.campaigns where organization_id=${quote(organizationId)}::uuid) or exists(select 1 from public.campaign_slots where organization_id=${quote(organizationId)}::uuid) or exists(select 1 from public.opportunities where organization_id=${quote(organizationId)}::uuid) or exists(select 1 from public.placements where organization_id=${quote(organizationId)}::uuid) or exists(select 1 from public.audit_events where organization_id=${quote(organizationId)}::uuid)` : "false"} then raise exception 'disposable fixtures remain'; end if; end $cleanup$;`);
    if (!verify.ok) cleanupErrors.push(`cleanup verification failed: ${verify.stderr}`);
  }
  if (cleanupErrors.length === 0 && (fixtureUserId || organizationId)) console.log("PASS: disposable Auth and database fixtures cleaned; no temporary grants or files created");
  if (cleanupErrors.length > 0) {
    const cleanupError = new Error(cleanupErrors.join("; "));
    if (runError) cleanupError.cause = runError;
    throw cleanupError;
  }
}

if (runError) throw runError;

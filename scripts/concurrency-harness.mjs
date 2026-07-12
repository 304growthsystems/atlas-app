import { spawn } from "node:child_process";

const container = process.env.ATLAS_DB_CONTAINER ?? "supabase_db_atlas-app";
const psql = (sql) => new Promise((resolve) => {
  const child = spawn("docker", ["exec", "-i", container, "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-Atq"], { stdio: ["pipe", "pipe", "pipe"] });
  let stdout = ""; let stderr = "";
  child.stdout.on("data", (chunk) => { stdout += chunk; });
  child.stderr.on("data", (chunk) => { stderr += chunk; });
  child.on("close", (code) => resolve({ ok: code === 0, stdout: stdout.trim(), stderr: stderr.trim() }));
  child.stdin.end(sql);
});
const must = async (name, sql) => { const result = await psql(sql); if (!result.ok) throw new Error(`${name}: ${result.stderr}`); return result; };
const race = async (name, statements, verify, acceptableFailures = []) => {
  const results = await Promise.all(statements.map((statement) => psql(`set lock_timeout='5s'; set statement_timeout='10s'; set request.jwt.claim.sub='91000000-0000-0000-0000-000000000001'; set role authenticated; ${statement}`)));
  for (const result of results.filter((item) => !item.ok)) {
    if (!acceptableFailures.some((message) => result.stderr.includes(message))) throw new Error(`${name}: unsafe failure: ${result.stderr}`);
    if (result.stderr.includes("deadlock detected") || result.stderr.includes("lock timeout")) throw new Error(`${name}: lock-order failure: ${result.stderr}`);
  }
  await must(`${name} invariant`, verify);
  console.log(`PASS: ${name}`);
};

const cleanupSql = `
begin;
delete from public.audit_events where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.placements where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.opportunities where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.campaign_slots where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.campaigns where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.advertiser_contacts where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.advertiser_locations where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.advertisers where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.organization_memberships where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.profiles where id='91000000-0000-0000-0000-000000000001';
delete from public.organizations where id='92000000-0000-0000-0000-000000000001';
delete from auth.users where id='91000000-0000-0000-0000-000000000001';
commit;`;

try {

await must("fixture setup", `
begin;
delete from public.audit_events where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.placements where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.opportunities where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.campaign_slots where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.campaigns where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.advertiser_contacts where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.advertiser_locations where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.advertisers where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.organization_memberships where organization_id='92000000-0000-0000-0000-000000000001';
delete from public.profiles where id='91000000-0000-0000-0000-000000000001';
delete from public.organizations where id='92000000-0000-0000-0000-000000000001';
delete from auth.users where id='91000000-0000-0000-0000-000000000001';
insert into auth.users(id,email,encrypted_password,raw_user_meta_data,created_at,updated_at) values('91000000-0000-0000-0000-000000000001','concurrency@local.test','x','{}',now(),now());
insert into public.organizations(id,name) values('92000000-0000-0000-0000-000000000001','Concurrency Local');
insert into public.organization_memberships(id,organization_id,user_id,role) values('93000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001','owner');
insert into public.advertisers(id,organization_id,name,normalized_name,category) values
 ('94000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','Race A','race a','Dental'),
 ('94000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','Race B','race b','Retail');
insert into public.advertiser_contacts(organization_id,advertiser_id,name,email,is_primary) select organization_id,id,name,'race@local.test',true from public.advertisers where organization_id='92000000-0000-0000-0000-000000000001';
insert into public.advertiser_locations(organization_id,advertiser_id,address_line_1,city,state,postal_code,is_primary) select organization_id,id,'1 Race St','Atlas','NY','10001',true from public.advertisers where organization_id='92000000-0000-0000-0000-000000000001';
insert into public.campaigns(id,organization_id,name,territory,product_type,currency,publication_date,sales_deadline,artwork_deadline,proof_deadline,print_deadline,mailing_quantity,estimated_printing_cost_cents,estimated_postage_cost_cents,configured_slot_count,standard_slot_price_cents,status) values
 ('95000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','Cancel Race','A','Postcard','USD','2028-03-05','2028-03-01','2028-03-02','2028-03-03','2028-03-04',100,0,0,2,10000,'selling');
insert into public.campaign_slots(id,organization_id,campaign_id,identifier,side_or_section,status,standard_price_cents,currency) values
 ('96000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','Slot 1','Front','reserved',10000,'USD'),
 ('96000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','Slot 2','Back','available',10000,'USD');
insert into public.opportunities(id,organization_id,advertiser_id,campaign_id,assigned_membership_id,stage) values('97000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','reserved');
insert into public.placements(id,organization_id,campaign_id,campaign_slot_id,advertiser_id,opportunity_id,assigned_membership_id,status,sale_price_cents,currency,category) values('98000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','reserved',10000,'USD','Dental');
commit;`);

const advertiserPayload = (name) => `'${JSON.stringify({ name, category: "Services", contact_name: "Race Contact", email: "race@local.test", phone: "", address_line_1: "2 Race St", address_line_2: "", city: "Atlas", state: "NY", postal_code: "10002" })}'::jsonb`;
const campaignPayload = (slotCount) => `'${JSON.stringify({ name:"Cancel Race",territory:"A",product_type:"Postcard",publication_date:"2028-03-05",sales_deadline:"2028-03-01",artwork_deadline:"2028-03-02",proof_deadline:"2028-03-03",print_deadline:"2028-03-04",mailing_quantity:100,estimated_printing_cost_cents:0,estimated_postage_cost_cents:0,slot_count:slotCount,standard_slot_price_cents:10000,category_exclusivity_enabled:false,currency:"USD" })}'::jsonb`;
await race("concurrent advertiser normalized-name collision", [
  `select public.update_advertiser_with_details('92000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001',${advertiserPayload("Shared Name")});`,
  `select public.update_advertiser_with_details('92000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000002',${advertiserPayload("Shared Name")});`
], `do $$begin if (select count(*) from public.advertisers where organization_id='92000000-0000-0000-0000-000000000001' and normalized_name='shared name')<>1 then raise exception 'duplicate normalized names'; end if; end$$;`, ["DUPLICATE_ADVERTISER", "duplicate key value"]);

await race("campaign transition racing reservation", [
  `select * from public.transition_campaign_status('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','artwork_collection');`,
  `select * from public.reserve_campaign_slot('92000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002',10000);`
], `do $$begin if (select status from public.campaigns where id='95000000-0000-0000-0000-000000000001')<>'artwork_collection' or exists(select 1 from public.placements p join public.campaigns c on c.id=p.campaign_id where p.campaign_slot_id='96000000-0000-0000-0000-000000000002' and p.status in ('held','reserved','confirmed') and c.status='selling') then raise exception 'transition/reservation invariant'; end if; end$$;`, ["RESERVATION_UNAVAILABLE"]);

await must("slot reduction race reset", `delete from public.placements where campaign_slot_id='96000000-0000-0000-0000-000000000002'; delete from public.opportunities where campaign_id='95000000-0000-0000-0000-000000000001' and advertiser_id='94000000-0000-0000-0000-000000000002'; update public.campaign_slots set status='available' where id='96000000-0000-0000-0000-000000000002'; update public.campaigns set status='selling',configured_slot_count=2 where id='95000000-0000-0000-0000-000000000001';`);
await race("slot reduction racing reservation", [
  `select public.update_campaign_with_slots('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001',${campaignPayload(1)});`,
  `select * from public.reserve_campaign_slot('92000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002',10000);`
], `do $$begin if exists(select 1 from public.placements p left join public.campaign_slots s on s.id=p.campaign_slot_id where p.organization_id='92000000-0000-0000-0000-000000000001' and s.id is null) then raise exception 'orphaned placement'; end if; end$$;`, ["INVALID_RESERVATION","SLOT_COUNT_BELOW_OCCUPIED"]);

await race("concurrent repeated reservation cancellation", [
  `select * from public.cancel_reservation('92000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000001','Concurrent cancel A');`,
  `select * from public.cancel_reservation('92000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000001','Concurrent cancel B');`
], `do $$begin if (select status from public.placements where id='98000000-0000-0000-0000-000000000001')<>'canceled' or (select count(*) from public.audit_events where event_type='placement.canceled' and entity_id='98000000-0000-0000-0000-000000000001')<>1 then raise exception 'non-idempotent cancellation'; end if; end$$;`, ["RESERVATION_ALREADY_CANCELED"]);

await must("overlap fixture reset", `update public.placements set status='reserved',canceled_at=null,cancellation_reason=null where id='98000000-0000-0000-0000-000000000001'; update public.campaign_slots set status='reserved' where id='96000000-0000-0000-0000-000000000001'; update public.opportunities set stage='reserved' where id='97000000-0000-0000-0000-000000000001';`);
await race("two simultaneous campaign cancellations", [
  `select * from public.cancel_campaign('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','Campaign no longer viable');`,
  `select * from public.cancel_campaign('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','Campaign no longer viable');`
], `do $$begin if (select status from public.campaigns where id='95000000-0000-0000-0000-000000000001')<>'canceled' or (select status from public.placements where id='98000000-0000-0000-0000-000000000001')<>'canceled' or (select status from public.campaign_slots where id='96000000-0000-0000-0000-000000000001')<>'available' or (select count(*) from public.audit_events where event_type='campaign.status_changed' and entity_id='95000000-0000-0000-0000-000000000001' and details->>'new_status'='canceled')<>1 then raise exception 'unsafe or duplicated cancellation'; end if; end$$;`, ["CAMPAIGN_ALREADY_TERMINAL"]);

console.log("PASS: local concurrency harness completed");
} finally {
  const cleanup = await psql(cleanupSql);
  if (!cleanup.ok) throw new Error(`cleanup failed: ${cleanup.stderr}`);
  const verify = await psql(`do $$begin if exists(select 1 from auth.users where id='91000000-0000-0000-0000-000000000001') or exists(select 1 from public.organizations where id='92000000-0000-0000-0000-000000000001') then raise exception 'disposable fixtures remain'; end if; end$$;`);
  if (!verify.ok) throw new Error(`cleanup verification failed: ${verify.stderr}`);
  console.log("PASS: disposable fixtures and temporary grants cleaned");
}

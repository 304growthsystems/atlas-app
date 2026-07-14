begin;
create extension if not exists pgtap;
select plan(261);

-- Contract and privilege coverage.
select has_function('public','update_advertiser_with_details',array['uuid','uuid','jsonb'],'advertiser aggregate update RPC exists');
select has_function('public','change_advertiser_status',array['uuid','uuid','record_status'],'advertiser status RPC exists');
select has_function('public','update_campaign_with_slots',array['uuid','uuid','jsonb'],'campaign update RPC exists');
select has_function('public','transition_campaign_status',array['uuid','uuid','campaign_status'],'campaign transition RPC exists');
select has_function('public','cancel_campaign',array['uuid','uuid','text'],'campaign cancellation RPC exists');
select has_function('public','cancel_reservation',array['uuid','uuid','text'],'reservation cancellation RPC exists');
select function_returns('public','update_advertiser_with_details',array['uuid','uuid','jsonb'],'uuid','advertiser update returns authoritative id');
select function_returns('public','change_advertiser_status',array['uuid','uuid','record_status'],'uuid','advertiser status returns authoritative id');
select function_returns('public','update_campaign_with_slots',array['uuid','uuid','jsonb'],'uuid','campaign update returns authoritative id');
select is_definer('public','update_advertiser_with_details',array['uuid','uuid','jsonb'],'advertiser update is secured definer');
select is_definer('public','change_advertiser_status',array['uuid','uuid','record_status'],'advertiser status is secured definer');
select is_definer('public','update_campaign_with_slots',array['uuid','uuid','jsonb'],'campaign update is secured definer');
select is_definer('public','transition_campaign_status',array['uuid','uuid','campaign_status'],'campaign transition is secured definer');
select is_definer('public','cancel_campaign',array['uuid','uuid','text'],'campaign cancellation is secured definer');
select is_definer('public','cancel_reservation',array['uuid','uuid','text'],'cancellation is secured definer');
select function_privs_are('public','update_advertiser_with_details',array['uuid','uuid','jsonb'],'anon',array[]::text[],'anon cannot edit advertiser');
select function_privs_are('public','change_advertiser_status',array['uuid','uuid','record_status'],'anon',array[]::text[],'anon cannot change advertiser status');
select function_privs_are('public','update_campaign_with_slots',array['uuid','uuid','jsonb'],'anon',array[]::text[],'anon cannot edit campaign');
select function_privs_are('public','transition_campaign_status',array['uuid','uuid','campaign_status'],'anon',array[]::text[],'anon cannot transition campaign');
select function_privs_are('public','cancel_campaign',array['uuid','uuid','text'],'anon',array[]::text[],'anon cannot cancel campaign');
select function_privs_are('public','cancel_reservation',array['uuid','uuid','text'],'anon',array[]::text[],'anon cannot cancel reservation');
select function_privs_are('public','update_advertiser_with_details',array['uuid','uuid','jsonb'],'authenticated',array['EXECUTE'],'authenticated can invoke advertiser update');
select function_privs_are('public','change_advertiser_status',array['uuid','uuid','record_status'],'authenticated',array['EXECUTE'],'authenticated can invoke advertiser status command');
select function_privs_are('public','update_campaign_with_slots',array['uuid','uuid','jsonb'],'authenticated',array['EXECUTE'],'authenticated can invoke campaign update');
select function_privs_are('public','transition_campaign_status',array['uuid','uuid','campaign_status'],'authenticated',array['EXECUTE'],'authenticated can invoke transition');
select function_privs_are('public','cancel_campaign',array['uuid','uuid','text'],'authenticated',array['EXECUTE'],'authenticated can invoke campaign cancellation');
select function_privs_are('public','cancel_reservation',array['uuid','uuid','text'],'authenticated',array['EXECUTE'],'authenticated can invoke cancellation');
select is((select proconfig from pg_proc where oid='public.cancel_reservation(uuid,uuid,text)'::regprocedure),array['search_path=""']::text[], 'cancellation has empty search path');
select is((select proconfig from pg_proc where oid='public.cancel_campaign(uuid,uuid,text)'::regprocedure),array['search_path=""']::text[], 'campaign cancellation has empty search path');
select is((select proconfig from pg_proc where oid='public.update_campaign_with_slots(uuid,uuid,jsonb)'::regprocedure),array['search_path=""']::text[], 'campaign update has empty search path');

create function pg_temp.advertiser_payload(name text, email text default 'owner@example.com') returns jsonb language sql immutable as $$
 select jsonb_build_object('name',name,'category','Dental','contact_name','New Contact','email',email,'phone','555-0100','address_line_1','22 New St','address_line_2','Suite 2','city','Atlas','state','NY','postal_code','10002')
$$;
create function pg_temp.campaign_payload(overrides jsonb default '{}'::jsonb) returns jsonb language sql immutable as $$
 select '{"name":"Updated Campaign","territory":"North","product_type":"Postcard","publication_date":"2028-03-05","sales_deadline":"2028-03-01","artwork_deadline":"2028-03-02","proof_deadline":"2028-03-03","print_deadline":"2028-03-04","mailing_quantity":1000,"estimated_printing_cost_cents":2000,"estimated_postage_cost_cents":3000,"slot_count":3,"standard_slot_price_cents":12000,"category_exclusivity_enabled":true,"currency":"USD"}'::jsonb || overrides
$$;

insert into auth.users(id,email,encrypted_password,raw_user_meta_data,created_at,updated_at) values
 ('11000000-0000-0000-0000-000000000001','owner@example.com','x','{}',now(),now()),
 ('11000000-0000-0000-0000-000000000002','sales@example.com','x','{}',now(),now()),
 ('11000000-0000-0000-0000-000000000003','other@example.com','x','{}',now(),now());
insert into public.organizations(id,name) values
 ('21000000-0000-0000-0000-000000000001','Atlas A'),
 ('21000000-0000-0000-0000-000000000002','Atlas B');
insert into public.organization_memberships(id,organization_id,user_id,role) values
 ('31000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','owner'),
 ('31000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000002','salesperson'),
 ('31000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000002','11000000-0000-0000-0000-000000000003','owner');
insert into public.profiles(id,normalized_email,active_organization_id) values
 ('11000000-0000-0000-0000-000000000001','owner@example.com','21000000-0000-0000-0000-000000000001'),
 ('11000000-0000-0000-0000-000000000002','sales@example.com','21000000-0000-0000-0000-000000000001'),
 ('11000000-0000-0000-0000-000000000003','other@example.com','21000000-0000-0000-0000-000000000002')
on conflict(id) do update set active_organization_id=excluded.active_organization_id;
insert into public.advertisers(id,organization_id,name,normalized_name,category) values
 ('41000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','Alpha Dental','alpha dental','Dental'),
 ('41000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','Beta Dental','beta dental','Dental'),
 ('41000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000002','Other Tenant','other tenant','Retail'),
 ('41000000-0000-0000-0000-000000000004','21000000-0000-0000-0000-000000000001','Gamma Services','gamma services','Services');
insert into public.advertiser_contacts(id,organization_id,advertiser_id,name,email,is_primary) values
 ('42000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001','Old Contact','old@example.com',true),
 ('42000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000002','Beta Contact','beta@example.com',true),
 ('42000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000002','41000000-0000-0000-0000-000000000003','Other Contact','other@example.com',true);
insert into public.advertiser_locations(id,organization_id,advertiser_id,address_line_1,city,state,postal_code,is_primary) values
 ('43000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001','1 Old St','Atlas','NY','10001',true),
 ('43000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000002','2 Beta St','Atlas','NY','10001',true),
 ('43000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000002','41000000-0000-0000-0000-000000000003','3 Other St','Atlas','NY','10001',true);
insert into public.campaigns(id,organization_id,name,territory,product_type,currency,publication_date,sales_deadline,artwork_deadline,proof_deadline,print_deadline,mailing_quantity,estimated_printing_cost_cents,estimated_postage_cost_cents,configured_slot_count,standard_slot_price_cents,category_exclusivity_enabled,status) values
 ('51000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','Editable','A','Postcard','USD','2028-03-05','2028-03-01','2028-03-02','2028-03-03','2028-03-04',100,0,0,2,10000,false,'draft'),
 ('51000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','Cancel Me','A','Postcard','USD','2028-03-05','2028-03-01','2028-03-02','2028-03-03','2028-03-04',100,0,0,2,10000,false,'selling'),
 ('51000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000001','Lifecycle','A','Postcard','USD','2028-03-05','2028-03-01','2028-03-02','2028-03-03','2028-03-04',100,0,0,1,10000,false,'draft'),
 ('51000000-0000-0000-0000-000000000004','21000000-0000-0000-0000-000000000001','Published','A','Postcard','USD','2028-03-05','2028-03-01','2028-03-02','2028-03-03','2028-03-04',100,0,0,1,10000,false,'mailed_or_published'),
 ('51000000-0000-0000-0000-000000000005','21000000-0000-0000-0000-000000000002','Other','B','Postcard','USD','2028-03-05','2028-03-01','2028-03-02','2028-03-03','2028-03-04',100,0,0,1,10000,false,'draft');
insert into public.campaign_slots(id,organization_id,campaign_id,identifier,side_or_section,status,standard_price_cents,currency) values
 ('61000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','Slot 1','Front','available',10000,'USD'),
 ('61000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','Slot 2','Back','reserved',10000,'USD'),
 ('61000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002','Slot 1','Front','reserved',10000,'USD'),
 ('61000000-0000-0000-0000-000000000004','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002','Slot 2','Back','reserved',10000,'USD'),
 ('61000000-0000-0000-0000-000000000005','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000003','Slot 1','Front','available',10000,'USD'),
 ('61000000-0000-0000-0000-000000000006','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000004','Slot 1','Front','reserved',10000,'USD'),
 ('61000000-0000-0000-0000-000000000007','21000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000005','Slot 1','Front','available',10000,'USD');
insert into public.opportunities(id,organization_id,advertiser_id,campaign_id,assigned_membership_id,stage) values
 ('71000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-000000000001','reserved'),
 ('71000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002','31000000-0000-0000-0000-000000000001','reserved'),
 ('71000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000002','31000000-0000-0000-0000-000000000001','reserved'),
 ('71000000-0000-0000-0000-000000000004','21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000004','31000000-0000-0000-0000-000000000001','reserved');
insert into public.placements(id,organization_id,campaign_id,campaign_slot_id,advertiser_id,opportunity_id,assigned_membership_id,status,sale_price_cents,currency,category) values
 ('81000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000002','41000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-000000000001','reserved',10000,'USD','Dental'),
 ('81000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002','61000000-0000-0000-0000-000000000003','41000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002','31000000-0000-0000-0000-000000000001','reserved',10000,'USD','Dental'),
 ('81000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002','61000000-0000-0000-0000-000000000004','41000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000003','31000000-0000-0000-0000-000000000001','reserved',10000,'USD','Dental'),
 ('81000000-0000-0000-0000-000000000004','21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000004','61000000-0000-0000-0000-000000000006','41000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000004','31000000-0000-0000-0000-000000000001','reserved',10000,'USD','Dental');
insert into public.opportunities(id,organization_id,advertiser_id,campaign_id,assigned_membership_id,stage) values
 ('71000000-0000-0000-0000-000000000005','21000000-0000-0000-0000-000000000002','41000000-0000-0000-0000-000000000003','51000000-0000-0000-0000-000000000005','31000000-0000-0000-0000-000000000003','reserved');
insert into public.placements(id,organization_id,campaign_id,campaign_slot_id,advertiser_id,opportunity_id,assigned_membership_id,status,sale_price_cents,currency,category) values
 ('81000000-0000-0000-0000-000000000005','21000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000005','61000000-0000-0000-0000-000000000007','41000000-0000-0000-0000-000000000003','71000000-0000-0000-0000-000000000005','31000000-0000-0000-0000-000000000003','reserved',10000,'USD','Retail');
update public.campaign_slots set status='reserved' where id='61000000-0000-0000-0000-000000000007';

-- Authentication and authorization behavior.
select throws_ok($$select public.update_advertiser_with_details('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001','{}')$$,'28000','AUTH_REQUIRED','advertiser update requires authentication');
set local role authenticated;
set local "request.jwt.claim.sub"='11000000-0000-0000-0000-000000000002';
select throws_ok($$select public.change_advertiser_status('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001','archived')$$,'42501','NOT_AUTHORIZED','salesperson cannot change advertiser status');
select throws_ok($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload())$$,'42501','NOT_AUTHORIZED','salesperson cannot update campaign');
set local "request.jwt.claim.sub"='11000000-0000-0000-0000-000000000001';
select throws_ok($$select public.update_advertiser_with_details('21000000-0000-0000-0000-000000000002','41000000-0000-0000-0000-000000000003',pg_temp.advertiser_payload('Attack'))$$,'42501','NOT_AUTHORIZED','cross-tenant advertiser update denied');
select throws_ok($$select public.transition_campaign_status('21000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000005','selling')$$,'42501','NOT_AUTHORIZED','cross-tenant campaign transition denied');

-- Advertiser aggregate update, validation, atomicity, status guard, and auditing.
select results_eq($$select public.update_advertiser_with_details('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload(' Alpha Prime '))$$,array['41000000-0000-0000-0000-000000000001'::uuid],'advertiser update returns authoritative id');
select results_eq($$select name||'|'||normalized_name||'|'||category from public.advertisers where id='41000000-0000-0000-0000-000000000001'$$,array['Alpha Prime|alpha prime|Dental'],'advertiser parent updated and normalized');
select results_eq($$select name||'|'||email||'|'||phone from public.advertiser_contacts where advertiser_id='41000000-0000-0000-0000-000000000001' and is_primary$$,array['New Contact|owner@example.com|555-0100'],'primary contact updated');
select results_eq($$select address_line_1||'|'||address_line_2||'|'||postal_code from public.advertiser_locations where advertiser_id='41000000-0000-0000-0000-000000000001' and is_primary$$,array['22 New St|Suite 2|10002'],'primary location updated');
select results_eq($$select count(*)::bigint from public.audit_events where event_type='advertiser.updated' and entity_id='41000000-0000-0000-0000-000000000001'$$,array[1::bigint],'advertiser update audited');
select throws_ok($$select public.update_advertiser_with_details('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001',null)$$,'22023','INVALID_ADVERTISER','null advertiser payload rejected');
select throws_ok($$select public.update_advertiser_with_details('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Beta Dental'))$$,'23505','DUPLICATE_ADVERTISER','duplicate normalized advertiser name rejected');
select throws_ok($$select public.update_advertiser_with_details('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Invalid Email','bad @example.com'))$$,'22023','INVALID_CONTACT_EMAIL','malformed contact email rejected');
select results_eq($$select name from public.advertisers where id='41000000-0000-0000-0000-000000000001'$$,array['Alpha Prime'],'failed advertiser update is atomic');
select lives_ok($$select public.change_advertiser_status('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000004','archived')$$,'advertiser without active reservations can be archived');
select throws_ok($$select public.update_advertiser_with_details('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000004',pg_temp.advertiser_payload('Archived Edit'))$$,'55000','ADVERTISER_NOT_EDITABLE','archived advertiser cannot be edited');
select lives_ok($$select public.change_advertiser_status('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000004','active')$$,'archived advertiser can be restored');
select throws_ok($$select public.change_advertiser_status('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000004','active')$$,'55000','INVALID_ADVERTISER_TRANSITION','same advertiser status rejected');
select throws_ok($$select public.change_advertiser_status('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001','archived')$$,'55000','ADVERTISER_HAS_ACTIVE_RESERVATIONS','advertiser with active reservation cannot be archived');

-- Campaign update behavior: validation parity, resize semantics, occupied protection, and auditing.
select throws_ok($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',null)$$,'22023','INVALID_CAMPAIGN','null campaign update payload rejected');
select throws_ok($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"slot_count":1.5}'))$$,'22023','INVALID_CAMPAIGN','fractional slot count rejected');
select throws_ok($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"mailing_quantity":"100"}'))$$,'22023','INVALID_CAMPAIGN','numeric string rejected');
select throws_ok($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"category_exclusivity_enabled":"true"}'))$$,'22023','INVALID_CAMPAIGN','string boolean rejected');
select throws_ok($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"publication_date":"2028-02-30"}'))$$,'22023','INVALID_CAMPAIGN','impossible date rejected safely');
select throws_ok($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"currency":"EUR"}'))$$,'22023','INVALID_CAMPAIGN','organization currency mismatch rejected');
select results_eq($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload())$$,array['51000000-0000-0000-0000-000000000001'::uuid],'campaign update returns authoritative id');
select results_eq($$select configured_slot_count::text||'|'||standard_slot_price_cents||'|'||name from public.campaigns where id='51000000-0000-0000-0000-000000000001'$$,array['3|12000|Updated Campaign'],'campaign fields and count updated');
select results_eq($$select count(*)::bigint from public.campaign_slots where campaign_id='51000000-0000-0000-0000-000000000001'$$,array[3::bigint],'campaign growth creates slot');
select results_eq($$select count(*)::bigint from public.campaign_slots where campaign_id='51000000-0000-0000-0000-000000000001' and status='available' and standard_price_cents=12000$$,array[2::bigint],'available slots receive new standard price');
select results_eq($$select standard_price_cents from public.campaign_slots where id='61000000-0000-0000-0000-000000000002'$$,array[10000::bigint],'occupied slot price is preserved');
select lives_ok($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"slot_count":2}'))$$,'campaign can remove highest available slot');
select results_eq($$select count(*)::bigint from public.campaign_slots where campaign_id='51000000-0000-0000-0000-000000000001'$$,array[2::bigint],'campaign shrink deletes only requested available slot');
select throws_ok($$select public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"slot_count":0}'))$$,'22023','INVALID_CAMPAIGN','slot count below domain minimum rejected');
select results_eq($$select count(*)::bigint from public.audit_events where event_type='campaign.updated' and entity_id='51000000-0000-0000-0000-000000000001'$$,array[2::bigint],'successful campaign updates audited');

-- Reservation cancellation and campaign transition side effects.
select throws_ok($$select public.cancel_reservation('21000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000002',null)$$,'22023','INVALID_CANCELLATION','null cancellation reason rejected');
select throws_ok($$select public.cancel_reservation('21000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000002','   ')$$,'22023','INVALID_CANCELLATION','blank cancellation reason rejected');
select lives_ok($$select * from public.cancel_reservation('21000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000002',' Client changed plans ')$$,'reservation cancellation succeeds');
select results_eq($$select status::text||'|'||cancellation_reason from public.placements where id='81000000-0000-0000-0000-000000000002'$$,array['canceled|Client changed plans'],'placement canceled with trimmed reason');
select results_eq($$select stage from public.opportunities where id='71000000-0000-0000-0000-000000000002'$$,array['lost'::public.opportunity_stage],'cancellation loses opportunity');
select results_eq($$select status from public.campaign_slots where id='61000000-0000-0000-0000-000000000003'$$,array['available'::public.slot_status],'cancellation releases unoccupied slot');
select throws_ok($$select public.cancel_reservation('21000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000002','Again')$$,'55000','RESERVATION_ALREADY_CANCELED','repeat cancellation rejected');
select throws_ok($$select public.cancel_reservation('21000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000004','Too late')$$,'55000','CANCELLATION_NOT_ALLOWED','published reservation cannot be canceled');
select results_eq($$select count(*)::bigint from public.audit_events where entity_id='81000000-0000-0000-0000-000000000002' and event_type='placement.canceled'$$,array[1::bigint],'reservation cancellation audited once');
select throws_ok($$select public.transition_campaign_status('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000003','proofing')$$,'55000','INVALID_CAMPAIGN_TRANSITION','invalid skipped transition rejected');
select lives_ok($$select * from public.transition_campaign_status('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000003','selling')$$,'valid campaign transition succeeds');
select throws_ok($$select public.cancel_campaign('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002','   ')$$,'22023','INVALID_CANCELLATION','campaign cancellation rejects blank reason');
select lives_ok($$select * from public.cancel_campaign('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002','Publication withdrawn')$$,'selling campaign can be canceled with reason');
select results_eq($$select status from public.placements where id='81000000-0000-0000-0000-000000000003'$$,array['canceled'::public.placement_status],'campaign cancellation cancels remaining placement');
select results_eq($$select stage from public.opportunities where id='71000000-0000-0000-0000-000000000003'$$,array['lost'::public.opportunity_stage],'campaign cancellation loses remaining opportunity');
select results_eq($$select count(*)::bigint from public.campaign_slots where campaign_id='51000000-0000-0000-0000-000000000002' and status='available'$$,array[2::bigint],'campaign cancellation releases all occupied slots');
select throws_ok($$select public.cancel_campaign('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000002','Again')$$,'55000','CAMPAIGN_ALREADY_TERMINAL','repeated campaign cancellation rejected');
select results_eq($$select count(*)::bigint from public.audit_events where event_type='placement.canceled' and details->>'campaign_id'='51000000-0000-0000-0000-000000000002' and details->>'reason'='Publication withdrawn'$$,array[1::bigint],'campaign cancellation audits each affected active placement');
select results_eq($$select count(*)::bigint from public.audit_events where event_type='slot.released' and details->>'campaign_id'='51000000-0000-0000-0000-000000000002' and details->>'reason'='Publication withdrawn'$$,array[1::bigint],'campaign cancellation audits actual slot releases once');
select results_eq($$select details->>'reason' from public.audit_events where event_type='campaign.status_changed' and entity_id='51000000-0000-0000-0000-000000000002'$$,array['Publication withdrawn'],'campaign cancellation audit records reason');
select results_eq($$select count(*)::bigint from public.audit_events where event_type='campaign.status_changed' and entity_id in ('51000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000003')$$,array[2::bigint],'campaign transitions audited');

-- Behavioral role-matrix assertions below invoke the real RPCs. Each helper uses a
-- subtransaction to verify the resulting row state and then rolls the mutation back,
-- keeping every case isolated while preserving exact SQLSTATE checks.
reset role;
insert into auth.users(id,email,encrypted_password,raw_user_meta_data,created_at,updated_at) values
 ('11000000-0000-0000-0000-000000000011','admin@example.com','x','{}',now(),now()),
 ('11000000-0000-0000-0000-000000000012','manager@example.com','x','{}',now(),now()),
 ('11000000-0000-0000-0000-000000000013','designer@example.com','x','{}',now(),now()),
 ('11000000-0000-0000-0000-000000000014','finance@example.com','x','{}',now(),now()),
 ('11000000-0000-0000-0000-000000000015','advertiser@example.com','x','{}',now(),now()),
 ('11000000-0000-0000-0000-000000000016','inactive@example.com','x','{}',now(),now()),
 ('11000000-0000-0000-0000-000000000017','mismatch@example.com','x','{}',now(),now());
insert into public.organization_memberships(id,organization_id,user_id,role,status) values
 ('31000000-0000-0000-0000-000000000011','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000011','administrator','active'),
 ('31000000-0000-0000-0000-000000000012','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000012','sales_manager','active'),
 ('31000000-0000-0000-0000-000000000013','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000013','designer','active'),
 ('31000000-0000-0000-0000-000000000014','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000014','finance','active'),
 ('31000000-0000-0000-0000-000000000015','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000015','advertiser','active'),
 ('31000000-0000-0000-0000-000000000016','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000016','owner','archived'),
 ('31000000-0000-0000-0000-000000000017','21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000017','owner','active');
insert into public.profiles(id,normalized_email,active_organization_id) values
 ('11000000-0000-0000-0000-000000000011','admin@example.com','21000000-0000-0000-0000-000000000001'),
 ('11000000-0000-0000-0000-000000000012','manager@example.com','21000000-0000-0000-0000-000000000001'),
 ('11000000-0000-0000-0000-000000000013','designer@example.com','21000000-0000-0000-0000-000000000001'),
 ('11000000-0000-0000-0000-000000000014','finance@example.com','21000000-0000-0000-0000-000000000001'),
 ('11000000-0000-0000-0000-000000000015','advertiser@example.com','21000000-0000-0000-0000-000000000001'),
 ('11000000-0000-0000-0000-000000000016','inactive@example.com','21000000-0000-0000-0000-000000000001'),
 ('11000000-0000-0000-0000-000000000017','mismatch@example.com','21000000-0000-0000-0000-000000000002');

create function pg_temp.rpc_case(action text, uid uuid, allowed boolean, from_status public.campaign_status default 'draft', to_status public.campaign_status default 'selling') returns boolean
language plpgsql security definer set search_path='' as $$
declare changed boolean:=false; state_before text; state_after text; expected_code text:='42501';
begin
 perform set_config('request.jwt.claim.sub',uid::text,true);
 if action='campaign_cancel' and from_status in ('completed','canceled') then expected_code:='55000'; end if;
 if action='advertiser_update' then select name into state_before from public.advertisers where id='41000000-0000-0000-0000-000000000001';
 elsif action='advertiser_status' then update public.advertisers set status='active' where id='41000000-0000-0000-0000-000000000004'; state_before:='active';
 elsif action='campaign_update' then update public.campaigns set status='draft',name='Editable' where id='51000000-0000-0000-0000-000000000001'; state_before:='Editable';
 elsif action='reservation_cancel' then update public.campaigns set status='draft' where id='51000000-0000-0000-0000-000000000001'; update public.placements set status='reserved',cancellation_reason=null where id='81000000-0000-0000-0000-000000000001'; state_before:='reserved';
 elsif action in ('transition','campaign_cancel') then update public.campaigns set status=from_status where id='51000000-0000-0000-0000-000000000003'; state_before:=from_status::text;
 end if;
 begin
  if action='advertiser_update' then perform public.update_advertiser_with_details('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Role Matrix')); select name into state_after from public.advertisers where id='41000000-0000-0000-0000-000000000001'; changed:=state_after='Role Matrix';
  elsif action='advertiser_status' then perform public.change_advertiser_status('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000004','archived'); select status::text into state_after from public.advertisers where id='41000000-0000-0000-0000-000000000004'; changed:=state_after='archived';
  elsif action='campaign_update' then perform public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',pg_temp.campaign_payload(jsonb_build_object('name','Role Matrix Campaign','slot_count',2))); select name into state_after from public.campaigns where id='51000000-0000-0000-0000-000000000001'; changed:=state_after='Role Matrix Campaign';
  elsif action='reservation_cancel' then perform public.cancel_reservation('21000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000001','Role matrix'); select status::text into state_after from public.placements where id='81000000-0000-0000-0000-000000000001'; changed:=state_after='canceled';
  elsif action='transition' then perform public.transition_campaign_status('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000003',to_status); select status::text into state_after from public.campaigns where id='51000000-0000-0000-0000-000000000003'; changed:=state_after=to_status::text;
  elsif action='campaign_cancel' then perform public.cancel_campaign('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000003','Role matrix'); select status::text into state_after from public.campaigns where id='51000000-0000-0000-0000-000000000003'; changed:=state_after='canceled'; end if;
  if not allowed then return false; end if;
  raise exception using errcode='P0001',message='ROLLBACK_CASE';
 exception when sqlstate 'P0001' then return changed;
  when others then
   if allowed then return false; end if;
   if sqlstate<>expected_code then return false; end if;
   if action='advertiser_update' then select name into state_after from public.advertisers where id='41000000-0000-0000-0000-000000000001';
   elsif action='advertiser_status' then select status::text into state_after from public.advertisers where id='41000000-0000-0000-0000-000000000004';
   elsif action='campaign_update' then select name into state_after from public.campaigns where id='51000000-0000-0000-0000-000000000001';
   elsif action='reservation_cancel' then select status::text into state_after from public.placements where id='81000000-0000-0000-0000-000000000001';
   else select status::text into state_after from public.campaigns where id='51000000-0000-0000-0000-000000000003'; end if;
   return state_after=state_before;
 end;
end $$;

-- Behavioral assertions: aggregate mutation role matrices.
select ok(pg_temp.rpc_case(action,uid,allowed),action||' role behavior: '||role_name)
from (values
 ('owner','11000000-0000-0000-0000-000000000001'::uuid,true),('administrator','11000000-0000-0000-0000-000000000011',true),('sales_manager','11000000-0000-0000-0000-000000000012',true),('salesperson','11000000-0000-0000-0000-000000000002',false),('designer','11000000-0000-0000-0000-000000000013',false),('finance','11000000-0000-0000-0000-000000000014',false),('advertiser','11000000-0000-0000-0000-000000000015',false)
) r(role_name,uid,allowed) cross join (values('advertiser_update'),('advertiser_status'),('campaign_update'),('reservation_cancel')) a(action);

-- Behavioral assertions: every documented forward transition for every role.
select ok(pg_temp.rpc_case('transition',uid,allowed,from_status,to_status),'transition '||from_status||' -> '||to_status||' role behavior: '||role_name)
from (values
 ('draft'::public.campaign_status,'selling'::public.campaign_status),('selling','artwork_collection'),('artwork_collection','proofing'),('proofing','ready_for_print'),('ready_for_print','sent_to_printer'),('sent_to_printer','mailed_or_published'),('mailed_or_published','completed')
) t(from_status,to_status)
cross join (values
 ('owner','11000000-0000-0000-0000-000000000001'::uuid,array['draft','selling','artwork_collection','proofing','ready_for_print','sent_to_printer','mailed_or_published']::text[]),
 ('administrator','11000000-0000-0000-0000-000000000011',array['draft','selling','artwork_collection','proofing','ready_for_print','sent_to_printer','mailed_or_published']),
 ('sales_manager','11000000-0000-0000-0000-000000000012',array['draft','selling','artwork_collection']),
 ('designer','11000000-0000-0000-0000-000000000013',array['proofing','ready_for_print']),
 ('salesperson','11000000-0000-0000-0000-000000000002',array[]::text[]),('finance','11000000-0000-0000-0000-000000000014',array[]::text[]),('advertiser','11000000-0000-0000-0000-000000000015',array[]::text[])
) r(role_name,uid,allowed_from)
cross join lateral (select from_status::text=any(allowed_from) allowed) x;

-- Behavioral assertions: cancellation authority in every lifecycle state.
select ok(pg_temp.rpc_case('campaign_cancel',uid,allowed,status,'selling'),'campaign cancellation from '||status||' role behavior: '||role_name)
from (values ('draft'::public.campaign_status),('selling'),('artwork_collection'),('proofing'),('ready_for_print'),('sent_to_printer'),('mailed_or_published'),('completed'),('canceled')) s(status)
cross join (values
 ('owner','11000000-0000-0000-0000-000000000001'::uuid,array['draft','selling','artwork_collection','proofing','ready_for_print','sent_to_printer','mailed_or_published']::text[]),
 ('administrator','11000000-0000-0000-0000-000000000011',array['draft','selling','artwork_collection','proofing','ready_for_print','sent_to_printer','mailed_or_published']),
 ('sales_manager','11000000-0000-0000-0000-000000000012',array['draft','selling','artwork_collection']),
 ('salesperson','11000000-0000-0000-0000-000000000002',array[]::text[]),('designer','11000000-0000-0000-0000-000000000013',array[]::text[]),('finance','11000000-0000-0000-0000-000000000014',array[]::text[]),('advertiser','11000000-0000-0000-0000-000000000015',array[]::text[])
) r(role_name,uid,allowed_from)
cross join lateral (select status::text=any(allowed_from) allowed) x;

create function pg_temp.context_case(action text, mode text) returns boolean language plpgsql security definer set search_path='' as $$
declare uid uuid:='11000000-0000-0000-0000-000000000001'; good boolean; old_org public.record_status; old_member public.record_status; old_active uuid; target uuid;
begin
 if mode='active' then return pg_temp.rpc_case(action,uid,true); end if;
 if mode='archived_organization' then select status into old_org from public.organizations where id='21000000-0000-0000-0000-000000000001'; update public.organizations set status='archived' where id='21000000-0000-0000-0000-000000000001';
 elsif mode='inactive_membership' then uid:='11000000-0000-0000-0000-000000000016';
 elsif mode='active_organization_mismatch' then uid:='11000000-0000-0000-0000-000000000017';
 elsif mode='advertiser_membership' then uid:='11000000-0000-0000-0000-000000000015';
 elsif mode='cross_tenant_id' then
  perform set_config('request.jwt.claim.sub',uid::text,true);
  begin
   if action='advertiser_update' then perform public.update_advertiser_with_details('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000003',pg_temp.advertiser_payload('Cross tenant'));
   elsif action='advertiser_status' then perform public.change_advertiser_status('21000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000003','archived');
   elsif action='campaign_update' then perform public.update_campaign_with_slots('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000005',pg_temp.campaign_payload());
   elsif action='transition' then perform public.transition_campaign_status('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000005','selling');
   elsif action='campaign_cancel' then perform public.cancel_campaign('21000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000005','Cross tenant');
   else perform public.cancel_reservation('21000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000005','Cross tenant'); end if;
   return false;
  exception when others then return sqlstate='22023'; end;
 end if;
 good:=pg_temp.rpc_case(action,uid,false);
 if mode='archived_organization' then update public.organizations set status=old_org where id='21000000-0000-0000-0000-000000000001'; end if;
 return good;
end $$;

-- Behavioral assertions: organization state and tenant isolation for every new RPC.
select ok(pg_temp.context_case(action,mode),action||' context behavior: '||mode)
from (values('advertiser_update'),('advertiser_status'),('campaign_update'),('transition'),('campaign_cancel'),('reservation_cancel')) a(action)
cross join (values('active'),('archived_organization'),('inactive_membership'),('active_organization_mismatch'),('cross_tenant_id'),('advertiser_membership')) m(mode);

select * from finish();
rollback;

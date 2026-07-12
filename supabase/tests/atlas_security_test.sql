begin;
create extension if not exists pgtap;
create function pg_temp.public_can_execute(target regprocedure) returns boolean language sql stable as $$
  select coalesce(bool_or(acl.privilege_type='EXECUTE' and acl.grantee=0),false)
  from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
  where p.oid=target
$$;
select plan(230);
select policies_are('public','advertisers',array['advertisers_select_internal'],'advertisers read-only internal');
select policies_are('public','advertiser_contacts',array['contacts_select_internal'],'contacts read-only internal');
select policies_are('public','advertiser_locations',array['locations_select_internal'],'locations read-only internal');
select policies_are('public','campaigns',array['campaigns_select_internal'],'campaigns read-only internal');
select policies_are('public','campaign_slots',array['slots_select_internal'],'slots read-only internal');
select policies_are('public','opportunities',array['opportunities_select_internal'],'opportunities read-only internal');
select policies_are('public','placements',array['placements_select_internal'],'placements read-only internal');
select policies_are('public','audit_events',array['audit_select_admin'],'audit append-only');
select policies_are('public','organization_memberships',array['memberships_select_internal'],'memberships cannot self-elevate');
select policies_are('public','profiles',array['profiles_select_self','profiles_update_self'],'profiles expose self');
select has_function('public','create_advertiser_with_details',array['uuid','jsonb'],'advertiser RPC');
select has_function('public','set_active_organization',array['uuid'],'active org RPC');
select has_function('public','create_organization_with_owner',array['text'],'onboarding RPC');
select has_function('public','create_campaign_with_slots',array['uuid','json'],'campaign RPC has the exact uuid,json signature');
select hasnt_function('public','create_campaign_with_slots',array['uuid','jsonb'],'campaign RPC has no uuid,jsonb overload');
select has_function('public','reserve_campaign_slot',array['uuid','uuid','uuid','bigint'],'reservation RPC');
select results_eq(
  $$select oid::regprocedure::text from pg_proc where pronamespace='public'::regnamespace and proname='create_campaign_with_slots' order by 1$$,
  array['create_campaign_with_slots(uuid,json)'::text],
  'campaign RPC has exactly one unambiguous overload'
);
select col_is_unique('public','advertisers',array['organization_id','normalized_name'],'normalized duplicate rejection');
select col_is_unique('public','organization_memberships',array['organization_id','id'],'membership composite key');
select fk_ok('public','opportunities',array['organization_id','assigned_membership_id'],'public','organization_memberships',array['organization_id','id'],'opportunity same-org membership');
select fk_ok('public','placements',array['organization_id','assigned_membership_id'],'public','organization_memberships',array['organization_id','id'],'placement same-org membership');
select ok(
  exists (
    select 1
    from pg_catalog.pg_class index_class
    join pg_catalog.pg_namespace index_namespace on index_namespace.oid=index_class.relnamespace
    join pg_catalog.pg_index index_catalog on index_catalog.indexrelid=index_class.oid
    join pg_catalog.pg_class table_class on table_class.oid=index_catalog.indrelid
    join pg_catalog.pg_namespace table_namespace on table_namespace.oid=table_class.relnamespace
    where index_namespace.nspname='public'
      and index_class.relname='one_active_placement_per_slot'
      and index_class.relkind='i'
      and table_namespace.nspname='public'
      and table_class.relname='placements'
      and index_catalog.indisunique
      and index_catalog.indpred is not null
      and pg_catalog.pg_get_indexdef(index_class.oid) like 'CREATE UNIQUE INDEX one_active_placement_per_slot ON public.placements USING btree (campaign_slot_id)%'
      and pg_catalog.pg_get_expr(index_catalog.indpred,index_catalog.indrelid) ~ '^\(status = ANY \(ARRAY\[''held''::(public\.)?placement_status, ''reserved''::(public\.)?placement_status, ''confirmed''::(public\.)?placement_status\]\)\)$'
  ),
  'active occupancy unique'
);
select function_privs_are('public','create_advertiser_with_details',array['uuid','jsonb'],'authenticated',array['EXECUTE'],'advertiser RPC privilege');
select function_privs_are('public','reserve_campaign_slot',array['uuid','uuid','uuid','bigint'],'authenticated',array['EXECUTE'],'reservation RPC privilege');
-- Structural privilege assertions: externally callable RPCs are authenticated-only.
select ok(not pg_temp.public_can_execute('public.set_active_organization(uuid)'::regprocedure),'PUBLIC cannot execute active-org RPC');
select ok(not has_function_privilege('anon','public.set_active_organization(uuid)','EXECUTE'),'anon cannot execute active-org RPC');
select ok(has_function_privilege('authenticated','public.set_active_organization(uuid)','EXECUTE'),'authenticated can execute active-org RPC');
select ok(not pg_temp.public_can_execute('public.create_organization_with_owner(text)'::regprocedure),'PUBLIC cannot execute onboarding RPC');
select ok(not has_function_privilege('anon','public.create_organization_with_owner(text)','EXECUTE'),'anon cannot execute onboarding RPC');
select ok(has_function_privilege('authenticated','public.create_organization_with_owner(text)','EXECUTE'),'authenticated can execute onboarding RPC');
select ok(not pg_temp.public_can_execute('public.create_advertiser_with_details(uuid,jsonb)'::regprocedure),'PUBLIC cannot execute advertiser RPC');
select ok(not has_function_privilege('anon','public.create_advertiser_with_details(uuid,jsonb)','EXECUTE'),'anon cannot execute advertiser RPC');
select ok(has_function_privilege('authenticated','public.create_advertiser_with_details(uuid,jsonb)','EXECUTE'),'authenticated can execute advertiser RPC');
select ok(not pg_temp.public_can_execute('public.create_campaign_with_slots(uuid,json)'::regprocedure),'PUBLIC cannot execute campaign RPC');
select ok(not has_function_privilege('anon','public.create_campaign_with_slots(uuid,json)','EXECUTE'),'anon cannot execute campaign RPC');
select ok(has_function_privilege('authenticated','public.create_campaign_with_slots(uuid,json)','EXECUTE'),'authenticated can execute campaign RPC');
select ok(not pg_temp.public_can_execute('public.reserve_campaign_slot(uuid,uuid,uuid,bigint)'::regprocedure),'PUBLIC cannot execute reservation RPC');
select ok(not has_function_privilege('anon','public.reserve_campaign_slot(uuid,uuid,uuid,bigint)','EXECUTE'),'anon cannot execute reservation RPC');
select ok(has_function_privilege('authenticated','public.reserve_campaign_slot(uuid,uuid,uuid,bigint)','EXECUTE'),'authenticated can execute reservation RPC');
select ok(not pg_temp.public_can_execute('public.is_active_org_member(uuid)'::regprocedure),'PUBLIC cannot execute active-member helper');
select ok(not has_function_privilege('anon','public.is_active_org_member(uuid)','EXECUTE'),'anon cannot execute active-member helper');
select ok(not pg_temp.public_can_execute('public.is_internal_org_member(uuid)'::regprocedure),'PUBLIC cannot execute internal-member helper');
select ok(not has_function_privilege('anon','public.is_internal_org_member(uuid)','EXECUTE'),'anon cannot execute internal-member helper');
select ok(not pg_temp.public_can_execute('public.has_org_role(uuid,public.organization_role[])'::regprocedure),'PUBLIC cannot execute role helper');
select ok(not has_function_privilege('anon','public.has_org_role(uuid,organization_role[])','EXECUTE'),'anon cannot execute role helper');
-- Structural assertions: metadata proves the defense exists, not its runtime behavior.
select has_trigger('public','profiles','profiles_set_updated_at','profiles updated_at trigger');
select has_trigger('public','organizations','organizations_set_updated_at','organizations updated_at trigger');
select has_trigger('public','organization_memberships','memberships_set_updated_at','memberships updated_at trigger');
select has_trigger('public','advertisers','advertisers_set_updated_at','advertisers updated_at trigger');
select has_trigger('public','advertiser_contacts','contacts_set_updated_at','contacts updated_at trigger');
select has_trigger('public','advertiser_locations','locations_set_updated_at','locations updated_at trigger');
select has_trigger('public','campaigns','campaigns_set_updated_at','campaigns updated_at trigger');
select has_trigger('public','campaign_slots','slots_set_updated_at','slots updated_at trigger');
select has_trigger('public','opportunities','opportunities_set_updated_at','opportunities updated_at trigger');
select has_trigger('public','placements','placements_set_updated_at','placements updated_at trigger');
select fk_ok('public','placements',array['organization_id','campaign_id','campaign_slot_id'],'public','campaign_slots',array['organization_id','campaign_id','id'],'placement slot belongs to campaign and organization');
select function_returns('public','set_updated_at',array[]::text[],'trigger','updated_at trigger function');
select function_lang_is('public','set_updated_at',array[]::text[],'plpgsql','updated_at trigger uses plpgsql');
select function_privs_are('public','set_updated_at',array[]::text[],'authenticated',array[]::text[],'clients cannot execute trigger function');
select isnt_empty($$select 1 from pg_proc where oid='public.create_organization_with_owner(text)'::regprocedure and prosrc like '%for update%'$$,'onboarding function serializes on auth user row (structural; multi-session harness required)');

create function pg_temp.campaign_payload(overrides jsonb default '{}'::jsonb) returns json language sql immutable as $$
 select ('{"name":"Validation Campaign","territory":"A","product_type":"Postcard","publication_date":"2028-03-05","sales_deadline":"2028-03-01","artwork_deadline":"2028-03-02","proof_deadline":"2028-03-03","print_deadline":"2028-03-04","mailing_quantity":100,"estimated_printing_cost_cents":0,"estimated_postage_cost_cents":0,"slot_count":1,"standard_slot_price_cents":100,"category_exclusivity_enabled":false}'::jsonb || overrides)::json
$$;
create function pg_temp.campaign_all_dates(value text, campaign_name text) returns json language sql immutable as $$
 select pg_temp.campaign_payload(jsonb_build_object('name',campaign_name,'publication_date',value,'sales_deadline',value,'artwork_deadline',value,'proof_deadline',value,'print_deadline',value))
$$;
create function pg_temp.advertiser_payload(advertiser_name text,contact_email text) returns jsonb language sql immutable as $$
 select jsonb_build_object('name',advertiser_name,'category','Dental','contact_name','Person','email',contact_email,'phone','','address_line_1','1 Main','city','Town','state','WV','postal_code','26000')
$$;

-- Behavioral assertions: controlled authenticated JWT simulation against real RLS/RPC behavior.
insert into auth.users(id,aud,role,email,encrypted_password) values
 ('10000000-0000-0000-0000-000000000001','authenticated','authenticated','owner@example.test','x'),
 ('10000000-0000-0000-0000-000000000002','authenticated','authenticated','other@example.test','x'),
 ('10000000-0000-0000-0000-000000000003','authenticated','authenticated','portal@example.test','x');
insert into public.organizations(id,name,status) values
 ('20000000-0000-0000-0000-000000000001','Active A','active'),
 ('20000000-0000-0000-0000-000000000002','Active B','active'),
 ('20000000-0000-0000-0000-000000000003','Archived','archived');
insert into public.organization_memberships(id,organization_id,user_id,role,status) values
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','owner','active'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','owner','active'),
 ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003','advertiser','active'),
 ('30000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','owner','active');
insert into public.advertisers(id,organization_id,name,normalized_name,category) values
 ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Tenant A Advertiser','tenant a advertiser','Dental'),
 ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Tenant B Advertiser','tenant b advertiser','Dental'),
 ('40000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000003','Archived Advertiser','archived advertiser','Dental');
insert into public.advertisers(id,organization_id,name,normalized_name,category) values
 ('40000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','Competitor','competitor','Dental');
insert into public.campaigns(id,organization_id,name,territory,product_type,currency,publication_date,sales_deadline,artwork_deadline,proof_deadline,print_deadline,mailing_quantity,estimated_printing_cost_cents,estimated_postage_cost_cents,configured_slot_count,standard_slot_price_cents,category_exclusivity_enabled,status) values
 ('50000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Selling','A','Postcard','USD','2026-12-05','2026-12-01','2026-12-02','2026-12-03','2026-12-04',100,0,0,3,10000,true,'selling'),
 ('50000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','Draft','A','Postcard','USD','2026-12-05','2026-12-01','2026-12-02','2026-12-03','2026-12-04',100,0,0,1,10000,false,'draft'),
 ('50000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','Tenant B Campaign','B','Postcard','USD','2026-12-05','2026-12-01','2026-12-02','2026-12-03','2026-12-04',100,0,0,1,10000,false,'selling');
insert into public.campaign_slots(id,organization_id,campaign_id,identifier,side_or_section,standard_price_cents,currency) values
 ('60000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','A1','Front',10000,'USD'),
 ('60000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','A2','Back',10000,'USD'),
 ('60000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','A3','Inside',10000,'USD'),
 ('60000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002','D1','Front',10000,'USD'),
 ('60000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000002','50000000-0000-0000-0000-000000000003','B1','Front',10000,'USD');
insert into public.opportunities(id,organization_id,advertiser_id,campaign_id,assigned_membership_id,stage) values('70000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','reserved');
select throws_ok($$insert into public.placements(organization_id,campaign_id,campaign_slot_id,advertiser_id,opportunity_id,assigned_membership_id,status,sale_price_cents,currency) values('20000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','reserved',10000,'USD')$$,'23503',null,'placement cannot reference a slot from another campaign');

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000001';
select results_eq($$select count(*)::bigint from public.advertisers where organization_id='20000000-0000-0000-0000-000000000002'$$,array[0::bigint],'cross-organization SELECT denied');
select throws_ok($$insert into public.advertisers(organization_id,name,normalized_name,category) values('20000000-0000-0000-0000-000000000002','Attack','attack','Other')$$,'42501',null,'cross-organization direct INSERT denied');
select throws_ok($$update public.advertisers set name='Attack' where id='40000000-0000-0000-0000-000000000002'$$,'42501',null,'cross-organization direct UPDATE denied');
select throws_ok($$delete from public.advertisers where id='40000000-0000-0000-0000-000000000002'$$,'42501',null,'cross-organization direct DELETE denied');
select throws_ok($$update public.organization_memberships set role='owner' where id='30000000-0000-0000-0000-000000000001'$$,'42501',null,'self-role elevation denied');
select throws_ok($$select public.create_organization_with_owner('Repeat')$$,'42501','ONBOARDING_ALREADY_COMPLETE','repeat onboarding denied');
select throws_ok($$select public.set_active_organization('20000000-0000-0000-0000-000000000002')$$,'42501','INVALID_ACTIVE_ORGANIZATION','invalid active organization denied');
select throws_ok($$select public.set_active_organization('20000000-0000-0000-0000-000000000003')$$,'42501','INVALID_ACTIVE_ORGANIZATION','archived organization selection denied');
select results_eq($$select count(*)::bigint from public.advertisers where organization_id='20000000-0000-0000-0000-000000000003'$$,array[0::bigint],'archived organization read denied');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000003','{}'::jsonb)$$,'42501','NOT_AUTHORIZED','archived organization mutation denied');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',jsonb_build_object('name','Email Bad','category','Dental','contact_name','Person','email','bad @example.com','phone','','address_line_1','1 Main','city','Town','state','WV','postal_code','26000'))$$,'22023','INVALID_CONTACT_EMAIL','RPC rejects malformed email and rolls back advertiser aggregate');
select results_eq($$select count(*)::bigint from public.advertisers where normalized_name='email bad'$$,array[0::bigint],'transactional advertiser rollback leaves no parent');
select lives_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Valid Plain','person@example.com'))$$,'advertiser email accepts a basic address');
select lives_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Valid Dotted','first.last@example.co.uk'))$$,'advertiser email accepts dotted local and multi-label domain');
select lives_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Valid Tagged','user+tag@example.com'))$$,'advertiser email accepts plus tags');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Consecutive Dots','a..b@example.com'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email rejects consecutive local periods');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Leading Dot','.abc@example.com'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email rejects leading local period');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Trailing Dot','abc.@example.com'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email rejects trailing local period');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Leading Hyphen','abc@-example.com'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email rejects leading domain-label hyphen');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Trailing Hyphen','abc@example-.com'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email rejects trailing domain-label hyphen');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email No Domain Dot','abc@example'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email requires a domain period');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Two Separators','abc@@example.com'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email requires exactly one at separator');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Space','abc @example.com'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email rejects whitespace');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Local Too Long',repeat('a',65)||'@example.com'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email rejects an overlong local part');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',pg_temp.advertiser_payload('Email Total Too Long',repeat('a',64)||'@'||repeat('b',63)||'.'||repeat('c',63)||'.'||repeat('d',63)||'.com'))$$,'22023','INVALID_CONTACT_EMAIL','advertiser email rejects an overlong total address');
select throws_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000001',jsonb_build_object('name',' Tenant A Advertiser ','category','Dental','contact_name','Person','email','valid@example.com','phone','','address_line_1','1 Main','city','Town','state','WV','postal_code','26000'))$$,'23505','DUPLICATE_ADVERTISER','normalized duplicate advertiser rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',null)$$,'22023','INVALID_CAMPAIGN','SQL NULL campaign payload rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001','null'::json)$$,'22023','INVALID_CAMPAIGN','JSON null campaign payload rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',json_build_object('name','Bad','territory','A','product_type','Postcard','publication_date','2026-12-05','sales_deadline','2026-12-01','artwork_deadline','2026-12-02','proof_deadline','2026-12-03','print_deadline','2026-12-04','mailing_quantity',1,'estimated_printing_cost_cents',0,'estimated_postage_cost_cents',0,'slot_count',1,'standard_slot_price_cents',100,'category_exclusivity_enabled','false'))$$,'22023','INVALID_CAMPAIGN','non-boolean exclusivity rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',json_build_object('name','Bad','territory','A','product_type','Postcard','publication_date','not-a-date','sales_deadline','2026-12-01','artwork_deadline','2026-12-02','proof_deadline','2026-12-03','print_deadline','2026-12-04','mailing_quantity',1,'estimated_printing_cost_cents',0,'estimated_postage_cost_cents',0,'slot_count',1,'standard_slot_price_cents',100,'category_exclusivity_enabled',false))$$,'22023','INVALID_CAMPAIGN','campaign conversion exception maps to safe error');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"slot_count":1.5}'))$$,'22023','INVALID_CAMPAIGN','fractional slot count rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"mailing_quantity":1.5}'))$$,'22023','INVALID_CAMPAIGN','fractional mailing quantity rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"estimated_printing_cost_cents":1.5}'))$$,'22023','INVALID_CAMPAIGN','fractional printing cents rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"estimated_postage_cost_cents":1.5}'))$$,'22023','INVALID_CAMPAIGN','fractional postage cents rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"standard_slot_price_cents":1.5}'))$$,'22023','INVALID_CAMPAIGN','fractional standard slot price cents rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001','{"name":"Scientific","territory":"A","product_type":"Postcard","publication_date":"2028-03-05","sales_deadline":"2028-03-01","artwork_deadline":"2028-03-02","proof_deadline":"2028-03-03","print_deadline":"2028-03-04","mailing_quantity":1e3,"estimated_printing_cost_cents":0,"estimated_postage_cost_cents":0,"slot_count":1,"standard_slot_price_cents":100,"category_exclusivity_enabled":false}'::json)$$,'22023','INVALID_CAMPAIGN','scientific-notation integer input rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"mailing_quantity":"100"}'))$$,'22023','INVALID_CAMPAIGN','numeric string rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"slot_count":2.0}'))$$,'22023','INVALID_CAMPAIGN','decimal-form integer rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"mailing_quantity":-1}'))$$,'22023','INVALID_CAMPAIGN','negative non-negative field rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"standard_slot_price_cents":100000000001}'))$$,'22023','INVALID_CAMPAIGN','out-of-range integer rejected before cast');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"slot_count":null}'))$$,'22023','INVALID_CAMPAIGN','null integer field rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"publication_date":"infinity"}'))$$,'22023','INVALID_CAMPAIGN','positive infinity date rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"publication_date":"-infinity"}'))$$,'22023','INVALID_CAMPAIGN','negative infinity date rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"publication_date":"2028-3-05"}'))$$,'22023','INVALID_CAMPAIGN','noncanonical date string rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"publication_date":"2028-02-30"}'))$$,'22023','INVALID_CAMPAIGN','impossible date rejected');
select lives_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"name":"Valid Leap Campaign","publication_date":"2028-02-29","print_deadline":"2028-02-29","proof_deadline":"2028-02-28","artwork_deadline":"2028-02-27","sales_deadline":"2028-02-26"}'))$$,'valid leap-year date accepted');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"publication_date":"2027-02-29"}'))$$,'22023','INVALID_CAMPAIGN','non-leap-year February 29 rejected');

-- Parser-level malformed-JSON assertion: 01 is rejected before a json argument or RPC call can exist.
select throws_ok(
  $$select '{"mailing_quantity":01}'::json$$,
  '22P02',null,
  'transport/parser level: a leading-zero JSON number is rejected before RPC validation'
);

-- Behavioral integer boundary assertions. All valid JSON failures must map to INVALID_CAMPAIGN.
select throws_ok(
  $$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',(pg_temp.campaign_payload()::jsonb - 'mailing_quantity')::json)$$,
  '22023','INVALID_CAMPAIGN','missing integer property rejected'
);
select throws_ok(
  $$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"mailing_quantity":9223372036854775808}'))$$,
  '22023','INVALID_CAMPAIGN','numeric token larger than PostgreSQL bigint maps safely'
);
select lives_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"name":"Mailing Zero","mailing_quantity":0}'))$$,'mailing quantity zero/minimum accepted');
select lives_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"name":"Mailing Max","mailing_quantity":10000000}'))$$,'mailing quantity maximum accepted');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"mailing_quantity":10000001}'))$$,'22023','INVALID_CAMPAIGN','mailing quantity above maximum rejected');
select lives_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"name":"Slot Min","slot_count":1}'))$$,'slot count minimum accepted');
select lives_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"name":"Slot Max","slot_count":500}'))$$,'slot count maximum accepted');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"slot_count":0}'))$$,'22023','INVALID_CAMPAIGN','slot count below minimum rejected');
select throws_ok($$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload('{"slot_count":501}'))$$,'22023','INVALID_CAMPAIGN','slot count above maximum rejected');
select case when valid then lives_ok(statement,label) else throws_ok(statement,'22023','INVALID_CAMPAIGN',label) end
from (
  select value >= 0 and value <= 100000000000 as valid,
    format($sql$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload(%L::jsonb))$sql$,
      jsonb_build_object('name',format('%s %s',key,value),'slot_count',1,key,value)::text) as statement,
    format('%s value %s %s',key,value,description) as label
  from (values
    ('estimated_printing_cost_cents',0::numeric,'zero/minimum accepted'),('estimated_printing_cost_cents',100000000000,'maximum accepted'),('estimated_printing_cost_cents',-1,'below minimum rejected'),('estimated_printing_cost_cents',100000000001,'above maximum rejected'),
    ('estimated_postage_cost_cents',0,'zero/minimum accepted'),('estimated_postage_cost_cents',100000000000,'maximum accepted'),('estimated_postage_cost_cents',-1,'below minimum rejected'),('estimated_postage_cost_cents',100000000001,'above maximum rejected'),
    ('standard_slot_price_cents',0,'zero/minimum accepted'),('standard_slot_price_cents',100000000000,'maximum accepted'),('standard_slot_price_cents',-1,'below minimum rejected'),('standard_slot_price_cents',100000000001,'above maximum rejected')
  ) cases(key,value,description)
) assertions;

-- Behavioral date assertions: every campaign date field receives the complete invalid-input matrix.
select throws_ok(
  format($sql$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',%s)$sql$,
    case when kind='missing' then format('(pg_temp.campaign_payload()::jsonb - %L)::json',field)
         else format('pg_temp.campaign_payload(%L::jsonb)',jsonb_build_object(field,value)::text) end),
  '22023','INVALID_CAMPAIGN',format('%s rejects %s',field,label)
)
from (values ('publication_date'),('sales_deadline'),('artwork_deadline'),('proof_deadline'),('print_deadline')) fields(field)
cross join (values
  ('missing','missing',null::jsonb),('null','JSON null','null'::jsonb),('value','non-string','42'::jsonb),('value','empty string','""'::jsonb),
  ('value','infinity','"infinity"'::jsonb),('value','-infinity','"-infinity"'::jsonb),('value','epoch','"epoch"'::jsonb),
  ('value','timestamp instead of date','"2028-03-05T00:00:00Z"'::jsonb),('value','slash-separated date','"2028/03/05"'::jsonb),
  ('value','non-zero-padded date','"2028-3-05"'::jsonb),('value','impossible calendar date','"2028-02-30"'::jsonb),
  ('value','invalid non-leap-year February 29','"2027-02-29"'::jsonb)
) invalid_dates(kind,label,value);

-- Each field is also exercised with canonical, leap-year, and relative canonical dates.
select lives_ok(
  format($sql$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_all_dates(%L,%L))$sql$,value,format('%s %s',field,label)),
  format('%s accepts %s',field,label)
)
from (values ('publication_date'),('sales_deadline'),('artwork_deadline'),('proof_deadline'),('print_deadline')) fields(field)
cross join lateral (values
  ('canonical YYYY-MM-DD','2028-03-05'),('valid leap-year February 29','2028-02-29'),
  ('today',current_date::text),('tomorrow',(current_date+1)::text),('yesterday',(current_date-1)::text)
) valid_dates(label,value);

select throws_ok(
  format($sql$select public.create_campaign_with_slots('20000000-0000-0000-0000-000000000001',pg_temp.campaign_payload(%L::jsonb))$sql$,override::text),
  '22023','INVALID_CAMPAIGN',label
)
from (values
  ('{"sales_deadline":"2028-03-03","artwork_deadline":"2028-03-02"}'::jsonb,'sales after artwork rejected'),
  ('{"artwork_deadline":"2028-03-04","proof_deadline":"2028-03-03"}'::jsonb,'artwork after proof rejected'),
  ('{"proof_deadline":"2028-03-05","print_deadline":"2028-03-04"}'::jsonb,'proof after print rejected'),
  ('{"print_deadline":"2028-03-06","publication_date":"2028-03-05"}'::jsonb,'print after publication rejected')
) ordering(override,label);

-- Multi-session concurrency assertions remain in scripts/concurrency-harness.mjs, not this transaction.
select lives_ok($$select public.reserve_campaign_slot('20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',10000)$$,'first reservation succeeds');
select lives_ok($$select public.reserve_campaign_slot('20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001',10000)$$,'same advertiser may reserve multiple slots');
select throws_ok($$select public.reserve_campaign_slot('20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000004',10000)$$,'55000','CATEGORY_CONFLICT','competing category rejected on different slot');
select throws_ok($$select public.reserve_campaign_slot('20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000001',10000)$$,'55000','RESERVATION_UNAVAILABLE','reservation denied for non-Selling campaign');
select throws_ok($$select public.reserve_campaign_slot('20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000002',10000)$$,'22023','INVALID_RESERVATION','cross-tenant advertiser rejected');
select throws_ok($$select public.reserve_campaign_slot('20000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000005','40000000-0000-0000-0000-000000000001',10000)$$,'22023','INVALID_RESERVATION','cross-tenant slot rejected');
select results_eq($$select count(*)::bigint from public.audit_events where event_type='slot.reserved'$$,array[2::bigint],'required reservation audit events created');
select throws_ok($$update public.audit_events set event_type='tampered'$$,'42501',null,'audit UPDATE denied');
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';
select lives_ok($$select public.create_advertiser_with_details('20000000-0000-0000-0000-000000000002',jsonb_build_object('name','Tenant A Advertiser','category','Dental','contact_name','Person','email','valid@example.com','phone','','address_line_1','1 Main','city','Town','state','WV','postal_code','26000'))$$,'same advertiser name allowed in different organizations');
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000003';
select results_eq($$select count(*)::bigint from public.advertisers$$,array[0::bigint],'advertiser role denied internal workspace records');
select throws_ok($$delete from public.audit_events$$,'42501',null,'audit DELETE denied');
select * from finish();
rollback;

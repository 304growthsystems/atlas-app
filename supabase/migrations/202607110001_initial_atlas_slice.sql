create extension if not exists pgcrypto;

create type public.organization_role as enum ('owner','administrator','sales_manager','salesperson','designer','finance','advertiser');
create type public.record_status as enum ('active','archived');
create type public.campaign_status as enum ('draft','selling','artwork_collection','proofing','ready_for_print','sent_to_printer','mailed_or_published','completed','canceled');
create type public.slot_status as enum ('available','held','reserved','sold','house_ad','unavailable');
create type public.opportunity_stage as enum ('new_lead','contacted','follow_up','interested','proposal_sent','reserved','won','lost','renewal_due');
create type public.placement_status as enum ('held','reserved','confirmed','completed','canceled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (display_name is null or (length(trim(display_name)) between 1 and 160)),
  normalized_email text not null check (length(normalized_email) between 3 and 320),
  active_organization_id uuid,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.organizations (
  id uuid primary key default gen_random_uuid(), name text not null check (length(trim(name)) between 1 and 160),
  default_currency text not null default 'USD' check (default_currency ~ '^[A-Z]{3}$'),
  timezone text not null default 'America/New_York' check (length(trim(timezone)) between 1 and 100),
  default_deposit_percent integer not null default 100 check (default_deposit_percent between 0 and 100),
  refund_approval_threshold_cents bigint not null default 50000 check (refund_approval_threshold_cents >= 0),
  status public.record_status not null default 'active', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.profiles add constraint profiles_active_organization_fk foreign key(active_organization_id) references public.organizations(id) on delete set null;
create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  user_id uuid not null references auth.users(id), role public.organization_role not null,
  status public.record_status not null default 'active', joined_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(organization_id,user_id), unique(organization_id,id)
);
create table public.advertisers (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  name text not null check (length(trim(name)) between 1 and 160), normalized_name text not null check (length(normalized_name) between 1 and 160),
  category text not null check (length(trim(category)) between 1 and 80), status public.record_status not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(organization_id,id), unique(organization_id,normalized_name)
);
create table public.advertiser_contacts (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, advertiser_id uuid not null,
  name text not null check (length(trim(name)) between 1 and 160), email text check(email is null or length(email)<=320), phone text check(phone is null or length(phone)<=40),
  is_primary boolean not null default false, status public.record_status not null default 'active', created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key(organization_id,advertiser_id) references public.advertisers(organization_id,id)
);
create unique index one_primary_contact on public.advertiser_contacts(advertiser_id) where is_primary and status='active';
create table public.advertiser_locations (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, advertiser_id uuid not null,
  address_line_1 text not null check (length(trim(address_line_1)) between 1 and 200), address_line_2 text check(address_line_2 is null or length(address_line_2)<=200),
  city text not null check(length(trim(city)) between 1 and 100), state text not null check(length(trim(state)) between 1 and 100), postal_code text not null check(length(trim(postal_code)) between 1 and 20),
  is_primary boolean not null default false, status public.record_status not null default 'active', created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key(organization_id,advertiser_id) references public.advertisers(organization_id,id)
);
create unique index one_primary_location on public.advertiser_locations(advertiser_id) where is_primary and status='active';
create table public.campaigns (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
  name text not null check(length(trim(name)) between 1 and 160), territory text not null check(length(trim(territory)) between 1 and 160), product_type text not null check(length(trim(product_type)) between 1 and 100),
  currency text not null check(currency ~ '^[A-Z]{3}$'), publication_date date not null, sales_deadline date not null, artwork_deadline date not null, proof_deadline date not null, print_deadline date not null,
  mailing_quantity integer not null check(mailing_quantity between 0 and 10000000), estimated_printing_cost_cents bigint not null check(estimated_printing_cost_cents between 0 and 100000000000),
  estimated_postage_cost_cents bigint not null check(estimated_postage_cost_cents between 0 and 100000000000), configured_slot_count integer not null check(configured_slot_count between 1 and 500),
  standard_slot_price_cents bigint not null check(standard_slot_price_cents between 0 and 100000000000), category_exclusivity_enabled boolean not null default false,
  status public.campaign_status not null default 'selling', created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(organization_id,id),
  check(sales_deadline<=artwork_deadline and artwork_deadline<=proof_deadline and proof_deadline<=print_deadline and print_deadline<=publication_date)
);
create table public.campaign_slots (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, campaign_id uuid not null,
  identifier text not null check(length(trim(identifier)) between 1 and 100), side_or_section text not null check(length(trim(side_or_section)) between 1 and 100),
  status public.slot_status not null default 'available', standard_price_cents bigint not null check(standard_price_cents between 0 and 100000000000), currency text not null check(currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), foreign key(organization_id,campaign_id) references public.campaigns(organization_id,id),
  unique(campaign_id,identifier), unique(organization_id,id), unique(organization_id,campaign_id,id)
);
create table public.opportunities (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, advertiser_id uuid not null, campaign_id uuid,
  assigned_membership_id uuid not null, stage public.opportunity_stage not null default 'new_lead', estimated_value_cents bigint check(estimated_value_cents between 0 and 100000000000),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), foreign key(organization_id,advertiser_id) references public.advertisers(organization_id,id),
  foreign key(organization_id,campaign_id) references public.campaigns(organization_id,id), foreign key(organization_id,assigned_membership_id) references public.organization_memberships(organization_id,id), unique(organization_id,id)
);
create table public.placements (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, campaign_id uuid not null, campaign_slot_id uuid not null, advertiser_id uuid not null,
  opportunity_id uuid not null, assigned_membership_id uuid not null, status public.placement_status not null, sale_price_cents bigint not null check(sale_price_cents between 0 and 100000000000),
  currency text not null check(currency ~ '^[A-Z]{3}$'), category text, canceled_at timestamptz, cancellation_reason text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), foreign key(organization_id,campaign_id) references public.campaigns(organization_id,id),
  foreign key(organization_id,campaign_id,campaign_slot_id) references public.campaign_slots(organization_id,campaign_id,id), foreign key(organization_id,advertiser_id) references public.advertisers(organization_id,id),
  foreign key(organization_id,opportunity_id) references public.opportunities(organization_id,id), foreign key(organization_id,assigned_membership_id) references public.organization_memberships(organization_id,id)
);
create unique index one_active_placement_per_slot on public.placements(campaign_slot_id) where status in ('held','reserved','confirmed');
create table public.audit_events (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), actor_user_id uuid not null references auth.users(id),
  event_type text not null check(length(trim(event_type)) between 1 and 100), entity_type text not null check(length(trim(entity_type)) between 1 and 100), entity_id uuid not null,
  details jsonb not null default '{}', created_at timestamptz not null default now()
);

create function public.set_updated_at() returns trigger language plpgsql security invoker set search_path='' as $$
begin new.updated_at = now(); return new; end $$;
revoke all on function public.set_updated_at() from public,anon,authenticated;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger organizations_set_updated_at before update on public.organizations for each row execute function public.set_updated_at();
create trigger memberships_set_updated_at before update on public.organization_memberships for each row execute function public.set_updated_at();
create trigger advertisers_set_updated_at before update on public.advertisers for each row execute function public.set_updated_at();
create trigger contacts_set_updated_at before update on public.advertiser_contacts for each row execute function public.set_updated_at();
create trigger locations_set_updated_at before update on public.advertiser_locations for each row execute function public.set_updated_at();
create trigger campaigns_set_updated_at before update on public.campaigns for each row execute function public.set_updated_at();
create trigger slots_set_updated_at before update on public.campaign_slots for each row execute function public.set_updated_at();
create trigger opportunities_set_updated_at before update on public.opportunities for each row execute function public.set_updated_at();
create trigger placements_set_updated_at before update on public.placements for each row execute function public.set_updated_at();

create function public.is_active_org_member(org_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.organization_memberships m join public.organizations o on o.id=m.organization_id where m.organization_id=org_id and m.user_id=auth.uid() and m.status='active' and o.status='active')
$$;
create function public.is_internal_org_member(org_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.organization_memberships m join public.organizations o on o.id=m.organization_id where m.organization_id=org_id and m.user_id=auth.uid() and m.status='active' and o.status='active' and m.role in ('owner','administrator','sales_manager','salesperson','designer','finance'))
$$;
create function public.has_org_role(org_id uuid, roles public.organization_role[]) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.organization_memberships m join public.organizations o on o.id=m.organization_id where m.organization_id=org_id and m.user_id=auth.uid() and m.status='active' and o.status='active' and m.role=any(roles))
$$;

alter table public.profiles enable row level security; alter table public.organizations enable row level security; alter table public.organization_memberships enable row level security;
alter table public.advertisers enable row level security; alter table public.advertiser_contacts enable row level security; alter table public.advertiser_locations enable row level security;
alter table public.campaigns enable row level security; alter table public.campaign_slots enable row level security; alter table public.opportunities enable row level security;
alter table public.placements enable row level security; alter table public.audit_events enable row level security;
create policy profiles_select_self on public.profiles for select to authenticated using(id=auth.uid());
create policy profiles_update_self on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy organizations_select_internal on public.organizations for select to authenticated using(public.is_internal_org_member(id));
create policy memberships_select_internal on public.organization_memberships for select to authenticated using(public.is_internal_org_member(organization_id));
create policy advertisers_select_internal on public.advertisers for select to authenticated using(public.is_internal_org_member(organization_id));
create policy contacts_select_internal on public.advertiser_contacts for select to authenticated using(public.is_internal_org_member(organization_id));
create policy locations_select_internal on public.advertiser_locations for select to authenticated using(public.is_internal_org_member(organization_id));
create policy campaigns_select_internal on public.campaigns for select to authenticated using(public.is_internal_org_member(organization_id));
create policy slots_select_internal on public.campaign_slots for select to authenticated using(public.is_internal_org_member(organization_id));
create policy opportunities_select_internal on public.opportunities for select to authenticated using(public.is_internal_org_member(organization_id));
create policy placements_select_internal on public.placements for select to authenticated using(public.is_internal_org_member(organization_id));
create policy audit_select_admin on public.audit_events for select to authenticated using(public.has_org_role(organization_id,array['owner','administrator']::public.organization_role[]));

create function public.set_active_organization(org_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); begin
 if uid is null then raise exception using errcode='28000', message='AUTH_REQUIRED'; end if;
 if not public.is_active_org_member(org_id) then raise exception using errcode='42501', message='INVALID_ACTIVE_ORGANIZATION'; end if;
 insert into public.profiles(id,display_name,normalized_email,active_organization_id)
 select uid,coalesce(nullif(trim(u.raw_user_meta_data->>'display_name'),''),split_part(u.email,'@',1)),lower(u.email),org_id from auth.users u where u.id=uid
 on conflict(id) do update set active_organization_id=excluded.active_organization_id,updated_at=now(); return org_id;
end $$;
create function public.create_organization_with_owner(org_name text) returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); oid uuid; clean_name text:=trim(org_name); begin
 if uid is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 perform 1 from auth.users where id=uid for update;
 if not found then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 if exists(select 1 from public.organization_memberships m join public.organizations o on o.id=m.organization_id where m.user_id=uid and m.status='active' and o.status='active') then raise exception using errcode='42501',message='ONBOARDING_ALREADY_COMPLETE'; end if;
 if clean_name is null or length(clean_name) not between 1 and 160 then raise exception using errcode='22023',message='INVALID_ORGANIZATION'; end if;
 insert into public.organizations(name) values(clean_name) returning id into oid;
 insert into public.organization_memberships(organization_id,user_id,role) values(oid,uid,'owner');
 insert into public.profiles(id,display_name,normalized_email,active_organization_id) select uid,coalesce(nullif(trim(raw_user_meta_data->>'display_name'),''),split_part(email,'@',1)),lower(email),oid from auth.users where id=uid
 on conflict(id) do update set active_organization_id=excluded.active_organization_id,updated_at=now();
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id) values(oid,uid,'organization.created','organization',oid); return oid;
end $$;
create function public.create_advertiser_with_details(org_id uuid,payload jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); aid uuid; clean_name text; normalized text; contact_name text; address1 text; contact_email text; email_local text; email_domain text; begin
 if uid is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 if not public.has_org_role(org_id,array['owner','administrator','sales_manager']::public.organization_role[]) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if payload is null or jsonb_typeof(payload)<>'object' then raise exception using errcode='22023',message='INVALID_ADVERTISER'; end if;
 clean_name:=trim(payload->>'name'); normalized:=lower(clean_name); contact_name:=trim(payload->>'contact_name'); address1:=trim(payload->>'address_line_1'); contact_email:=trim(payload->>'email');
 if jsonb_typeof(payload)<>'object' or clean_name is null or length(clean_name) not between 1 and 160 or length(normalized)>160 or length(trim(payload->>'category')) not between 1 and 80 then raise exception using errcode='22023',message='INVALID_ADVERTISER'; end if;
 if exists(select 1 from public.advertisers where organization_id=org_id and normalized_name=normalized) then raise exception using errcode='23505',message='DUPLICATE_ADVERTISER'; end if;
 if contact_name is null or contact_name='' or length(contact_name)>160 or length(coalesce(payload->>'phone',''))>40 then raise exception using errcode='22023',message='INVALID_CONTACT'; end if;
 if contact_email is not null and contact_email<>'' then
  if length(contact_email)>254 or contact_email ~ '[[:space:]]' or length(contact_email)-length(replace(contact_email,'@',''))<>1 then raise exception using errcode='22023',message='INVALID_CONTACT_EMAIL'; end if;
  email_local:=split_part(contact_email,'@',1); email_domain:=split_part(contact_email,'@',2);
  if length(email_local) not between 1 and 64 or length(email_domain) not between 1 and 253 or email_local like '.%' or email_local like '%.' or email_local like '%..%' or position('.' in email_domain)=0 or exists(select 1 from unnest(string_to_array(email_domain,'.')) label where length(label) not between 1 and 63 or label !~ '^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$') then raise exception using errcode='22023',message='INVALID_CONTACT_EMAIL'; end if;
 end if;
 if address1 is null or address1='' or length(address1)>200 or coalesce(length(trim(payload->>'city')) between 1 and 100,false)=false or coalesce(length(trim(payload->>'state')) between 1 and 100,false)=false or coalesce(length(trim(payload->>'postal_code')) between 1 and 20,false)=false then raise exception using errcode='22023',message='INVALID_LOCATION'; end if;
 insert into public.advertisers(organization_id,name,normalized_name,category) values(org_id,clean_name,normalized,trim(payload->>'category')) returning id into aid;
 insert into public.advertiser_contacts(organization_id,advertiser_id,name,email,phone,is_primary) values(org_id,aid,contact_name,nullif(trim(payload->>'email'),''),nullif(trim(payload->>'phone'),''),true);
 insert into public.advertiser_locations(organization_id,advertiser_id,address_line_1,address_line_2,city,state,postal_code,is_primary) values(org_id,aid,address1,nullif(trim(payload->>'address_line_2'),''),trim(payload->>'city'),trim(payload->>'state'),trim(payload->>'postal_code'),true);
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'advertiser.created','advertiser',aid,jsonb_build_object('primary_contact_created',true,'primary_location_created',true)); return aid;
end $$;
create function public.create_campaign_with_slots(org_id uuid,payload json) returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); cid uuid; n int; price bigint; currency text; org_currency text; publication date; sales date; artwork date; proof date; printing date; qty int; print_cost bigint; postage_cost bigint; exclusivity boolean; integer_keys text[]:=array['mailing_quantity','estimated_printing_cost_cents','estimated_postage_cost_cents','slot_count','standard_slot_price_cents']; date_keys text[]:=array['publication_date','sales_deadline','artwork_deadline','proof_deadline','print_deadline']; required_keys text[]:=array['name','territory','product_type','publication_date','sales_deadline','artwork_deadline','proof_deadline','print_deadline','mailing_quantity','estimated_printing_cost_cents','estimated_postage_cost_cents','slot_count','standard_slot_price_cents','category_exclusivity_enabled']; key text; begin
 if uid is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 if not public.has_org_role(org_id,array['owner','administrator','sales_manager']::public.organization_role[]) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if payload is null or json_typeof(payload)<>'object' or not (payload::jsonb ?& required_keys) then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 if json_typeof(payload->'name')<>'string' or json_typeof(payload->'territory')<>'string' or json_typeof(payload->'product_type')<>'string' or json_typeof(payload->'publication_date')<>'string' or json_typeof(payload->'sales_deadline')<>'string' or json_typeof(payload->'artwork_deadline')<>'string' or json_typeof(payload->'proof_deadline')<>'string' or json_typeof(payload->'print_deadline')<>'string' then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 if json_typeof(payload->'category_exclusivity_enabled')<>'boolean' then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 foreach key in array integer_keys loop
  if json_typeof(payload->key)<>'number' or (payload->>key) !~ '^(0|[1-9][0-9]*)$' then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 end loop;
 if payload->>'slot_count'='0' or length(payload->>'slot_count')>3 or (length(payload->>'slot_count')=3 and payload->>'slot_count'>'500') or length(payload->>'mailing_quantity')>8 or (length(payload->>'mailing_quantity')=8 and payload->>'mailing_quantity'>'10000000') then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 foreach key in array array['estimated_printing_cost_cents','estimated_postage_cost_cents','standard_slot_price_cents'] loop
  if length(payload->>key)>12 or (length(payload->>key)=12 and payload->>key>'100000000000') then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 end loop;
 foreach key in array date_keys loop
  if json_typeof(payload->key)<>'string' or (payload->>key) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 end loop;
 begin
  n=(payload->>'slot_count')::int; price=(payload->>'standard_slot_price_cents')::bigint; qty=(payload->>'mailing_quantity')::int; print_cost=(payload->>'estimated_printing_cost_cents')::bigint; postage_cost=(payload->>'estimated_postage_cost_cents')::bigint;
  publication=(payload->>'publication_date')::date; sales=(payload->>'sales_deadline')::date; artwork=(payload->>'artwork_deadline')::date; proof=(payload->>'proof_deadline')::date; printing=(payload->>'print_deadline')::date; exclusivity=(payload->>'category_exclusivity_enabled')::boolean;
 exception when others then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end;
 if not isfinite(publication) or not isfinite(sales) or not isfinite(artwork) or not isfinite(proof) or not isfinite(printing) or to_char(publication,'YYYY-MM-DD')<>payload->>'publication_date' or to_char(sales,'YYYY-MM-DD')<>payload->>'sales_deadline' or to_char(artwork,'YYYY-MM-DD')<>payload->>'artwork_deadline' or to_char(proof,'YYYY-MM-DD')<>payload->>'proof_deadline' or to_char(printing,'YYYY-MM-DD')<>payload->>'print_deadline' then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 select default_currency into org_currency from public.organizations where id=org_id and status='active'; currency:=coalesce(nullif(payload->>'currency',''),org_currency);
 if org_currency is null or currency<>org_currency or length(trim(payload->>'name')) not between 1 and 160 or length(trim(payload->>'territory')) not between 1 and 160 or length(trim(payload->>'product_type')) not between 1 and 100 or n not between 1 and 500 or qty not between 0 and 10000000 or price not between 0 and 100000000000 or print_cost not between 0 and 100000000000 or postage_cost not between 0 and 100000000000 or not(sales<=artwork and artwork<=proof and proof<=printing and printing<=publication) then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 insert into public.campaigns(organization_id,name,territory,product_type,currency,publication_date,sales_deadline,artwork_deadline,proof_deadline,print_deadline,mailing_quantity,estimated_printing_cost_cents,estimated_postage_cost_cents,configured_slot_count,standard_slot_price_cents,category_exclusivity_enabled,status)
 values(org_id,trim(payload->>'name'),trim(payload->>'territory'),trim(payload->>'product_type'),currency,publication,sales,artwork,proof,printing,qty,print_cost,postage_cost,n,price,exclusivity,'selling') returning id into cid;
 insert into public.campaign_slots(organization_id,campaign_id,identifier,side_or_section,standard_price_cents,currency) select org_id,cid,'Slot '||g,case when g%2=1 then 'Front' else 'Back' end,price,currency from generate_series(1,n) g;
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'campaign.created','campaign',cid,jsonb_build_object('slot_count',n,'status','selling')); return cid;
end $$;
create function public.reserve_campaign_slot(org_id uuid,slot_id uuid,advertiser_id uuid,sale_price_cents bigint) returns table(placement_id uuid,campaign_id uuid) language plpgsql security definer set search_path='' as $$
declare
 p_organization_id constant uuid:=reserve_campaign_slot.org_id;
 p_campaign_slot_id constant uuid:=reserve_campaign_slot.slot_id;
 p_advertiser_id constant uuid:=reserve_campaign_slot.advertiser_id;
 p_sale_price_cents constant bigint:=reserve_campaign_slot.sale_price_cents;
 v_user_id uuid:=auth.uid();
 v_membership_id uuid;
 v_campaign_slot public.campaign_slots;
 v_campaign public.campaigns;
 v_advertiser public.advertisers;
 v_opportunity_id uuid;
 v_placement_id uuid;
begin
 if v_user_id is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 if not public.has_org_role(p_organization_id,array['owner','administrator','sales_manager']::public.organization_role[]) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if p_campaign_slot_id is null or p_advertiser_id is null or p_sale_price_cents not between 0 and 100000000000 then raise exception using errcode='22023',message='INVALID_RESERVATION'; end if;
 select cs.* into v_campaign_slot from public.campaign_slots as cs where cs.id=p_campaign_slot_id and cs.organization_id=p_organization_id;
 if not found then raise exception using errcode='22023',message='INVALID_RESERVATION'; end if;
 select c.* into v_campaign from public.campaigns as c where c.id=v_campaign_slot.campaign_id and c.organization_id=p_organization_id and exists(select 1 from public.organizations as o where o.id=p_organization_id and o.status='active') for update;
 select cs.* into v_campaign_slot from public.campaign_slots as cs where cs.id=p_campaign_slot_id and cs.organization_id=p_organization_id and cs.campaign_id=v_campaign.id for update;
 select a.* into v_advertiser from public.advertisers as a where a.id=p_advertiser_id and a.organization_id=p_organization_id and a.status='active';
 if not found then raise exception using errcode='22023',message='INVALID_RESERVATION'; end if;
 if v_campaign.status<>'selling' or v_campaign_slot.status<>'available' or v_campaign_slot.standard_price_cents<0 or exists(select 1 from public.placements as p where p.organization_id=p_organization_id and p.campaign_slot_id=v_campaign_slot.id and p.status in ('held','reserved','confirmed')) then raise exception using errcode='55000',message='RESERVATION_UNAVAILABLE'; end if;
 if v_campaign.category_exclusivity_enabled and v_advertiser.category is not null and exists(select 1 from public.placements as p where p.organization_id=p_organization_id and p.campaign_id=v_campaign.id and p.status in ('held','reserved','confirmed') and lower(trim(p.category))=lower(trim(v_advertiser.category)) and p.advertiser_id<>v_advertiser.id) then raise exception using errcode='55000',message='CATEGORY_CONFLICT'; end if;
 select om.id into v_membership_id from public.organization_memberships as om where om.organization_id=p_organization_id and om.user_id=v_user_id and om.status='active' and om.role in ('owner','administrator','sales_manager');
 if v_membership_id is null then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 insert into public.opportunities as o(organization_id,advertiser_id,campaign_id,assigned_membership_id,stage,estimated_value_cents) values(p_organization_id,v_advertiser.id,v_campaign.id,v_membership_id,'reserved',p_sale_price_cents) returning o.id into v_opportunity_id;
 insert into public.audit_events as ae(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(p_organization_id,v_user_id,'opportunity.created','opportunity',v_opportunity_id,jsonb_build_object('stage','reserved','campaign_id',v_campaign.id));
 insert into public.placements as p(organization_id,campaign_id,campaign_slot_id,advertiser_id,opportunity_id,assigned_membership_id,status,sale_price_cents,currency,category) values(p_organization_id,v_campaign.id,v_campaign_slot.id,v_advertiser.id,v_opportunity_id,v_membership_id,'reserved',p_sale_price_cents,v_campaign.currency,v_advertiser.category) returning p.id into v_placement_id;
 update public.campaign_slots as cs set status='reserved',updated_at=now() where cs.id=v_campaign_slot.id and cs.organization_id=p_organization_id;
 insert into public.audit_events as ae(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(p_organization_id,v_user_id,'placement.created','placement',v_placement_id,jsonb_build_object('status','reserved','slot_id',v_campaign_slot.id));
 insert into public.audit_events as ae(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(p_organization_id,v_user_id,'slot.reserved','campaign_slot',v_campaign_slot.id,jsonb_build_object('placement_id',v_placement_id,'advertiser_id',v_advertiser.id,'sale_price_cents',p_sale_price_cents));
 return query select v_placement_id as placement_id,v_campaign.id as campaign_id;
end $$;

revoke all on schema public from public,anon; grant usage on schema public to authenticated;
revoke all on all tables in schema public from public,anon,authenticated;
grant select on public.profiles,public.organizations,public.organization_memberships,public.advertisers,public.advertiser_contacts,public.advertiser_locations,public.campaigns,public.campaign_slots,public.opportunities,public.placements,public.audit_events to authenticated;
grant update(display_name) on public.profiles to authenticated;
revoke execute on function public.is_active_org_member(uuid),public.is_internal_org_member(uuid),public.has_org_role(uuid,public.organization_role[]),public.set_active_organization(uuid),public.create_organization_with_owner(text),public.create_advertiser_with_details(uuid,jsonb),public.create_campaign_with_slots(uuid,json),public.reserve_campaign_slot(uuid,uuid,uuid,bigint) from public,anon;
grant execute on function public.is_active_org_member(uuid),public.is_internal_org_member(uuid),public.has_org_role(uuid,public.organization_role[]),public.set_active_organization(uuid),public.create_organization_with_owner(text),public.create_advertiser_with_details(uuid,jsonb),public.create_campaign_with_slots(uuid,json),public.reserve_campaign_slot(uuid,uuid,uuid,bigint) to authenticated;

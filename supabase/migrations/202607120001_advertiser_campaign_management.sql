-- Advertiser and campaign management commands. All mutations remain RPC-only.

create function public.update_advertiser_with_details(org_id uuid, advertiser_id uuid, payload jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); a public.advertisers; clean_name text; normalized text; contact_email text; local_part text; domain_part text;
begin
 if uid is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 if not public.has_org_role(org_id,array['owner','administrator','sales_manager']::public.organization_role[]) or not exists(select 1 from public.profiles p where p.id=uid and p.status='active' and p.active_organization_id=org_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select x.* into a from public.advertisers x where x.id=update_advertiser_with_details.advertiser_id and x.organization_id=update_advertiser_with_details.org_id for update;
 if not found then raise exception using errcode='22023',message='INVALID_ADVERTISER'; end if;
 if a.status<>'active' then raise exception using errcode='55000',message='ADVERTISER_NOT_EDITABLE'; end if;
 clean_name:=trim(payload->>'name'); normalized:=lower(clean_name); contact_email:=trim(payload->>'email');
 if payload is null or jsonb_typeof(payload)<>'object' or length(clean_name) not between 1 and 160 or length(trim(payload->>'category')) not between 1 and 80
   or length(trim(payload->>'contact_name')) not between 1 and 160 or length(coalesce(trim(payload->>'phone'),''))>40
   or length(trim(payload->>'address_line_1')) not between 1 and 200 or length(coalesce(trim(payload->>'address_line_2'),''))>200
   or length(trim(payload->>'city')) not between 1 and 100 or length(trim(payload->>'state')) not between 1 and 100 or length(trim(payload->>'postal_code')) not between 1 and 20
 then raise exception using errcode='22023',message='INVALID_ADVERTISER'; end if;
 if contact_email<>'' then
  if length(contact_email)>254 or contact_email ~ '[[:space:]]' or length(contact_email)-length(replace(contact_email,'@',''))<>1 then raise exception using errcode='22023',message='INVALID_CONTACT_EMAIL'; end if;
  local_part:=split_part(contact_email,'@',1); domain_part:=split_part(contact_email,'@',2);
  if length(local_part) not between 1 and 64 or length(domain_part) not between 1 and 253 or local_part like '.%' or local_part like '%.' or local_part like '%..%' or position('.' in domain_part)=0
    or exists(select 1 from unnest(string_to_array(domain_part,'.')) label where length(label) not between 1 and 63 or label !~ '^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$')
  then raise exception using errcode='22023',message='INVALID_CONTACT_EMAIL'; end if;
 end if;
 if exists(select 1 from public.advertisers x where x.organization_id=update_advertiser_with_details.org_id and x.normalized_name=normalized and x.id<>update_advertiser_with_details.advertiser_id) then raise exception using errcode='23505',message='DUPLICATE_ADVERTISER'; end if;
 update public.advertisers x set name=clean_name,normalized_name=normalized,category=trim(payload->>'category') where x.id=update_advertiser_with_details.advertiser_id;
 update public.advertiser_contacts x set name=trim(payload->>'contact_name'),email=nullif(contact_email,''),phone=nullif(trim(payload->>'phone'),'') where x.organization_id=update_advertiser_with_details.org_id and x.advertiser_id=update_advertiser_with_details.advertiser_id and x.is_primary and x.status='active';
 if not found then raise exception using errcode='55000',message='PRIMARY_CONTACT_REQUIRED'; end if;
 update public.advertiser_locations x set address_line_1=trim(payload->>'address_line_1'),address_line_2=nullif(trim(payload->>'address_line_2'),''),city=trim(payload->>'city'),state=trim(payload->>'state'),postal_code=trim(payload->>'postal_code') where x.organization_id=update_advertiser_with_details.org_id and x.advertiser_id=update_advertiser_with_details.advertiser_id and x.is_primary and x.status='active';
 if not found then raise exception using errcode='55000',message='PRIMARY_LOCATION_REQUIRED'; end if;
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'advertiser.updated','advertiser',advertiser_id,jsonb_build_object('name',clean_name));
 return advertiser_id;
end $$;

create function public.change_advertiser_status(org_id uuid, advertiser_id uuid, new_status public.record_status)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); old_status public.record_status;
begin
 if uid is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 if not public.has_org_role(org_id,array['owner','administrator','sales_manager']::public.organization_role[]) or not exists(select 1 from public.profiles p where p.id=uid and p.status='active' and p.active_organization_id=org_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select x.status into old_status from public.advertisers x where x.id=change_advertiser_status.advertiser_id and x.organization_id=change_advertiser_status.org_id for update;
 if not found then raise exception using errcode='22023',message='INVALID_ADVERTISER'; end if;
 if old_status=new_status then raise exception using errcode='55000',message='INVALID_ADVERTISER_TRANSITION'; end if;
 if new_status='archived' and exists(select 1 from public.placements p where p.organization_id=change_advertiser_status.org_id and p.advertiser_id=change_advertiser_status.advertiser_id and p.status in ('held','reserved','confirmed')) then raise exception using errcode='55000',message='ADVERTISER_HAS_ACTIVE_RESERVATIONS'; end if;
 update public.advertisers x set status=new_status where x.id=change_advertiser_status.advertiser_id;
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'advertiser.status_changed','advertiser',advertiser_id,jsonb_build_object('old_status',old_status,'new_status',new_status));
 return advertiser_id;
end $$;

create function public.update_campaign_with_slots(org_id uuid, campaign_id uuid, payload jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); c public.campaigns; n int; occupied int; org_currency text; publication date; sales date; artwork date; proof date; printing date; price bigint; print_cost bigint; postage_cost bigint; qty int; exclusivity boolean; key text; integer_keys text[]:=array['mailing_quantity','estimated_printing_cost_cents','estimated_postage_cost_cents','slot_count','standard_slot_price_cents']; date_keys text[]:=array['publication_date','sales_deadline','artwork_deadline','proof_deadline','print_deadline']; required_keys text[]:=array['name','territory','product_type','publication_date','sales_deadline','artwork_deadline','proof_deadline','print_deadline','mailing_quantity','estimated_printing_cost_cents','estimated_postage_cost_cents','slot_count','standard_slot_price_cents','category_exclusivity_enabled'];
begin
 if uid is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 if not public.has_org_role(org_id,array['owner','administrator','sales_manager']::public.organization_role[]) or not exists(select 1 from public.profiles p where p.id=uid and p.status='active' and p.active_organization_id=org_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select x.* into c from public.campaigns x where x.id=update_campaign_with_slots.campaign_id and x.organization_id=update_campaign_with_slots.org_id for update;
 if not found then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 if c.status not in ('draft','selling') then raise exception using errcode='55000',message='CAMPAIGN_NOT_EDITABLE'; end if;
 if payload is null or jsonb_typeof(payload)<>'object' or not (payload ?& required_keys)
   or jsonb_typeof(payload->'name')<>'string' or jsonb_typeof(payload->'territory')<>'string' or jsonb_typeof(payload->'product_type')<>'string'
   or jsonb_typeof(payload->'category_exclusivity_enabled')<>'boolean'
 then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 foreach key in array integer_keys loop
  if jsonb_typeof(payload->key)<>'number' or (payload->>key) !~ '^(0|[1-9][0-9]*)$' then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 end loop;
 if payload->>'slot_count'='0' or length(payload->>'slot_count')>3 or (length(payload->>'slot_count')=3 and payload->>'slot_count'>'500') or length(payload->>'mailing_quantity')>8 or (length(payload->>'mailing_quantity')=8 and payload->>'mailing_quantity'>'10000000') then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 foreach key in array array['estimated_printing_cost_cents','estimated_postage_cost_cents','standard_slot_price_cents'] loop
  if length(payload->>key)>12 or (length(payload->>key)=12 and payload->>key>'100000000000') then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 end loop;
 foreach key in array date_keys loop
  if jsonb_typeof(payload->key)<>'string' or (payload->>key) !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 end loop;
 begin n=(payload->>'slot_count')::int; qty=(payload->>'mailing_quantity')::int; price=(payload->>'standard_slot_price_cents')::bigint; print_cost=(payload->>'estimated_printing_cost_cents')::bigint; postage_cost=(payload->>'estimated_postage_cost_cents')::bigint; publication=(payload->>'publication_date')::date; sales=(payload->>'sales_deadline')::date; artwork=(payload->>'artwork_deadline')::date; proof=(payload->>'proof_deadline')::date; printing=(payload->>'print_deadline')::date; exclusivity=(payload->>'category_exclusivity_enabled')::boolean; exception when others then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end;
 if not isfinite(publication) or not isfinite(sales) or not isfinite(artwork) or not isfinite(proof) or not isfinite(printing) or to_char(publication,'YYYY-MM-DD')<>payload->>'publication_date' or to_char(sales,'YYYY-MM-DD')<>payload->>'sales_deadline' or to_char(artwork,'YYYY-MM-DD')<>payload->>'artwork_deadline' or to_char(proof,'YYYY-MM-DD')<>payload->>'proof_deadline' or to_char(printing,'YYYY-MM-DD')<>payload->>'print_deadline' then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 select o.default_currency into org_currency from public.organizations o where o.id=update_campaign_with_slots.org_id and o.status='active';
 if org_currency is null or coalesce(payload->>'currency',c.currency)<>org_currency or length(trim(payload->>'name')) not between 1 and 160 or length(trim(payload->>'territory')) not between 1 and 160 or length(trim(payload->>'product_type')) not between 1 and 100 or n not between 1 and 500 or qty not between 0 and 10000000 or price not between 0 and 100000000000 or print_cost not between 0 and 100000000000 or postage_cost not between 0 and 100000000000 or not(sales<=artwork and artwork<=proof and proof<=printing and printing<=publication) then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 select count(*) into occupied from public.campaign_slots s where s.organization_id=update_campaign_with_slots.org_id and s.campaign_id=update_campaign_with_slots.campaign_id and s.status<>'available';
 if n<occupied then raise exception using errcode='55000',message='SLOT_COUNT_BELOW_OCCUPIED'; end if;
 if n<c.configured_slot_count then
  if (select count(*) from public.campaign_slots s where s.organization_id=update_campaign_with_slots.org_id and s.campaign_id=update_campaign_with_slots.campaign_id and s.status='available') < c.configured_slot_count-n then raise exception using errcode='55000',message='SLOT_COUNT_BELOW_OCCUPIED'; end if;
  delete from public.campaign_slots target where target.id in (select s.id from public.campaign_slots s where s.organization_id=update_campaign_with_slots.org_id and s.campaign_id=update_campaign_with_slots.campaign_id and s.status='available' order by (substring(s.identifier from '[0-9]+$'))::int desc limit c.configured_slot_count-n);
 elsif n>c.configured_slot_count then
  insert into public.campaign_slots(organization_id,campaign_id,identifier,side_or_section,standard_price_cents,currency) select org_id,update_campaign_with_slots.campaign_id,'Slot '||g,case when g%2=1 then 'Front' else 'Back' end,price,org_currency from generate_series(c.configured_slot_count+1,n) g;
 end if;
 update public.campaigns x set name=trim(payload->>'name'),territory=trim(payload->>'territory'),product_type=trim(payload->>'product_type'),publication_date=publication,sales_deadline=sales,artwork_deadline=artwork,proof_deadline=proof,print_deadline=printing,mailing_quantity=qty,estimated_printing_cost_cents=print_cost,estimated_postage_cost_cents=postage_cost,configured_slot_count=n,standard_slot_price_cents=price,category_exclusivity_enabled=exclusivity where x.id=update_campaign_with_slots.campaign_id;
 update public.campaign_slots s set standard_price_cents=price where s.organization_id=update_campaign_with_slots.org_id and s.campaign_id=update_campaign_with_slots.campaign_id and s.status='available';
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'campaign.updated','campaign',campaign_id,jsonb_build_object('old_slot_count',c.configured_slot_count,'new_slot_count',n)); return campaign_id;
end $$;

create function public.transition_campaign_status(org_id uuid, campaign_id uuid, new_status public.campaign_status)
returns table(authoritative_campaign_id uuid,status public.campaign_status) language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); old_status public.campaign_status; actor_role public.organization_role;
begin
 if uid is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 select m.role into actor_role from public.organization_memberships m join public.organizations o on o.id=m.organization_id and o.status='active' join public.profiles pr on pr.id=m.user_id and pr.status='active' and pr.active_organization_id=m.organization_id where m.organization_id=org_id and m.user_id=uid and m.status='active';
 if actor_role is null then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select c.status into old_status from public.campaigns c where c.id=transition_campaign_status.campaign_id and c.organization_id=transition_campaign_status.org_id for update;
 if not found then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 if old_status in ('completed','canceled') then raise exception using errcode='55000',message='CAMPAIGN_ALREADY_TERMINAL'; end if;
 if new_status='canceled' then raise exception using errcode='22023',message='INVALID_CAMPAIGN_TRANSITION'; end if;
 if not ((old_status='draft' and new_status='selling') or (old_status='selling' and new_status='artwork_collection') or (old_status='artwork_collection' and new_status='proofing') or (old_status='proofing' and new_status='ready_for_print') or (old_status='ready_for_print' and new_status='sent_to_printer') or (old_status='sent_to_printer' and new_status='mailed_or_published') or (old_status='mailed_or_published' and new_status='completed')) then raise exception using errcode='55000',message='INVALID_CAMPAIGN_TRANSITION'; end if;
 if not (actor_role in ('owner','administrator') or actor_role='sales_manager' and old_status in ('draft','selling','artwork_collection') or actor_role='designer' and old_status in ('proofing','ready_for_print')) then raise exception using errcode='42501',message='CAMPAIGN_TRANSITION_NOT_AUTHORIZED'; end if;
 update public.campaigns c set status=new_status where c.id=transition_campaign_status.campaign_id;
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'campaign.status_changed','campaign',campaign_id,jsonb_build_object('old_status',old_status,'new_status',new_status));
 return query select transition_campaign_status.campaign_id,new_status;
end $$;

create function public.cancel_campaign(org_id uuid,campaign_id uuid,reason text)
returns table(authoritative_campaign_id uuid,status public.campaign_status) language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); old_status public.campaign_status; actor_role public.organization_role; p record; released int; occurred_at timestamptz:=now(); clean_reason text:=trim(reason);
begin
 if uid is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 if clean_reason is null or length(clean_reason) not between 1 and 500 then raise exception using errcode='22023',message='INVALID_CANCELLATION'; end if;
 select m.role into actor_role from public.organization_memberships m join public.organizations o on o.id=m.organization_id and o.status='active' join public.profiles pr on pr.id=m.user_id and pr.status='active' and pr.active_organization_id=m.organization_id where m.organization_id=org_id and m.user_id=uid and m.status='active';
 if actor_role is null then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 select c.status into old_status from public.campaigns c where c.id=cancel_campaign.campaign_id and c.organization_id=cancel_campaign.org_id for update;
 if not found then raise exception using errcode='22023',message='INVALID_CAMPAIGN'; end if;
 if old_status in ('completed','canceled') then raise exception using errcode='55000',message='CAMPAIGN_ALREADY_TERMINAL'; end if;
 if not (actor_role in ('owner','administrator') or actor_role='sales_manager' and old_status in ('draft','selling','artwork_collection')) then raise exception using errcode='42501',message='CAMPAIGN_TRANSITION_NOT_AUTHORIZED'; end if;
 perform 1 from public.placements x where x.organization_id=org_id and x.campaign_id=cancel_campaign.campaign_id and x.status in ('held','reserved','confirmed') order by x.id for update;
 perform 1 from public.campaign_slots x where x.organization_id=org_id and x.campaign_id=cancel_campaign.campaign_id order by x.id for update;
 perform 1 from public.opportunities x where x.organization_id=org_id and x.id in(select y.opportunity_id from public.placements y where y.organization_id=org_id and y.campaign_id=cancel_campaign.campaign_id and y.status in ('held','reserved','confirmed')) order by x.id for update;
 for p in select x.id,x.opportunity_id,x.campaign_slot_id from public.placements x where x.organization_id=org_id and x.campaign_id=cancel_campaign.campaign_id and x.status in ('held','reserved','confirmed') order by x.id loop
  update public.placements target set status='canceled',canceled_at=occurred_at,cancellation_reason=clean_reason where target.id=p.id;
  update public.opportunities target set stage='lost' where target.id=p.opportunity_id and target.stage<>'lost';
  if found then insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'opportunity.status_changed','opportunity',p.opportunity_id,jsonb_build_object('campaign_id',campaign_id,'placement_id',p.id,'old_status','reserved','new_status','lost','reason',clean_reason,'occurred_at',occurred_at)); end if;
  update public.campaign_slots target set status='available' where target.id=p.campaign_slot_id and target.status in ('held','reserved','sold') and not exists(select 1 from public.placements other where other.campaign_slot_id=p.campaign_slot_id and other.id<>p.id and other.status in ('held','reserved','confirmed'));
  get diagnostics released=row_count;
  insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'placement.canceled','placement',p.id,jsonb_build_object('campaign_id',campaign_id,'opportunity_id',p.opportunity_id,'slot_id',p.campaign_slot_id,'reason',clean_reason,'occurred_at',occurred_at));
  if released=1 then insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'slot.released','campaign_slot',p.campaign_slot_id,jsonb_build_object('campaign_id',campaign_id,'placement_id',p.id,'opportunity_id',p.opportunity_id,'reason',clean_reason,'occurred_at',occurred_at)); end if;
 end loop;
 update public.campaigns target set status='canceled' where target.id=cancel_campaign.campaign_id;
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'campaign.status_changed','campaign',campaign_id,jsonb_build_object('old_status',old_status,'new_status','canceled','reason',clean_reason,'occurred_at',occurred_at));
 return query select cancel_campaign.campaign_id,'canceled'::public.campaign_status;
end $$;

create function public.cancel_reservation(org_id uuid, placement_id uuid, reason text)
returns table(campaign_id uuid,slot_id uuid) language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); placement_row public.placements; c public.campaigns; s public.campaign_slots; released int; occurred_at timestamptz:=now();
begin
 if uid is null then raise exception using errcode='28000',message='AUTH_REQUIRED'; end if;
 if not public.has_org_role(org_id,array['owner','administrator','sales_manager']::public.organization_role[]) or not exists(select 1 from public.profiles p where p.id=uid and p.status='active' and p.active_organization_id=org_id) then raise exception using errcode='42501',message='NOT_AUTHORIZED'; end if;
 if reason is null or length(trim(reason)) not between 1 and 500 then raise exception using errcode='22023',message='INVALID_CANCELLATION'; end if;
 select x.* into placement_row from public.placements x where x.id=cancel_reservation.placement_id and x.organization_id=cancel_reservation.org_id;
 if not found then raise exception using errcode='22023',message='INVALID_RESERVATION'; end if;
 select x.* into c from public.campaigns x where x.id=placement_row.campaign_id and x.organization_id=cancel_reservation.org_id for update;
 select x.* into placement_row from public.placements x where x.id=cancel_reservation.placement_id and x.organization_id=cancel_reservation.org_id for update;
 select x.* into s from public.campaign_slots x where x.id=placement_row.campaign_slot_id and x.organization_id=cancel_reservation.org_id for update;
 perform 1 from public.opportunities x where x.id=placement_row.opportunity_id and x.organization_id=cancel_reservation.org_id for update;
 if placement_row.status='canceled' then raise exception using errcode='55000',message='RESERVATION_ALREADY_CANCELED'; end if;
 if placement_row.status not in ('held','reserved','confirmed') or c.status in ('mailed_or_published','completed') then raise exception using errcode='55000',message='CANCELLATION_NOT_ALLOWED'; end if;
 update public.placements target set status='canceled',canceled_at=now(),cancellation_reason=trim(reason) where target.id=placement_row.id;
 update public.opportunities target set stage='lost' where target.id=placement_row.opportunity_id and target.stage<>'lost';
 if found then insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'opportunity.status_changed','opportunity',placement_row.opportunity_id,jsonb_build_object('campaign_id',placement_row.campaign_id,'placement_id',placement_row.id,'new_status','lost','reason',trim(reason),'occurred_at',occurred_at)); end if;
 update public.campaign_slots target set status='available' where target.id=placement_row.campaign_slot_id and target.status in ('held','reserved','sold') and not exists(select 1 from public.placements x where x.campaign_slot_id=placement_row.campaign_slot_id and x.id<>placement_row.id and x.status in ('held','reserved','confirmed'));
 get diagnostics released=row_count;
 insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'placement.canceled','placement',placement_row.id,jsonb_build_object('campaign_id',placement_row.campaign_id,'slot_id',placement_row.campaign_slot_id,'reason',trim(reason),'opportunity_id',placement_row.opportunity_id,'occurred_at',occurred_at));
 if released=1 then insert into public.audit_events(organization_id,actor_user_id,event_type,entity_type,entity_id,details) values(org_id,uid,'slot.released','campaign_slot',placement_row.campaign_slot_id,jsonb_build_object('campaign_id',placement_row.campaign_id,'placement_id',placement_row.id,'opportunity_id',placement_row.opportunity_id,'reason',trim(reason),'occurred_at',occurred_at)); end if;
 return query select placement_row.campaign_id,placement_row.campaign_slot_id;
end $$;

revoke execute on function public.update_advertiser_with_details(uuid,uuid,jsonb),public.change_advertiser_status(uuid,uuid,public.record_status),public.update_campaign_with_slots(uuid,uuid,jsonb),public.transition_campaign_status(uuid,uuid,public.campaign_status),public.cancel_campaign(uuid,uuid,text),public.cancel_reservation(uuid,uuid,text) from public,anon;
grant execute on function public.update_advertiser_with_details(uuid,uuid,jsonb),public.change_advertiser_status(uuid,uuid,public.record_status),public.update_campaign_with_slots(uuid,uuid,jsonb),public.transition_campaign_status(uuid,uuid,public.campaign_status),public.cancel_campaign(uuid,uuid,text),public.cancel_reservation(uuid,uuid,text) to authenticated;

-- A slot can disappear while a reservation waits for the campaign lock during
-- concurrent inventory reduction. Revalidate the locked slot before inserting
-- any reservation aggregate rows.

create or replace function public.reserve_campaign_slot(org_id uuid,slot_id uuid,advertiser_id uuid,sale_price_cents bigint)
returns table(placement_id uuid,campaign_id uuid) language plpgsql security definer set search_path='' as $$
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
 if not found then raise exception using errcode='22023',message='INVALID_RESERVATION'; end if;
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

revoke execute on function public.reserve_campaign_slot(uuid,uuid,uuid,bigint) from public,anon;
grant execute on function public.reserve_campaign_slot(uuid,uuid,uuid,bigint) to authenticated;

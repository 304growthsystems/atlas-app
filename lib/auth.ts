import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isInternalRole } from "@/lib/security";
import { requireQueryData } from "@/lib/query";
export const getCurrentContext = cache(async () => {
  const supabase = await createClient(); const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError) { console.error("Current user lookup failed", { code: authError.code }); throw new Error("AUTH_CONTEXT_FAILED"); }
  if (!user) redirect("/login");
  const profile=requireQueryData("current profile",await supabase.from("profiles").select("active_organization_id").eq("id",user.id).maybeSingle()) as {active_organization_id:string|null}|null;
  const memberships=requireQueryData("current memberships",await supabase.from("organization_memberships").select("id, organization_id, role, organizations!inner(id, name, status)").eq("user_id",user.id).eq("status","active").eq("organizations.status","active"));
  const internal=memberships.filter(m=>isInternalRole(m.role));
  if (!internal.length) redirect(memberships.length>0?"/login?error=workspace_access":"/onboarding");
  const membership=internal.find(m=>m.organization_id===profile?.active_organization_id);
  if (!membership) redirect("/organizations/select");
  return { supabase, user, membership, organizationId: membership.organization_id };
});

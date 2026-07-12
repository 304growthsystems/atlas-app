import { createOrganization } from "@/app/actions";
import { ActionForm, Field } from "@/components/forms/action-form";
import { requireQueryData } from "@/lib/query";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
export default async function Onboarding(){const s=await createClient();const{data:{user}}=await s.auth.getUser();if(!user)redirect("/login");const data=requireQueryData("onboarding memberships",await s.from("organization_memberships").select("id,organizations!inner(status)").eq("user_id",user.id).eq("status","active").eq("organizations.status","active").limit(1));if(data.length)redirect("/organizations/select");return <main className="grid min-h-screen place-items-center bg-slate-100 p-6"><section className="w-full max-w-lg rounded-2xl bg-white p-7 shadow"><h1 className="text-2xl font-black">Create your organization</h1><p className="mt-2 text-slate-600">This becomes your explicit Atlas workspace and you become its Owner.</p><ActionForm action={createOrganization} submitLabel="Create organization" className="mt-6 space-y-4"><Field label="Organization name" name="name" required/></ActionForm></section></main>}

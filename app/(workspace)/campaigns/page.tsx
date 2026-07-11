import Link from "next/link";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { getCurrentContext } from "@/lib/auth";
import { requireQueryData } from "@/lib/query";
import { canManageFirstSlice } from "@/lib/security";
export default async function Campaigns(){const{supabase,organizationId,membership}=await getCurrentContext();const rows=requireQueryData("campaign list",await supabase.from("campaigns").select("id,name,territory,status,publication_date").eq("organization_id",organizationId).order("publication_date"));return <><ApplicationHeader title="Campaigns" actions={canManageFirstSlice(membership.role)?[{label:"New campaign",variant:"primary",href:"/campaigns/new"}]:[]}/><PageContainer>{rows.length?<div className="grid gap-3">{rows.map(c=><Link key={c.id} href={`/campaigns/${c.id}`} className="rounded-xl border bg-white p-5 hover:border-red-400"><h2 className="font-bold">{c.name}</h2><p className="text-sm text-slate-500">{c.territory} · {c.status.replaceAll("_"," ")} · {c.publication_date}</p></Link>)}</div>:<div className="rounded-xl border bg-white p-8 text-center">No campaigns yet.</div>}</PageContainer></>}

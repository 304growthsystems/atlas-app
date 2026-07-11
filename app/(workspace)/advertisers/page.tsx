import Link from "next/link";
import { ApplicationHeader } from "@/components/application-shell/application-header";
import { PageContainer } from "@/components/application-shell/page-container";
import { getCurrentContext } from "@/lib/auth";
import { requireQueryData } from "@/lib/query";
import { canManageFirstSlice } from "@/lib/security";
export default async function AdvertisersPage(){const{supabase,organizationId,membership}=await getCurrentContext();const canManage=canManageFirstSlice(membership.role);const rows=requireQueryData("advertiser list",await supabase.from("advertisers").select("id,name,category,status").eq("organization_id",organizationId).order("name"));return <><ApplicationHeader title="Advertisers" actions={canManage?[{label:"Add advertiser",variant:"primary",href:"/advertisers/new"}]:[]}/><PageContainer>{rows.length?<div className="grid gap-3">{rows.map(a=><article key={a.id} className="rounded-xl border bg-white p-5"><h2 className="font-bold">{a.name}</h2><p className="text-sm text-slate-500">{a.category}</p></article>)}</div>:<div className="rounded-xl border bg-white p-8 text-center"><p>No advertisers yet.</p>{canManage&&<Link className="mt-3 inline-block text-red-700 underline" href="/advertisers/new">Create the first advertiser</Link>}</div>}</PageContainer></>}

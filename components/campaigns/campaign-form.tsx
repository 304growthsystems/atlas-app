"use client";

import { useActionState, useEffect, useRef } from "react";
import { createCampaign } from "@/app/actions";

const fields = [
  ["name", "Campaign name", "text", undefined], ["territory", "Territory", "text", undefined],
  ["productType", "Product type", "text", undefined], ["publicationDate", "Mail or publication date", "date", undefined],
  ["salesDeadline", "Sales deadline", "date", undefined], ["artworkDeadline", "Artwork deadline", "date", undefined],
  ["proofDeadline", "Proof deadline", "date", undefined], ["printDeadline", "Print deadline", "date", undefined],
  ["mailingQuantity", "Mailing quantity", "number", undefined], ["estimatedPrintingCost", "Estimated printing cost ($)", "text", "0.00"],
  ["estimatedPostageCost", "Estimated postage cost ($)", "text", "0.00"], ["slotCount", "Number of campaign slots", "number", undefined],
  ["standardSlotPrice", "Standard slot price ($)", "text", "0.00"],
] as const;

export function CampaignForm() {
  const [state, formAction, pending] = useActionState(createCampaign, {});
  const formRef = useRef<HTMLFormElement>(null);
  useEffect(() => { formRef.current?.querySelector<HTMLElement>("[aria-invalid='true']")?.focus(); }, [state]);
  return <form ref={formRef} action={formAction} className="space-y-5" noValidate>
    <div className="grid gap-4 sm:grid-cols-2">{fields.map(([name,label,type,fallback])=>{const error=state.errors?.[name]?.[0];const errorId=`${name}-error`;return <label key={name} className="grid gap-1.5 text-sm font-semibold">{label}<input name={name} type={type} required defaultValue={String(state.values?.[name]??fallback??"")} min={name==="slotCount"?1:name==="mailingQuantity"?0:undefined} step={type==="number"?1:undefined} aria-invalid={Boolean(error)} aria-describedby={error?errorId:undefined} className={`rounded-lg border bg-white px-3 py-2.5 font-normal ${error?"border-red-600 ring-1 ring-red-600":"border-slate-300"}`}/>{error&&<span id={errorId} className="text-xs font-medium text-red-700">{error}</span>}</label>})}
      <label className="flex items-center gap-2 text-sm font-semibold"><input type="checkbox" name="categoryExclusivity" defaultChecked={state.values?.categoryExclusivity===true}/> Enable category exclusivity</label>
    </div>
    {state.message&&<p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-800">{state.message}</p>}
    <button disabled={pending} className="rounded-lg bg-red-700 px-4 py-2.5 font-bold text-white disabled:opacity-60">{pending?"Saving…":"Create campaign and slots"}</button>
  </form>;
}

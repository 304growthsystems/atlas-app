import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL;
const anon = process.env.SUPABASE_ANON_KEY;
const email = process.env.ATLAS_CONCURRENCY_EMAIL;
const password = process.env.ATLAS_CONCURRENCY_PASSWORD;
const onboardingEmail = process.env.ATLAS_ONBOARDING_EMAIL;
const onboardingPassword = process.env.ATLAS_ONBOARDING_PASSWORD;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !anon || !email || !password || !onboardingEmail || !onboardingPassword) {
  console.error("FAIL: set Supabase URL/key plus reservation and fresh onboarding test-user credentials.");
  process.exit(1);
}
const clients = Array.from({ length: 3 }, () => createClient(url, anon, { auth: { persistSession: false } }));
await Promise.all(clients.map(async client => { const { error } = await client.auth.signInWithPassword({ email, password }); if (error) throw new Error("Harness login failed"); }));
const onboardingClients = Array.from({ length: 3 }, () => createClient(url, anon, { auth: { persistSession: false } }));
await Promise.all(onboardingClients.map(async client => { const { error } = await client.auth.signInWithPassword({ email: onboardingEmail, password: onboardingPassword }); if (error) throw new Error("Onboarding harness login failed"); }));
const expectExactlyOne = async (name, calls) => {
  const results = await Promise.all(calls.map(call => call()));
  const successes = results.filter(result => !result.error);
  if (successes.length !== 1) throw new Error(`${name}: expected exactly one success, received ${successes.length}`);
  console.log(`PASS: ${name}`);
};
const expectAll = async (name, calls) => { const results=await Promise.all(calls.map(call=>call()));if(results.some(result=>result.error))throw new Error(`${name}: expected all calls to succeed`);console.log(`PASS: ${name}`); };
const reserve = (client, fixture, advertiserId, slotId) => client.rpc("reserve_campaign_slot", { org_id: fixture.orgId, slot_id: slotId, advertiser_id: advertiserId, sale_price_cents: fixture.salePriceCents ?? 10000 });

const orgName = `Concurrency ${Date.now()}`;
await expectExactlyOne("concurrent repeated onboarding", onboardingClients.map(client => () => client.rpc("create_organization_with_owner", { org_name: orgName })));

const fixtures = process.env.ATLAS_CONCURRENCY_FIXTURES ? JSON.parse(process.env.ATLAS_CONCURRENCY_FIXTURES) : null;
if (!fixtures) console.log("SKIP: reservation races require ATLAS_CONCURRENCY_FIXTURES JSON with fresh sameSlot, competingCategory, sameAdvertiser, and statusTransition fixtures.");
else {
  const same=fixtures.sameSlot;await expectExactlyOne("concurrent same-slot reservations",clients.map(client=>()=>reserve(client,same,same.advertiserA,same.slotA)));
  const competing=fixtures.competingCategory;await expectExactlyOne("concurrent competing-category reservations on different slots",[()=>reserve(clients[0],competing,competing.advertiserA,competing.slotA),()=>reserve(clients[1],competing,competing.advertiserB,competing.slotB)]);
  const repeat=fixtures.sameAdvertiser;await expectAll("concurrent same-advertiser reservations on different slots",[()=>reserve(clients[0],repeat,repeat.advertiserA,repeat.slotA),()=>reserve(clients[1],repeat,repeat.advertiserA,repeat.slotB)]);
  if(!serviceKey)throw new Error("status transition race requires SUPABASE_SERVICE_ROLE_KEY for the local test instance");
  const admin=createClient(url,serviceKey,{auth:{persistSession:false}});const transition=fixtures.statusTransition;
  const results=await Promise.all([reserve(clients[0],transition,transition.advertiserA,transition.slotA),admin.from("campaigns").update({status:"artwork_collection"}).eq("id",transition.campaignId).eq("status","selling").select("id")]);
  const reservationSucceeded=!results[0].error;const transitioned=!results[1].error&&results[1].data.length===1;if(!transitioned)throw new Error("reservation/status transition race: transition did not complete");if(!reservationSucceeded&&results[0].error?.message?.includes("RESERVATION_UNAVAILABLE")!==true)throw new Error("reservation/status transition race returned an unsafe failure");console.log(`PASS: reservation racing campaign-status transition (${reservationSucceeded?"reservation serialized first":"transition serialized first"})`);
}
console.log("PASS: concurrency harness completed");

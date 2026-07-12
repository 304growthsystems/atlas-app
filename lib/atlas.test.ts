import { describe, expect, it } from "vitest";
import { dollarsToCents, formatCurrency } from "./money";
import { advertiserSchema, campaignSchema, cancellationSchema, codePointLength, isValidAdvertiserEmail, loginSchema, reservationSchema, statusSchema, signupSchema } from "./validation";
import { assertOrganizationScoped, calculateCampaignMetrics, categoryConflicts, isSlotAvailable } from "./domain/rules";
import { canCancelCampaign, canManageFirstSlice, canViewCampaignFinancials, getAuthCallbackUrl, getTrustedAppUrl, isInternalRole, permittedCampaignTransitions, safeErrorMessage } from "./security";

describe("money",()=>{it("converts exactly",()=>expect(dollarsToCents("1,234.56")).toBe(123456));it("formats",()=>expect(formatCurrency(49500)).toBe("$495.00"));it("rejects fractional cents",()=>expect(()=>dollarsToCents("1.009")).toThrow())});
describe("metrics",()=>it("derives inventory and revenue",()=>expect(calculateCampaignMetrics([{status:"selling",slots:[{status:"available"},{status:"reserved"}],placements:[{status:"held",salePriceCents:10},{status:"reserved",salePriceCents:500}]}])).toEqual({activeCampaigns:1,availableSlots:1,reservedSlots:1,projectedRevenueCents:500})));
describe("inventory",()=>{it("requires no occupancy",()=>{expect(isSlotAvailable("available",0)).toBe(true);expect(isSlotAvailable("available",1)).toBe(false)});it("permits same advertiser",()=>{const active=[{advertiserId:"a",category:"Dental",status:"reserved" as const}];expect(categoryConflicts(true,"b","dental",active)).toBe(true);expect(categoryConflicts(true,"a","Dental",active)).toBe(false)})});
describe("scope",()=>it("rejects another organization",()=>expect(()=>assertOrganizationScoped({organization_id:"a"},"b")).toThrow()));
describe("validation",()=>{
  const campaign={name:"A",territory:"T",productType:"Mail",publicationDate:"2028-03-05",salesDeadline:"2028-03-01",artworkDeadline:"2028-03-02",proofDeadline:"2028-03-03",printDeadline:"2028-03-04",mailingQuantity:"100",slotCount:"1",estimatedPrintingCost:"0",estimatedPostageCost:"0",standardSlotPrice:"1",categoryExclusivity:false};
  it("requires advertiser details",()=>expect(advertiserSchema.safeParse({businessName:"A",category:"C",contactName:"",email:"",phone:"",addressLine1:"",addressLine2:"",city:"",state:"",postalCode:""}).success).toBe(false));
  it("bounds local auth input",()=>{expect(loginSchema.safeParse({email:"not-email",password:"short"}).success).toBe(false);expect(signupSchema.safeParse({email:`a@${"x".repeat(320)}.com`,password:"valid-password"}).success).toBe(false)});

  const integerCases: Array<[string, Record<string, unknown>, boolean]> = [
    ["valid baseline",{},true],["mailing zero",{mailingQuantity:"0"},true],["mailing maximum",{mailingQuantity:"10000000"},true],
    ["mailing above maximum",{mailingQuantity:"10000001"},false],["mailing negative",{mailingQuantity:"-1"},false],
    ["slot minimum",{slotCount:"1"},true],["slot maximum",{slotCount:"500"},true],["slot zero",{slotCount:"0"},false],["slot above maximum",{slotCount:"501"},false],
    ["missing integer",{mailingQuantity:undefined},false],["null integer",{mailingQuantity:null},false],["numeric value",{mailingQuantity:2},false],
    ["fractional",{mailingQuantity:"1.5"},false],["decimal notation",{mailingQuantity:"2.0"},false],["exponent notation",{mailingQuantity:"1e3"},false],
    ["unsafe integer",{mailingQuantity:"9007199254740992"},false],
    ["printing max",{estimatedPrintingCost:"1000000000"},true],["printing over",{estimatedPrintingCost:"1000000000.01"},false],
    ["postage max",{estimatedPostageCost:"1000000000"},true],["postage over",{estimatedPostageCost:"1000000000.01"},false],
    ["slot price max",{standardSlotPrice:"1000000000"},true],["slot price over",{standardSlotPrice:"1000000000.01"},false],
    ["money negative",{standardSlotPrice:"-1"},false],["money unsafe",{standardSlotPrice:"90071992547409.92"},false],
  ];
  it.each(integerCases)("campaign integer: %s",(_name,override,valid)=>expect(campaignSchema.safeParse({...campaign,...override}).success).toBe(valid));

  const dateFields = ["publicationDate","salesDeadline","artworkDeadline","proofDeadline","printDeadline"] as const;
  const invalidDates: Array<[string, unknown]> = [["missing",undefined],["null",null],["non-string",20280305],["empty",""],["infinity","infinity"],["negative infinity","-infinity"],["epoch","epoch"],["timestamp","2028-03-05T00:00:00Z"],["slash format","2028/03/05"],["non-padded","2028-3-05"],["impossible","2028-02-30"],["invalid non-leap day","2027-02-29"]];
  it.each(dateFields.flatMap((field)=>invalidDates.map(([label,value])=>[field,label,value] as const)))("campaign date: %s rejects %s",(field,_label,value)=>expect(campaignSchema.safeParse({...campaign,[field]:value}).success).toBe(false));
  it("accepts canonical and leap-year dates",()=>expect(campaignSchema.safeParse({...campaign,publicationDate:"2028-02-29",printDeadline:"2028-02-29",proofDeadline:"2028-02-28",artworkDeadline:"2028-02-27",salesDeadline:"2028-02-26"}).success).toBe(true));
  it.each([
    {salesDeadline:"2028-03-03",artworkDeadline:"2028-03-02"},
    {artworkDeadline:"2028-03-04",proofDeadline:"2028-03-03"},
    {proofDeadline:"2028-03-05",printDeadline:"2028-03-04"},
    {printDeadline:"2028-03-06",publicationDate:"2028-03-05"},
  ])("rejects a deadline-order violation",(override)=>expect(campaignSchema.safeParse({...campaign,...override}).success).toBe(false));
  it("does not accept invalid reservation ids",()=>expect(reservationSchema.safeParse({slotId:"bad",advertiserId:"bad",salePrice:"x"}).success).toBe(false));
  it("requires a bounded cancellation reason",()=>{expect(cancellationSchema.safeParse({placementId:"00000000-0000-4000-8000-000000000001",reason:"Customer request"}).success).toBe(true);expect(cancellationSchema.safeParse({placementId:"bad",reason:""}).success).toBe(false)});
  it("validates explicit campaign statuses",()=>{expect(statusSchema.safeParse({id:"00000000-0000-4000-8000-000000000001",status:"selling"}).success).toBe(true);expect(statusSchema.safeParse({id:"00000000-0000-4000-8000-000000000001",status:"invented"}).success).toBe(false)});
});
describe("advertiser email policy",()=>{
  it.each(["person@example.com","first.last@example.co.uk","user+tag@example.com"])("accepts %s",(email)=>expect(isValidAdvertiserEmail(email)).toBe(true));
  it.each(["a..b@example.com",".abc@example.com","abc.@example.com","abc@-example.com","abc@example-.com","abc@example","abc@@example.com","abc @example.com",`${"a".repeat(65)}@example.com`,`${"a".repeat(64)}@${"b".repeat(63)}.${"c".repeat(63)}.${"d".repeat(63)}.com`])("rejects %s",(email)=>expect(isValidAdvertiserEmail(email)).toBe(false));
  it("trims without changing case",()=>expect(advertiserSchema.parse({businessName:"A",category:"C",contactName:"P",email:" Person@Example.COM ",phone:"",addressLine1:"1 Main",addressLine2:"",city:"Town",state:"WV",postalCode:"26000"}).email).toBe("Person@Example.COM"));
  it.each([[63,true],[64,true],[65,false]])("counts %i non-BMP local characters as Unicode code points",(count,valid)=>{
    const local="𐐀".repeat(count);
    expect(codePointLength(local)).toBe(count);
    expect(isValidAdvertiserEmail(`${local}@example.com`)).toBe(valid);
  });
});
describe("security",()=>{it("authorizes implemented roles",()=>{expect(canManageFirstSlice("owner")).toBe(true);expect(canManageFirstSlice("salesperson")).toBe(false)});it("excludes advertiser",()=>expect(isInternalRole("advertiser")).toBe(false));it("builds trusted callback",()=>expect(getAuthCallbackUrl("https://atlas.example/")).toBe("https://atlas.example/auth/callback"));it("keeps request origins out of redirects",()=>{expect(getTrustedAppUrl("/dashboard","https://atlas.example/")).toBe("https://atlas.example/dashboard");expect(getTrustedAppUrl("/login?error=auth_callback","https://atlas.example/")).not.toContain("attacker.example")});it("rejects unsafe callback origins",()=>{expect(()=>getAuthCallbackUrl("javascript:alert(1)")).toThrow();expect(()=>getAuthCallbackUrl("https://atlas.example/path")).toThrow();expect(()=>getAuthCallbackUrl("https://user:pass@atlas.example/")).toThrow()});it("maps errors safely",()=>expect(safeErrorMessage({message:"constraint secret",code:"23505"})).not.toContain("constraint"))});
describe("management error mapping",()=>{it.each([["ADVERTISER_HAS_ACTIVE_RESERVATIONS","Cancel active reservations"],["SLOT_COUNT_BELOW_OCCUPIED","occupied inventory"],["INVALID_CAMPAIGN_TRANSITION","not permitted"],["RESERVATION_ALREADY_CANCELED","already been canceled"]])("maps %s safely",(code,text)=>expect(safeErrorMessage({message:code})).toContain(text))});
describe("campaign role matrix",()=>{it("limits sales management to pre-production",()=>{expect(permittedCampaignTransitions("sales_manager","artwork_collection")).toEqual(["proofing"]);expect(permittedCampaignTransitions("sales_manager","proofing")).toEqual([])});it("grants designers only production handoff steps",()=>{expect(permittedCampaignTransitions("designer","proofing")).toEqual(["ready_for_print"]);expect(permittedCampaignTransitions("designer","ready_for_print")).toEqual(["sent_to_printer"]);expect(permittedCampaignTransitions("designer","sent_to_printer")).toEqual([])});it("limits cancellation by role and phase",()=>{expect(canCancelCampaign("sales_manager","selling")).toBe(true);expect(canCancelCampaign("sales_manager","proofing")).toBe(false);expect(canCancelCampaign("administrator","sent_to_printer")).toBe(true)});it("limits sensitive financials",()=>{expect(canViewCampaignFinancials("owner")).toBe(true);expect(canViewCampaignFinancials("finance")).toBe(true);expect(canViewCampaignFinancials("sales_manager")).toBe(false);expect(canViewCampaignFinancials("designer")).toBe(false)})});

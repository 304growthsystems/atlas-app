# Atlas Business Workflows

## Shared workflow requirements

Every command below runs within one active Organization Membership. The system must verify tenant scope and permission, validate the current record version/status, perform coupled state changes atomically, append required Activity Events and Audit Events, and return a stable result safe against accidental retry. “Notify” means create an in-product notification/task once such infrastructure exists; notification delivery is not specified here.

Approved policy decisions are recorded in [FOUNDER_DECISIONS.md](./FOUNDER_DECISIONS.md).

## 1. Create advertiser

**Actors:** Owner, Administrator, Sales Manager, Salesperson.

**Preconditions:** Actor has organization access; business name is supplied.

**Steps:**

1. Enter company name and optional website, category, phone, contacts, and locations.
2. Normalize name/domain/phone/address and search the organization for duplicates.
3. If candidates exist, choose an existing Advertiser or explicitly confirm a distinct business with reason.
4. Create the Advertiser, then contacts and locations in the same organization.
5. Set primary contact/location only to newly created or existing active children.
6. Append creation and duplicate-override events as applicable.

**Outcome:** One reusable Advertiser exists; campaign participation is added later through Opportunity/Placement.

**Failure:** Missing name, cross-tenant references, invalid primary record, or unacknowledged likely duplicate prevents creation.

## 2. Create campaign

**Actors:** Owner, Administrator; Sales Manager may create Draft campaigns if permitted by organization policy.

**Steps:**

1. Create a Draft with name, territory, product type, currency, dates, mailing quantity, costs, exclusivity setting, and intended slot count.
2. Validate non-negative cents/quantity and deadline order.
3. Record placement-area vocabulary appropriate to the product (front/back, section/page, etc.).
4. Save the Draft and append audit/activity events.
5. Do not enter Selling until required fields and inventory slots are valid.

**Outcome:** A Draft campaign ready for slot setup.

## 3. Add campaign slots

**Actors:** Owner, Administrator, Sales Manager.

**Preconditions:** Campaign is Draft; configured slot count has capacity.

**Steps:**

1. Enter unique position identifier, side/section, size, standard price cents, and notes per slot.
2. Validate campaign currency, non-negative price, uniqueness, and supported placement area.
3. Create each slot as Available unless explicitly initialized as House Ad or Unavailable with reason.
4. Reconcile actual slots with configured slot count.
5. Audit bulk and individual state changes.

**Outcome:** Campaign inventory is addressable and ready for Selling.

**Failure:** Duplicate identifiers or exceeding configured capacity fails without partial creation unless an explicit validated bulk operation reports per-row results.

## 4. Create opportunity

**Actors:** Owner, Administrator, Sales Manager, Salesperson.

**Steps:**

1. Select an existing Advertiser; create one through Workflow 1 if needed.
2. Assign an active Salesperson membership (self by default for Salesperson actors).
3. Optionally select Campaign, estimated value, follow-up date, and notes.
4. Create at New Lead, or at another authorized stage when prior activity is recorded.
5. Append lead activity to the advertiser timeline.

**Outcome:** A trackable sales opportunity with ownership and history.

## 5. Hold a slot

**Actors:** Owner, Administrator, Sales Manager, assigned Salesperson.

**Preconditions:** Advertiser and Campaign are selected; campaign permits sales; slot is Available; actor may manage the Opportunity/Advertiser.

**Steps:**

1. Select slot, Opportunity, salesperson, sale price, placement category, and expiration; default expiration is 72 hours after creation.
2. Atomically recheck slot availability and category exclusivity.
3. Create Placement as Held and set slot to Held.
4. Move Opportunity to Reserved only if product policy equates a hold with that stage; otherwise retain its stage (open question).
5. Schedule expiration handling and append reservation/hold timeline plus audit events. Sales Manager or Administrator may extend with reason/audit, but never beyond seven total days from original creation.

**Outcome:** Temporarily exclusive inventory with a visible expiration.

**Failure:** Concurrent occupancy, category conflict, expired/invalid deadline, or tenant mismatch creates no Placement.

## 6. Reserve a slot

**Actors:** Owner, Administrator, Sales Manager, assigned Salesperson.

**Preconditions:** Placement is Held and unexpired (or direct reservation is later approved); slot remains Held by that Placement.

**Steps:**

1. Revalidate occupancy, exclusivity, campaign status, and sale price.
2. If conflict exists, stop or collect an authorized override reason and audit it.
3. Change Placement to Reserved and slot to Reserved atomically.
4. Set Opportunity stage to Reserved.
5. Cancel scheduled hold expiry and append activity/audit events.

**Outcome:** Inventory is reserved without implying payment or artwork completion.

## 7. Send invoice

**Actors:** Owner, Administrator, Finance; Sales roles may request but not send unless later approved.

**Preconditions:** Invoice lifecycle is Draft with at least one valid line item; each Placement is active and belongs to the Invoice Organization, Advertiser, and Campaign; totals balance.

**Steps:**

1. Select one or more Placements from the same Organization, Advertiser, Campaign, and currency.
2. Create line items with frozen descriptions and amounts; calculate total in cents.
3. Assign organization-unique invoice number, issue date, and due date.
4. Review recipient billing contact and delivery destination.
5. Change lifecycle from Draft to Sent, retain independent Payment state and Aging state, and record sent timestamp/delivery details.
6. Append invoice timeline and audit events.

**Outcome:** Durable Sent Invoice with balance equal to total less successful net payments.

**Failure:** Empty invoice, mismatched advertiser/currency/tenant, invalid totals, or already-sent mutation fails. Corrections require approved adjustment/void policy.

## 8. Record partial payment

**Actors:** Owner, Administrator, Finance; automated payment integration in the future acts as System.

**Preconditions:** Invoice lifecycle is Sent; amount is positive and currency matches. Payment and Aging states do not prevent a valid additional payment unless balance/credit rules do.

**Steps:**

1. Enter amount, method, received time, and unique external/reference value when available.
2. Check for a prior payment with the same idempotency/reference key.
3. Create separate Payment; mark Succeeded only when receipt is confirmed.
4. Allocate successful value proportionally across unpaid Invoice Lines by default; Finance may manually change allocations with reason and audit history.
5. Recalculate balance, independent Payment state, and independent Aging state. If successful value exceeds balance, fully pay the Invoice and create exact excess as unapplied Advertiser Credit.
6. Re-evaluate each Placement required deposit from its net Payment Allocations. Confirm qualifying Reserved Placements and mark their Slots Sold atomically.
7. Append payment, allocation, credit, confirmation, timeline, and audit events as applicable.

**Outcome:** Original Invoice remains intact, partial collection is visible, and balance is accurate.

**Failure:** Allocation or tenant/campaign mismatch fails atomically. Excess is never silently discarded or automatically refunded.

## 9. Confirm placement

**Actors:** System when allocations satisfy the deposit; Owner or Administrator for a reasoned deposit override.

**Preconditions:** Placement is Reserved, slot is Reserved by it, category rules remain satisfied, and net allocated payments meet the required deposit (default 100% of sale price or the Organization's configured smaller deposit), unless Owner/Administrator uses an override.

**Steps:**

1. Review advertiser, campaign, slot, sale price, salesperson, category, and linked Opportunity.
2. Validate Payment Allocations against required deposit. For an override, require Owner/Administrator, written reason, and audit event.
3. Atomically change Placement to Confirmed and slot to Sold.
4. Set Opportunity to Won when all intended sale items are confirmed.
5. Ensure an Artwork Package exists at Not Requested.
6. Append confirmation timeline and audit events.

**Outcome:** Sold inventory, independent of payment and artwork status.

## 10. Request artwork

**Actors:** Owner, Administrator, Designer; Sales roles may initiate for their assigned placements if policy permits.

**Preconditions:** Placement is Reserved or Confirmed; Artwork Package exists and is Not Requested or Revision Requested as appropriate.

**Steps:**

1. Choose recipient contact, required assets, instructions, and due date.
2. Record request and delivery attempt.
3. Set package to Requested.
4. Create follow-up Task and timeline/audit events.

**Outcome:** A placement-specific, deadline-tracked artwork request.

## 11. Submit artwork

**Actors:** Advertiser for its own placement; Designer, Administrator, or authorized Sales role on advertiser's behalf.

**Steps:**

1. Upload/reference allowed files and add submission notes.
2. Virus/type/size validation is required by future file-storage design.
3. Create an immutable next Artwork Version with submitter and source metadata.
4. Set status to Submitted; complete/update related collection Task.
5. Append submission timeline and audit events.

**Outcome:** Versioned source material is available for design/proofing.

## 12. Send proof

**Actors:** Designer, Administrator, Owner.

**Preconditions:** Package is Submitted, In Design, or Revision Requested; a new immutable proof version exists.

**Steps:**

1. Select the exact version, recipient contact, and message.
2. Record delivery attempt and sent timestamp against that version.
3. Set active proof version and package status to Proof Sent.
4. Create approval follow-up Task due by proof deadline.
5. Append proof timeline and audit events.

**Outcome:** The recipient can approve or request revision of a named version.

## 13. Request revision

**Actors:** Advertiser for its own proof; Designer, Administrator, Owner; authorized Sales role on behalf of advertiser with attribution.

**Preconditions:** Exact proof is Proof Sent or currently Approved.

**Steps:**

1. Record requested changes, requester identity, and timestamp against the version.
2. If previously approved/print-ready, retain approval history but invalidate it for future production.
3. Set package to Revision Requested and create/assign design Task.
4. Append timeline and audit events.

**Outcome:** Current proof is not production-ready; next proof must receive a new version number.

## 14. Approve proof

**Actors:** Authorized Advertiser contact for its own proof, Owner, or Administrator. Designer may not approve.

**Preconditions:** Package is Proof Sent; selected version is current and immutable.

**Steps:**

1. Display exact proof version and collect approval notes/affirmation.
2. Record approver identity, timestamp, notes, and approved version in an append-only Artwork Approval.
3. Set package to Approved.
4. Complete approval Task and append timeline/audit events.
5. A Designer later verifies production requirements and changes Approved to Print Ready.

**Outcome:** Verifiable approval exists for a specific version.

## 15. Mark campaign ready for print

**Actors:** Owner, Administrator, Designer.

**Preconditions:** Campaign is Proofing; every active Confirmed placement has current Print Ready artwork approved for its current version; no blocking conflicts/tasks; campaign production data is complete.

**Steps:**

1. Run and display a readiness checklist by slot/placement.
2. Block transition and identify every failed gate.
3. On success, change Campaign to Ready for Print.
4. Snapshot/readily identify included slots and artwork versions.
5. Append audit/activity events.

**Outcome:** A reproducible production set is ready for printer submission.

## 16. Send campaign to printer

**Actors:** Owner, Administrator, Designer.

**Preconditions:** Campaign is Ready for Print.

**Steps:**

1. Confirm printer, production package/version manifest, quantity, send timestamp, and expected completion.
2. Record printer confirmation/reference or mark confirmation pending.
3. Change status to Sent to Printer.
4. Create follow-up Task if confirmation is missing.
5. Append audit/activity events.

**Outcome:** Production handoff and exact submitted artwork are traceable.

## 17. Mark mailed or published

**Actors:** Owner, Administrator; authorized production staff.

**Preconditions:** Campaign is Sent to Printer; mailing/publication occurred.

**Steps:**

1. Record actual date/time, quantity if known, confirmation source, and evidence/reference.
2. Resolve or annotate differences from scheduled date/quantity.
3. Change status to Mailed or Published.
4. Append campaign and advertiser timeline events plus audit event.

**Outcome:** Delivery/publication is evidenced, not inferred from scheduled date.

## 18. Complete campaign

**Actors:** Owner, Administrator.

**Preconditions:** Campaign is Mailed or Published; closeout checklist is complete. Open invoices may remain, but must be surfaced.

**Steps:**

1. Review delivery evidence, active placement statuses, financial balances, and unresolved Tasks.
2. Change Confirmed placements to Completed where fulfillment occurred.
3. Change Campaign to Completed.
4. Preserve outstanding collections as finance work; do not mark invoices paid.
5. Append completion activity/audit events and identify renewal candidates.

**Outcome:** Operations are closed while finance history and balances remain active.

## 19. Create renewal opportunity

**Actors:** Owner, Administrator, Sales Manager, assigned Salesperson; System may suggest.

**Preconditions:** Advertiser has a prior Placement or Opportunity and remains active.

**Steps:**

1. Select source Placement/Opportunity and target campaign if known.
2. Copy only appropriate sales context; do not copy status, payment, or approval.
3. Assign salesperson using current assignment policy.
4. Create a new Opportunity at Renewal Due with follow-up date.
5. Link source record and append renewal activity/audit events.

**Outcome:** Renewal is a new trackable sale without rewriting the original history.

## 20. Cancel reservation and release inventory

**Actors:** Owner, Administrator, Sales Manager; assigned Salesperson for Held/Reserved if policy permits.

**Preconditions:** Placement is Held or Reserved and owns the corresponding Held/Reserved slot.

**Steps:**

1. Collect cancellation reason and effective timestamp.
2. Review related Invoice, Payment, Artwork Package, Tasks, and exclusivity override.
3. Atomically set Placement to Canceled and slot to Available, unless an authorized user selects House Ad or Unavailable with a separate reason.
4. Cancel related open operational Tasks; do not delete them.
5. Do not automatically delete/void invoices or refund payments; start the applicable finance workflow.
6. Update Opportunity to Follow-Up or Lost with reason, as selected.
7. Append cancellation/release timeline and audit events.

**Outcome:** Inventory is sellable again and the canceled reservation remains historical.

## Edge-case operating behavior

| Edge case | Required behavior |
|---|---|
| Hold expiration | Idempotently cancel only a still-Held placement; release its slot; retain history |
| Duplicate advertiser | Block silent duplicate; reuse existing or capture authorized distinct-business rationale |
| Partial payment | Separate Payment; recompute balance; set Payment state and Aging state independently |
| Overpayment | Fully pay Invoice and create exact excess as unapplied Advertiser Credit; Finance later applies or refunds it |
| Refund | Append Refund against original successful Payment; never rewrite/remove receipt |
| Canceled campaign | Preserve all history; release eligible inventory; separately resolve invoices/refunds |
| Canceled placement | Preserve record and related history; release slot when eligible |
| Reassigned salesperson | Change future responsibility; retain historical commission ownership unless Administrator approves an audited transfer |
| Reused artwork | Create new package/version source link; require placement-specific approval |
| Revised approved proof | New version; old approval remains historical but is not current; reapprove |
| Conflicting categories | Active Holds block competitors; same Advertiser may buy multiple slots; otherwise block or require authorized audited override |
| Missed deadlines | Derived health warning and urgent task/escalation; do not silently change campaign status |
| Slot made unavailable | Require no active placement, or move/cancel it first; record reason/audit |
| House ad | No advertiser placement/revenue; exclude or separately report in inventory metrics |
| Multiple locations | One Advertiser with many Locations; placement optionally chooses promoted location |
| Multiple slots | Separate Placement per slot; enforce exclusivity and price/artwork independently |
| One invoice, multiple placements | Separate line per placement; same advertiser/currency; preserve allocation traceability |

## Open questions requiring founder approval

1. Does a hold move an Opportunity to Reserved, or only a formal reservation?
2. Are invoice line amounts editable after Sent, or must correction use void/reissue or credit adjustments?
3. May campaigns complete with unresolved tasks or outstanding invoices, and which items are blockers versus warnings?
4. What is the precise closeout checklist and renewal timing?
5. How are proportional-allocation rounding remainders assigned?
6. What evidence is required when Owner/Administrator records proof approval received outside the portal?

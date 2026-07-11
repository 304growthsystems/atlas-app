# Atlas Business Rules

## Rule notation

`MUST` is an invariant that cannot be bypassed. `MAY WITH OVERRIDE` requires the named role, a reason, and an audit event. All writes are organization-scoped and must revalidate rules on the server at the time of change; interface checks alone are insufficient.

Approved policy decisions are recorded in [FOUNDER_DECISIONS.md](./FOUNDER_DECISIONS.md).

## Tenant and identity rules

1. Every business entity MUST belong to one Organization.
2. Every reference between tenant-owned entities MUST remain within the same Organization.
3. A user MUST have an active Organization Membership to access that organization's records.
4. An Advertiser-role membership MUST be restricted to explicitly linked advertiser records.
5. An Organization MUST always have at least one active Owner.
6. Role, membership, and advertiser-access changes MUST create audit events.
7. Tenant scope MUST apply to record reads, writes, search, exports, attachments, reports, unique constraints, and asynchronous work.

Example: a Campaign Slot from Organization A cannot be submitted in a Placement request for Organization B, even if its identifier is known.

## Advertiser rules

### Creation and duplicate review

- Advertiser represents a company, not a person.
- Name is required after trimming and normalization.
- Before creation, search the current organization for likely matches using normalized name plus available website domain, phone, and address.
- An exact or likely match MUST prompt selection of the existing advertiser or an explicit `not a duplicate` confirmation by an authorized staff role.
- A duplicate-review override MUST record candidate identifiers, actor, reason, and timestamp.
- An advertiser MUST NOT be copied merely to join a new campaign.

Example: “Smith Dental LLC” participating in three postcards remains one Advertiser with three Placements.

### Contacts and locations

- A primary contact/location, when set, MUST belong to the advertiser and be active.
- At most one contact and one location are primary at a time.
- Changing the primary record MUST atomically unset the previous primary.
- A placement MAY select one promoted advertiser location.
- Historical events retain references to inactive contacts/locations.

## Campaign rules

### Required validation

- Name, territory, product type, currency, product/publication date, and configured slot count are required before entering `Selling`.
- Slot count MUST be a positive integer.
- Mailing quantity MUST be a non-negative integer; whether zero is permitted outside Draft is an open question.
- Costs MUST be non-negative integer cents.
- Dates MUST obey the approved sequence when present: sales deadline no later than artwork deadline, artwork deadline no later than proof deadline, proof deadline no later than print deadline, and print deadline no later than mail/publication date. Exceptional sequencing requires Administrator override, reason, and audit.
- A campaign cannot enter a production status while required operational gates are unsatisfied.

### Status transitions

| Current | Allowed next statuses | Gate |
|---|---|---|
| Draft | Selling, Canceled | Selling requires required fields and inventory configuration |
| Selling | Artwork Collection, Canceled | Normal progression begins after sales work; unsold slots may remain |
| Artwork Collection | Proofing, Selling, Canceled | Proofing requires artwork submitted for every active confirmed placement |
| Proofing | Artwork Collection, Ready for Print, Canceled | Ready for Print gates are listed below |
| Ready for Print | Proofing, Sent to Printer, Canceled | Returning to Proofing requires reason and audit |
| Sent to Printer | Mailed or Published, Canceled | Printer submission must be recorded |
| Mailed or Published | Completed | Mailing/publication confirmation required |
| Completed | — | Terminal in normal operation |
| Canceled | — | Terminal; restoration requires a future explicit policy |

`Ready for Print` requires:

- Every active confirmed placement has `Print Ready` artwork and an approval for its current proof version.
- No unresolved artwork/proof blocking task exists.
- Slot/placement conflicts are absent.
- Required campaign dates and quantity are present.

`Sent to Printer` records printer, timestamp, submitting user, and confirmation/reference when available. `Mailed or Published` records confirmation timestamp and evidence/reference. `Completed` requires mailed/published status and completion of required closeout processing.

Owner, Administrator, or Designer may mark Ready for Print and Sent to Printer after all gates pass. Only Owner or Administrator may mark Mailed or Published and Completed.

Automated status advancement is not approved; the system enforces gates when an authorized user advances status.

### Cancellation

- Canceling a Campaign MUST require reason, actor, and timestamp and create audit/activity events.
- All active holds and reservations MUST be canceled and their slots released unless financial/legal policy requires a temporary lock.
- Confirmed placements, sent invoices, successful payments, and approvals MUST remain in history.
- The cancellation workflow MUST surface outstanding/refundable financial obligations; campaign cancellation MUST NOT automatically erase, void, or refund them.
- A campaign at or beyond `Sent to Printer` requires Administrator or Owner authority to cancel.

## Slot and placement rules

### Slot state consistency

| Slot status | Valid occupancy |
|---|---|
| Available | No active placement |
| Held | Exactly one Held placement with unexpired hold |
| Reserved | Exactly one Reserved placement |
| Sold | Exactly one Confirmed placement |
| House Ad | No active advertiser placement |
| Unavailable | No active placement |

- Occupancy MUST be enforced atomically to prevent concurrent double-booking.
- A slot MUST NOT have more than one active placement.
- A slot with a historical canceled/completed placement may be reused only when no active placement remains and campaign stage permits it.
- `Unavailable` requires a reason. Making an occupied slot unavailable first requires canceling or moving the active placement.
- `House Ad` is excluded from projected revenue and advertiser placement counts. Converting it to sellable inventory requires an authorized change and audit event.

### Hold

- Creating a hold requires advertiser, campaign, slot, salesperson, sale price, and future expiration.
- Hold expiration defaults to 72 hours after creation.
- Sales Manager or Administrator may extend a hold, but total elapsed hold time from original creation may not exceed seven days. Every extension requires a written reason and audit event.
- On expiration, the Placement becomes Canceled with reason `Hold expired`, the slot becomes Available, and activity/audit events are appended.
- Expiration processing MUST be idempotent and MUST recheck the placement is still Held before release.
- Extending a hold requires authorization, new expiration, reason, and audit.

### Reservation and confirmation

- Only an active Held placement may normally become Reserved; direct reservation is allowed only if organization policy explicitly permits it.
- Reserved requires a nonexpired hold or an atomic direct-reservation operation, plus successful exclusivity validation.
- Required deposit defaults to 100% of Placement sale price; an Organization may configure a smaller percentage.
- A Placement becomes Confirmed only when net Payment Allocations to it satisfy its required deposit. Owner or Administrator MAY WITH OVERRIDE confirm below the deposit with a written reason and audit event.
- Canceling Held or Reserved placements releases the slot to Available unless the slot is independently marked Unavailable or House Ad.
- Canceling a Confirmed placement requires Sales Manager, Administrator, or Owner authority, a reason, and financial/artwork impact review.
- Canceled placements remain queryable and visible in history.

### Multiple slots

An advertiser MAY buy multiple slots in one campaign. Each slot requires a separate Placement because occupancy, price, artwork approval, salesperson attribution, and cancellation are placement-specific. Category exclusivity still applies across those placements.

### Salesperson reassignment

- Reassignment changes future responsibility without rewriting the original activity/audit actor.
- Reassignment requires the new salesperson to be an active membership in the same organization.
- The previous and new salesperson, reason, actor, and timestamp are audited.
- Historical commission ownership remains unchanged on reassignment. A commission transfer requires Administrator approval, reason, and audit event.

## Opportunity rules

### Stage transitions

| Stage | Normal next stages |
|---|---|
| New Lead | Contacted, Lost |
| Contacted | Follow-Up, Interested, Lost |
| Follow-Up | Contacted, Interested, Lost |
| Interested | Proposal Sent, Follow-Up, Lost |
| Proposal Sent | Reserved, Follow-Up, Won, Lost |
| Reserved | Won, Follow-Up, Lost |
| Won | Renewal Due |
| Lost | Follow-Up, Renewal Due |
| Renewal Due | Contacted, Interested, Lost |

- Advertiser and assigned salesperson are required at creation.
- Campaign is required before stage `Reserved` and before Placement creation.
- `Lost` requires a loss reason.
- `Won` requires at least one noncanceled Placement.
- Stage changes append activity and audit events.
- Renewal creates a new Opportunity linked to the source relationship; it does not reopen or overwrite the original sale.

## Category exclusivity rules

- Exclusivity is evaluated only when enabled for the Campaign.
- Before a Placement becomes Held, Reserved, or Confirmed, the system checks other active (`Held`, `Reserved`, or `Confirmed`) placements in that Campaign using the restricted category.
- Active, unexpired Holds participate in exclusivity until expiration or cancellation.
- Exclusivity prevents competing Advertisers in a restricted category; the same Advertiser may purchase additional allowed slots.
- Sales Manager, Administrator, or Owner MAY WITH OVERRIDE allow a conflict. The override requires the conflicting placements, category, reason, actor, timestamp, and an audit event.
- Canceling or expiring the conflicting placement removes the active restriction but preserves override history.

## Artwork rules

### Status transitions

| Current | Allowed next statuses | Required data |
|---|---|---|
| Not Requested | Requested | Request recipient and timestamp |
| Requested | Submitted | Submitted assets/version |
| Submitted | In Design, Proof Sent | Version/source assets |
| In Design | Proof Sent | New proof version |
| Proof Sent | Revision Requested, Approved | Sent version and recipient |
| Revision Requested | In Design, Proof Sent | Revision notes |
| Approved | In Design, Print Ready | Rework creates new version; Print Ready validates approved current version |
| Print Ready | In Design | Reopening requires reason and audit |

- Artwork Package belongs to one Placement.
- Each proof has a monotonically increasing positive version number.
- Proof content/version is immutable after creation.
- Approval records exact proof version, approver identity, timestamp, and notes.
- Proof approval authority is limited to an authorized Advertiser contact, Owner, or Administrator. A Designer may create and send proofs but MUST NOT approve on behalf of an Advertiser.
- An approved version MUST NOT be overwritten or silently replaced.
- Any revision after approval creates a new version, clears the package's effective approved/current match, changes status out of Approved/Print Ready, and requires new approval.
- Reused artwork is copied or referenced as source material into a new package version; prior approval does not approve the new placement.

## Task and timeline rules

- A Task must have at least one supported related entity and an active organization member as assignee when assigned.
- Completed requires completion timestamp and actor. Reopening retains prior completion history through activity/audit events.
- Canceled requires a reason.
- Urgent and overdue tasks are display/notification concerns; they do not override permissions.
- Advertiser timeline events are append-only and ordered by occurred timestamp, then stable identifier for ties.
- Calls, emails, and notes may be manually logged. Reservations, invoices, payments, artwork/proof events, approvals, campaign completion, and renewals generate system timeline events.

## Campaign health rules

Health is derived at read/report time and is never a manually entered percentage.

Inputs:

- Inventory readiness (30%): filled inventory divided by total slots excluding Unavailable slots. Confirmed advertiser placements and House Ads are filled; House Ads are not sold and generate no revenue.
- Outstanding balances from invoice balances.
- Active placements missing required artwork.
- Proofs sent but awaiting approval or with requested revisions.
- Proximity to sales, artwork, proof, print, and mail/publication deadlines.
- Printer submission confirmation.
- Mailing/publication confirmation.

The initial score is the weighted sum of Inventory readiness (30%), Payment readiness (25%), Artwork and proof readiness (25%), Deadline risk (10%), and Printer/mailing confirmation (10%). Component scores range from 0 through 100. Overall labels are `Healthy` for 80 through 100, `Needs Attention` for 60 through 79, and `At Risk` below 60. The calculation must expose both filled inventory and advertiser-sold inventory. A manual annotation MUST NOT replace derived facts.

## Validation and concurrency rules

- All status transitions validate current status, target status, permissions, tenant scope, and required fields atomically.
- Invoice lifecycle, Payment state, and Aging state are independent dimensions; no single Invoice status may combine them. Payment and Aging states are recalculated from financial facts under [FINANCIAL_RULES.md](./FINANCIAL_RULES.md).
- Successful Payment value allocates proportionally across unpaid same-campaign Invoice Lines by default. Finance may manually reallocate with reason and audit history. Unapplied excess creates Advertiser Credit.
- Slot occupancy, exclusivity, invoice balance application, and refund totals require transactional/concurrency protection.
- Commands must be idempotent where retries are possible, particularly hold expiration, payment recording, refunds, and generated activity events.
- User-facing validation errors identify the violated rule without exposing another tenant's data.

## Open questions requiring founder approval

1. Is direct `Available → Reserved` permitted, or is a Hold mandatory?
2. Can a campaign leave Selling with unsold slots, and how should those slots be finalized?
3. Can Completed or Canceled campaigns ever be reopened?
4. What deadline windows and rules produce each Deadline Risk component score?
5. What exact formulas produce Payment, Artwork/proof, and Printer/mailing component scores?
6. Category override roles: should Sales Manager be permitted, or only Administrator/Owner?
7. How should required-deposit percentage calculations round fractional cents?

# Atlas Business Domain Model

## Purpose and conventions

This document defines the business entities and relationships for Atlas. It is persistence-technology neutral. Unless explicitly described as global reference data, every business record is scoped to exactly one `Organization`.

Approved policy decisions are recorded in [FOUNDER_DECISIONS.md](./FOUNDER_DECISIONS.md).

Identifiers are immutable opaque values. Timestamps include a timezone and are stored in UTC. Currency amounts are integer cents paired with a currency code. Records that must remain in history are archived, voided, canceled, or otherwise status-transitioned rather than hard-deleted.

## Tenant boundary and identity

### Organization

The top-level account and data-isolation boundary. `304 Biz Connect` is the initial organization.

Required attributes: identifier, legal/display name, default currency, timezone, default placement deposit percentage (initially 100%), refund approval threshold cents (initially 50,000 cents), status, created timestamp, and updated timestamp.

Invariants:

- Every tenant-owned record carries an organization identifier.
- References between tenant-owned records must have the same organization identifier.
- Queries, uniqueness constraints, authorization checks, audit events, background jobs, exports, and file access must all enforce organization scope.
- Organization identifiers must be resolved from trusted membership/session context, never accepted unchecked from browser input.

### User

A human identity that may participate in multiple organizations. A user is not itself tenant-owned.

Required attributes: identifier, display name, normalized email, identity status, created timestamp, and updated timestamp.

### Organization Membership

Joins a User to an Organization and assigns one role in that organization: `Owner`, `Administrator`, `Sales Manager`, `Salesperson`, `Designer`, `Finance`, or `Advertiser`.

Required attributes: identifier, organization, user, role, membership status, joined timestamp, and optional advertiser access assignment.

Relationships and rules:

- A user may have one membership per organization.
- An organization has one or more memberships and must retain at least one active Owner.
- An Advertiser-role membership receives portal access only through one or more Advertiser Portal Membership records. This does not convert the user into an Advertiser entity.
- Role changes are audited.

### Advertiser Portal Membership

Grants one Organization Membership with the `Advertiser` role access to exactly one Advertiser. Required attributes: identifier, organization, organization membership, advertiser, status, granted by, granted timestamp, and revoked timestamp when applicable.

A portal user may have multiple Advertiser Portal Memberships. Each grant is separate, same-organization, revocable, and audited. Every portal request operates in an explicit advertiser context selected from active grants; access to one advertiser never implies access to another.

## Advertiser aggregate

### Advertiser

A business or company that buys advertising. It is not an individual contact and is not recreated for each campaign.

Required attributes: identifier, organization, legal/display name, normalized name, status, optional category, primary contact reference, primary location reference, created timestamp, and updated timestamp.

Relationships:

- Has many Advertiser Contacts and Advertiser Locations.
- Has zero or one primary contact and zero or one primary location; each referenced primary must belong to that advertiser.
- Has many Opportunities, Placements, Artwork Packages, Invoices, Tasks, and Activity Events.
- May have more than one placement in a campaign when campaign rules allow it.

Duplicate prevention uses an organization-scoped review of normalized name, website/domain, phone number, and address. A suspected duplicate blocks silent creation but permits an authorized user to confirm that the businesses are distinct. Participation in another campaign is never a reason to duplicate an advertiser.

### Advertiser Contact

An individual associated with an Advertiser.

Attributes include name, title, email, phone, communication preferences, active flag, and timestamps. Contact information remains organization-scoped through its advertiser. Removing a contact from active use must not erase historical attribution.

### Advertiser Location

A physical or service location operated by an Advertiser.

Attributes include label, address fields, phone, website, service area, active flag, and timestamps. A placement may optionally identify the location it promotes. Multiple locations never require duplicate advertiser records.

### Advertiser Category

An organization-scoped classification used for reporting and campaign exclusivity. An advertiser may need more than one category; if supported, a Placement must identify the single category evaluated for that campaign. Category vocabulary and multi-category behavior are open questions.

## Sales and campaign aggregate

### Campaign

A shared advertising product owned by one Organization.

Product types include `Postcard`, `Community Magazine`, `Coupon Book`, `Chamber Guide`, `Sponsorship Package`, and future organization-configured formats.

Required attributes:

- Identifier, organization, name, territory, product type, status
- Mail/publication date, sales deadline, artwork deadline, proof deadline, print deadline
- Mailing quantity
- Estimated printing cost cents, estimated postage cost cents, currency
- Category-exclusivity enabled flag
- Configured slot count
- Created and updated timestamps

Campaign status is one of `Draft`, `Selling`, `Artwork Collection`, `Proofing`, `Ready for Print`, `Sent to Printer`, `Mailed or Published`, `Completed`, or `Canceled`.

A Campaign has many Campaign Slots, Placements, Opportunities, Invoices, Tasks, expenses, activity events, and audit events.

### Campaign Slot

A defined inventory position within one Campaign.

Required attributes: identifier, organization, campaign, position identifier, side/section/placement area, size, standard price cents, currency, status, notes, and timestamps.

Status is one of `Available`, `Held`, `Reserved`, `Sold`, `House Ad`, or `Unavailable`.

Invariants:

- Position identifier is unique within a campaign.
- Slot currency matches campaign currency.
- A slot has at most one active Placement (`Held`, `Reserved`, or `Confirmed`) at a time.
- `House Ad` and `Unavailable` slots have no active advertiser placement.
- Slot status is derived from or transactionally synchronized with its active placement; contradictory combinations are invalid.

### Opportunity

A possible advertising sale.

Required attributes: identifier, organization, advertiser, optional campaign, assigned salesperson membership, stage, estimated value cents/currency, next-follow-up date, outcome details, timestamps, and activity history.

Stages: `New Lead`, `Contacted`, `Follow-Up`, `Interested`, `Proposal Sent`, `Reserved`, `Won`, `Lost`, and `Renewal Due`.

An Opportunity may produce one or more Placements only after advertiser and campaign are selected. Whether the approved one-opportunity-to-many-placement relationship is intended is an open question; the model permits it to support package sales.

### Placement

The sale/reservation joining an Organization, Advertiser, Campaign, Campaign Slot, optional source Opportunity, and assigned Salesperson.

Required attributes: identifier, organization, advertiser, campaign, campaign slot, assigned salesperson membership, status, sale price cents, required deposit cents, currency, optional promoted location, campaign category, hold expiration when held, commission owner membership, timestamps, and cancellation metadata when canceled.

Statuses: `Held`, `Reserved`, `Confirmed`, `Completed`, and `Canceled`.

Invariants:

- All references share the same organization.
- The slot belongs to the selected campaign.
- A Placement cannot exist until advertiser, campaign, and slot are selected.
- `Held` requires a future expiration timestamp.
- Required deposit defaults to 100% of sale price but is calculated from the Organization's configured deposit percentage. It must be between zero and the sale price. An Owner or Administrator may override it with a written reason and audit event.
- `Confirmed` requires net Payment Allocations to the Placement to meet or exceed its required deposit, unless an Owner or Administrator records a reasoned deposit override.
- Only one active placement may occupy a slot.
- Canceled placements remain immutable history apart from append-only notes/audit events.
- Placement status, Invoice lifecycle/payment/aging states, Payment status, and Artwork status are separate dimensions.
- Sale price is copied onto the placement and does not change if the slot's standard price later changes.
- Reassigning the salesperson changes future responsibility, not historical commission ownership. Commission transfer is a separate Administrator-approved, reasoned, audited change.

## Artwork aggregate

### Artwork Package

The artwork workflow for exactly one Placement. It may reference assets or a prior package as its source, but approval is placement-specific.

Required attributes: identifier, organization, placement, advertiser, status, source package if reused, active proof version reference, approved proof version reference, timestamps.

Statuses: `Not Requested`, `Requested`, `Submitted`, `In Design`, `Proof Sent`, `Revision Requested`, `Approved`, and `Print Ready`.

### Artwork Version / Proof

An immutable versioned rendition in an Artwork Package.

Required attributes: identifier, organization, artwork package, positive sequential version number, file reference, submitted/created by, created timestamp, notes, and proof-sent timestamp when applicable.

Version number is unique within the package. Reusing artwork creates a version in the new placement's package that records its source; it does not reuse another placement's approval.

### Artwork Approval

An append-only approval of one proof version.

Required attributes: organization, artwork package, approved proof version, approver identity, approval timestamp, and approval notes. Replacing approved artwork requires a new version and a new approval; the former approval remains historical.

## Finance aggregate

### Invoice

A durable billing document belonging to an Organization, Advertiser, and Campaign. It is associated with one or more Placements through its line items. Version 1 invoices cannot span Campaigns.

Required attributes: identifier, organization, advertiser, campaign, invoice number, lifecycle, payment state, aging state, currency, issue date, due date, subtotal cents, adjustment/tax cents if applicable, total cents, allocated paid cents, balance cents, sent timestamp, and timestamps.

Invoice state has three independent dimensions:

- Lifecycle: `Draft`, `Sent`, `Void`.
- Payment state: `Unpaid`, `Partially Paid`, `Paid`, `Overpaid`, `Refunded`, `Partially Refunded`.
- Aging state: `Current`, `Overdue`.

Invoices are never hard-deleted.

### Invoice Line Item

An immutable-after-send charge description tied to one Campaign and one Placement.

Required attributes: identifier, invoice, organization, campaign, placement, description, quantity, unit amount cents, line total cents, and unpaid amount cents when cached. Every line's advertiser, campaign, and currency must match the invoice.

### Payment

A separate record of money received or attempted against an Invoice.

Required attributes: identifier, organization, advertiser, invoice, amount cents, currency, status, method, received/processed timestamp, external reference if any, and timestamps.

Statuses: `Pending`, `Succeeded`, `Failed`, `Refunded`, and `Partially Refunded`.

Payments are never hard-deleted. A successful payment may have many Refund records. Payment status summarizes its refund state without erasing the original success.

### Payment Allocation

An assignment of Payment value to one Invoice Line Item and therefore one Placement. Required attributes: identifier, organization, payment, invoice, invoice line item, placement, allocated amount cents, allocation method (`Proportional` or `Manual`), allocated by, reason for a manual change, and timestamp.

Successful payment value is allocated proportionally across unpaid invoice lines by default. Finance may change allocation while preserving adjustment history. Allocations cannot exceed available net payment value. A Placement's allocated net payments determine whether its required deposit is satisfied.

### Advertiser Credit

An organization- and advertiser-scoped unapplied credit balance created when successful payment value exceeds the Invoice balance. Required attributes: identifier, organization, advertiser, source payment, original amount cents, available amount cents, currency, status, created timestamp, and audit history.

Finance may apply credit to a future Invoice through traceable credit application records or refund it under refund approval rules. Credit is never automatically refunded and cannot cross advertisers, organizations, or currencies.

### Refund

An append-only return of funds against one successful Payment.

Required attributes: identifier, organization, payment, amount cents, status, reason, initiated by, created timestamp, and processed timestamp. Total successful refunds may not exceed the successful payment amount.

### Campaign Expense

An individual actual campaign cost. Required attributes include organization, campaign, expense category, description, actual amount cents, currency, incurred date, vendor/reference when available, status, created by, and timestamps. Campaign Expense is the authoritative ledger for actual campaign costs. A generic other-cost scalar is not authoritative and must not compete with this ledger.

## Operations and history

### Task

An organization-scoped work item related to one or more of: Advertiser, Opportunity, Campaign, Placement, Artwork Package, or Invoice.

Required attributes: identifier, organization, title, description, status, priority, assignee membership, due timestamp, completed timestamp, related-entity references, and timestamps.

Statuses: `Open`, `In Progress`, `Completed`, `Canceled`. Priorities: `Low`, `Normal`, `High`, `Urgent`.

### Activity Event

An append-only chronological business timeline event, especially for an Advertiser. It records event type, organization, advertiser, actor, related entity, occurred timestamp, human-readable summary, and structured metadata.

Types include lead creation, call, email, note, reservation, invoice, payment, artwork submission, proof, approval, campaign completion, and renewal activity. Events may be system-generated or user-entered. Corrections append a new event rather than rewriting history.

### Audit Event

An append-only compliance/traceability record for important changes.

Required attributes: identifier, organization, actor User (or explicit system actor), entity type, entity identifier, action, previous value when appropriate, new value when appropriate, timestamp, and optional reason/correlation identifier.

Audit events cannot be edited or deleted through normal application use. Sensitive fields must be redacted according to a future retention policy.

## Relationship summary

```text
User ──< Organization Membership >── Organization
                                          │
                     ┌────────────────────┼────────────────────┐
                     ▼                    ▼                    ▼
                Advertiser            Campaign              Audit Event
                 │  │  │                 │  │
        Contact ─┘  │  └─ Location       │  └─ Campaign Slot
                    │                    │          │
                    ├─ Opportunity ──────┼────── Placement
                    │                    │          ├─ Artwork Package ─ Proof ─ Approval
                    │                    │          └─ Invoice Line Item
                    └─ Invoice ─ Invoice Line Item ─┘
                         └─ Payment ─ Refund
```

## Open questions requiring founder approval

1. Can one Opportunity intentionally produce multiple Placements, or must each placement have its own opportunity?
2. May an Advertiser have multiple categories, and which category controls exclusivity for a placement?
3. Should contact and location deletion be prohibited entirely or allowed only when never referenced?
4. Is tax required, and if so, which jurisdictions and rounding rules apply?
5. What membership assignment model determines which advertisers a Salesperson can access?
6. What retention and redaction rules apply to personal contact data and audit snapshots?
7. How is the organization deposit percentage rounded when it produces a fractional cent?

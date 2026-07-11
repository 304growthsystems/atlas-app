# Atlas Founder Decisions

## Record conventions

This is the authoritative decision log for approved Project Atlas business policy. Each entry was adopted on **July 11, 2026**. A later change must add a superseding decision rather than silently rewriting historical rationale.

## FD-001 — Deposit-gated placement confirmation

**Decision:** A Placement becomes Confirmed when allocated net payments satisfy its required deposit. The default required deposit is 100% of Placement sale price, and an Organization may configure a smaller percentage. Owner or Administrator may override the requirement only with a written reason and audit event.

**Reasoning:** Confirmation must represent measurable commercial commitment while allowing organizations to operate with a deposit model. A controlled override handles exceptional agreements without hiding them.

## FD-002 — Holds and projected revenue

**Decision:** Held Placements do not count toward Projected Revenue. An active, unexpired Hold blocks its Campaign Slot and participates in category exclusivity until expiration or cancellation.

**Reasoning:** A hold protects promised inventory without overstating forecast revenue from an uncommitted sale.

## FD-003 — Hold duration and extension

**Decision:** Holds expire after 72 hours by default. Sales Manager and Administrator may extend a Hold up to seven total days from original creation. Each extension requires a reason and audit event.

**Reasoning:** Time-limited holds balance salesperson flexibility with the need to return scarce shared inventory to market.

## FD-004 — Version 1 invoice campaign boundary

**Decision:** One Invoice may cover multiple Placements only when all belong to the same Organization, Advertiser, and Campaign. Version 1 invoices cannot span Campaigns.

**Reasoning:** Grouping same-campaign purchases supports common sales while keeping fulfillment, revenue attribution, allocation, and cancellation understandable.

## FD-005 — Placement-linked lines and payment allocation

**Decision:** Each Invoice Line Item remains linked to one Placement. Successful payments allocate proportionally across unpaid lines by default. Finance may manually change allocations with traceable reason/history. A Placement becomes Confirmed when its allocated net payments satisfy its required deposit.

**Reasoning:** Line-level allocation makes a multi-placement invoice compatible with deposit-based confirmation and campaign reporting while preserving Finance control for negotiated payment arrangements.

## FD-006 — Overpayments and Advertiser Credit

**Decision:** Successful value above an Invoice balance creates unapplied Advertiser Credit. It is not automatically refunded. Finance may apply it to a future Invoice or refund it under refund approval rules.

**Reasoning:** Preserving excess value as a traceable liability avoids losing money, creating negative invoice balances, or making an unapproved automatic refund.

## FD-007 — Estimated and actual campaign costs

**Decision:** Campaign stores estimated printing and postage. Actual costs are individual Campaign Expense records. Projected calculations use estimates; final calculations use actual expenses when available. No generic other-cost scalar competes with the actual expense ledger.

**Reasoning:** Separate estimates and actuals support planning and accurate closeout without double-counting or overwriting the original forecast.

## FD-008 — Independent invoice state dimensions

**Decision:** Invoice uses three dimensions: Lifecycle (`Draft`, `Sent`, `Void`), Payment state (`Unpaid`, `Partially Paid`, `Paid`, `Overpaid`, `Refunded`, `Partially Refunded`), and Aging state (`Current`, `Overdue`).

**Reasoning:** A single status cannot accurately represent combinations such as a sent, partially paid, overdue invoice. Independent dimensions remove that contradiction.

## FD-009 — Initial Campaign Health model

**Decision:** Campaign Health is derived from Inventory readiness (30%), Payment readiness (25%), Artwork/proof readiness (25%), Deadline risk (10%), and Printer/mailing confirmation (10%). Scores 80–100 are Healthy, 60–79 Need Attention, and below 60 are At Risk. Unavailable slots are excluded from inventory denominator. House Ads count as filled but not sold and generate no revenue.

**Reasoning:** Weighted operational dimensions produce an explainable signal while preserving the important distinction between inventory utilization and revenue-producing sales.

## FD-010 — Proof approval authority

**Decision:** An authorized Advertiser contact, Owner, or Administrator may approve a Proof. Designer may create and send Proofs but cannot approve on behalf of an Advertiser.

**Reasoning:** Approval must come from the customer or accountable organizational authority, while design and approval remain appropriately separated.

## FD-011 — Production transition authority

**Decision:** Owner, Administrator, and Designer may mark Ready for Print after all gates and may mark Sent to Printer. Only Owner and Administrator may mark Mailed or Published and Completed.

**Reasoning:** Designers can control artwork/production handoff, while fulfillment confirmation and final organizational closeout remain accountable operational decisions.

## FD-012 — Salesperson reassignment and commission ownership

**Decision:** Reassignment changes future responsibility but not historical commission ownership. Commission transfer requires Administrator approval, reason, and audit event.

**Reasoning:** Operational ownership must be movable without silently rewriting compensation history.

## FD-013 — Refund approval threshold

**Decision:** Finance may issue refunds up to the Organization-configured threshold, initially $500 (`50,000` cents). Refunds above the threshold and every full-Invoice refund require Owner or Administrator approval.

**Reasoning:** Finance needs authority for routine corrections, while large or total reversals receive higher-level review. Storing the threshold in cents follows Atlas monetary rules.

## FD-014 — Multi-advertiser portal users

**Decision:** One portal User may represent multiple Advertisers through separate Advertiser Portal Memberships. Every portal operation requires an explicit Advertiser context and prevents cross-advertiser leakage.

**Reasoning:** Real people may manage several businesses, but convenience cannot weaken tenant or advertiser-level isolation.

## FD-015 — Multiple slots and exclusivity

**Decision:** One Advertiser may purchase multiple Campaign Slots in the same Campaign. Category exclusivity blocks competing Advertisers in the restricted category, not additional allowed inventory for the same Advertiser.

**Reasoning:** Exclusivity protects a buyer from category competitors; it is not intended to prevent that buyer from purchasing a larger share of available inventory.

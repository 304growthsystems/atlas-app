# Atlas Financial Rules

## Accounting scope and representation

Atlas operationally tracks campaign sales, receivables, collections, refunds, and campaign costs. It is not yet specified as a general ledger or tax-accounting system.

Approved policy decisions are recorded in [FOUNDER_DECISIONS.md](./FOUNDER_DECISIONS.md).

- Every monetary value MUST be an integer number of minor currency units (`cents` for USD), never a floating-point value.
- Every financial record MUST carry a currency code. Combining different currencies in one calculation or invoice is prohibited without a future exchange-rate specification.
- Negative invoice lines, discounts, taxes, credits, deposits, and write-offs are not approved concepts until explicitly defined.
- Financial records use append/void/refund/correction behavior and MUST NOT be permanently deleted.
- Calculations use source records, not manually entered dashboard totals.

Example: `$495.00` is stored as `49500`, and `$1,460.00` as `146000`.

## Price and cost sources

### Slot standard price

Campaign Slot standard price is a default quote in cents. It does not itself count as revenue.

### Placement sale price

Placement sale price is the agreed amount in cents copied at creation/reservation. Later changes to Slot standard price do not change existing Placements. Changing sale price on an active Placement requires sales authority, reason, and audit. Once invoiced, price changes require an approved invoice correction process rather than silently editing sent line items.

### Required placement deposit

Required deposit is a Placement monetary requirement in cents. It defaults to 100% of Placement sale price and uses the Organization's configured smaller percentage when set. It must be between zero and sale price. Net Payment Allocations to the Placement satisfy the deposit; money merely received on an Invoice without allocation does not. Owner or Administrator may override the requirement with written reason and audit event. Deposit satisfaction confirms the Placement and changes its reserved Slot to Sold, subject to occupancy and exclusivity invariants.

### Campaign cost

Approved definition:

```text
Projected Campaign Cost = Estimated Printing Cost + Estimated Postage Cost
Final Campaign Cost = SUM(actual Campaign Expense amounts)
```

Campaign stores estimated printing and postage amounts. Actual costs are individual Campaign Expense records and are authoritative for final calculations when available. A generic other-cost scalar must not compete with or be added to the expense ledger. Each amount is non-negative cents in campaign currency. Reports must clearly label estimates and actuals.

## Revenue and profit calculations

All calculations are organization- and campaign-scoped unless a broader authorized report explicitly aggregates campaigns.

### Projected Revenue

```text
Projected Revenue = SUM(Placement.sale_price_cents)
where Placement.status IN (Reserved, Confirmed, Completed)
```

Held and Canceled Placements contribute zero. Holds block inventory and category exclusivity but are not revenue. Reports should break out Reserved, Confirmed, and Completed values.

House Ads and Unavailable/Available slots contribute zero. Failed or canceled opportunities contribute zero.

### Collected Revenue

```text
Gross Collected Cash =
  SUM(Succeeded Payment.amount_cents) - SUM(Succeeded Refund.amount_cents)

Collected Revenue =
  SUM(net Payment Allocations to non-Void Invoice Lines)
```

Only settled/succeeded funds count. Pending and Failed payments contribute zero. A refunded payment contributes only its unrefunded net amount. Unapplied Advertiser Credit is a liability and is excluded from Collected Revenue until Finance applies it to an Invoice Line. Reserved but unpaid inventory contributes zero.

At campaign and Placement level, use Payment Allocations through Invoice Line Items. Payments allocate proportionally across unpaid lines by default; Finance may manually reallocate with reason and audit history.

### Outstanding Revenue

For each Invoice with lifecycle `Sent`:

```text
Net Paid = successful payments - successful refunds
Invoice Balance = MAX(Invoice Total - Allocated Net Paid - Applied Advertiser Credit, 0)
Outstanding Revenue = SUM(positive Invoice Balance)
```

Unapplied Advertiser Credit is not subtracted until Finance applies it to the Invoice. Draft and Void invoices do not constitute receivables. Refund effects are derived from allocations and credit/refund records, never from a single status.

### Projected Profit

```text
Projected Profit = Projected Revenue - Projected Campaign Cost
```

### Collected Profit

```text
Collected Profit = Collected Revenue - Final Campaign Cost
```

Collected Profit can be negative and does not imply accounting net income. Before actual expenses are available, any provisional collected-profit display must clearly use and label estimated cost rather than presenting a final value.

## Invoice rules

### Composition and totals

- Invoice belongs to one Organization, one Advertiser, one Campaign, and one currency.
- It contains one or more line items before sending.
- Each line item references one Placement in the Invoice Campaign. Multiple lines may reference multiple placements for the same advertiser and campaign; Version 1 invoices may not span campaigns.
- Line total is calculated from integer quantity and unit amount according to an approved quantity model. Advertising placements will normally use quantity `1`.
- Invoice total equals the exact sum of line totals plus only explicitly approved adjustments/tax.
- Invoice number is unique within an Organization and assigned no later than Send.
- Due date cannot precede issue date.
- Sent invoice commercial fields and lines are immutable. Corrections require void/reissue or future credit-note rules.

### Independent invoice state dimensions

An Invoice never uses one overloaded status. Its three dimensions are evaluated independently:

| Dimension | Values | Rule |
|---|---|---|
| Lifecycle | Draft, Sent, Void | Draft may become Sent or Void; Sent may become Void under correction policy; Void is terminal |
| Payment state | Unpaid, Partially Paid, Paid, Overpaid, Refunded, Partially Refunded | Derived from allocated payments, refunds, applied credit, total, and unapplied excess |
| Aging state | Current, Overdue | A Sent Invoice with positive balance after its due-date boundary is Overdue; otherwise Current |

Thus an invoice can simultaneously be lifecycle `Sent`, payment state `Partially Paid`, and aging state `Overdue`. `Overpaid` means successful value exceeds invoice balance and the excess has become Advertiser Credit. Refund states preserve the distinction between partial and full refund without changing lifecycle.

### One invoice covering multiple placements

- Every line identifies its Placement, Campaign, description, and amount.
- All Placements must belong to the Invoice Advertiser, Organization, Campaign, and currency.
- Canceling one Placement does not delete its line or other placements' charges; Finance applies the approved void/credit/refund process.
- Successful payment value is allocated proportionally across each unpaid line amount by default. Finance may manually change allocation with a reason; prior allocation history remains traceable.

## Payment rules

- Payment is always a separate record linked to an Invoice.
- Amount is positive cents and currency matches Invoice.
- Pending and Failed payments do not reduce balance.
- A Succeeded Payment records method, received timestamp, and external/reference identifier where available.
- A unique idempotency/reference key prevents duplicate recording of the same receipt.
- On success, available value is allocated proportionally across unpaid Invoice Lines. Finance may replace the default distribution with manual Payment Allocations; the total allocated cannot exceed available net payment value.
- After allocations change, each related Placement is evaluated against its required deposit. A Reserved Placement becomes Confirmed and its Slot becomes Sold once allocated net payments meet the deposit, subject to other invariants.
- Payment status transitions normally follow `Pending → Succeeded|Failed`, `Succeeded → Partially Refunded|Refunded`, and `Partially Refunded → Partially Refunded|Refunded`.
- A Succeeded payment is never changed to Failed to reverse it; use Refund.
- Failed attempts remain visible but are excluded from collection totals.

### Partial payments

Partial payments are allowed. Each receipt is a separate Payment. The Invoice balance is recomputed from records rather than decremented as an untraceable counter.

Example:

```text
Invoice total:       49,500 cents
Payment 1 succeeded: 20,000 cents
Payment 2 succeeded: 10,000 cents
Balance:             19,500 cents
Lifecycle:           Sent
Payment state:       Partially Paid
Aging state:         Current or Overdue independently
```

### Overpayments

Successful value above current Invoice balance creates an unapplied Advertiser Credit for the exact excess. It does not force Invoice balance below zero and is not automatically refunded. Credit remains scoped to the same Organization, Advertiser, and currency. Finance may apply some or all available credit to a future Invoice through a traceable application or refund it under the refund approval rules.

Example: a `50,000` cent payment against a `49,500` cent balance fully pays the Invoice and creates `500` cents of Advertiser Credit; Invoice payment state is `Overpaid` while that excess remains attributable to the receipt.

## Refund rules

- Refund is a separate append-only record against one Succeeded Payment.
- Refund amount is positive and cumulative successful refunds cannot exceed original successful Payment.
- Refund reason, initiating actor, status, and timestamps are required.
- A partial successful refund changes Payment to Partially Refunded; full cumulative refund changes it to Refunded.
- Failed/pending refund attempts remain historical but do not reduce Collected Revenue.
- Refund does not delete or mutate original receipt amount.
- Finance may issue refunds up to the Organization-configured approval threshold, initially `50,000` cents ($500). A refund above that threshold or any full-Invoice refund requires Owner or Administrator approval.
- Refunding money and canceling/voiding an Invoice or Placement are separate authorized actions.
- Refunds reverse related Payment Allocations or Advertiser Credit as applicable. Whether reversing an allocated payment reopens a receivable or accompanies a separate Invoice adjustment remains an unresolved correction-policy question.

Example:

```text
Successful payment: 49,500 cents
Successful refund:  10,000 cents
Net collected:       39,500 cents
Payment status:      Partially Refunded
```

## Cancellations and financial records

- Canceling a Placement or Campaign never deletes or automatically rewrites an Invoice, Payment, or Refund.
- Unsents Draft invoices may be Void under authorized policy.
- Sent invoices require an explicit Finance decision: remain collectible, void/reissue, credit, or refund. Credit-note behavior is not yet defined.
- A canceled campaign can retain collected revenue and costs; reports must expose cancellation status and not imply successful fulfillment.
- Completed campaign status does not imply invoices are Paid.

## Authorization and audit

- Finance, Administrator, and Owner can send invoices and record payments according to the permission matrix.
- Finance may issue refunds within the configured threshold; Owner or Administrator approval is required above it and for every full-Invoice refund.
- Sales roles can view permitted commercial price/balance information but cannot mark a Payment Succeeded or issue a Refund.
- Advertiser may view/pay only invoices belonging to its linked advertiser scope; it cannot alter financial records.
- Sent/void/refund/payment-success changes, price overrides, due-date changes, and external reference changes require audit events with previous/new values and actor.

## Reconciliation and invariants

The following must be checked transactionally or by continuous reconciliation:

- Invoice total equals sum of valid lines and approved adjustments.
- Net successful payments do not produce a negative balance under the approved overpayment policy.
- Successful refunds do not exceed their Payment.
- Cached paid/balance fields, if stored, equal source-record calculations.
- Placement/campaign/advertiser links on invoice lines are same-tenant and internally consistent.
- Dashboard values can be traced to contributing record identifiers.
- Financial exports report currency and time range explicitly.

## Open questions requiring founder approval

1. Are taxes, discounts, write-offs, credit notes, and non-placement invoice lines required in Version 1?
2. When only some actual Campaign Expenses have arrived, should final calculations remain unavailable or combine actuals with remaining estimates?
3. Does refunding an allocated payment reopen the Invoice balance automatically, or require a linked invoice adjustment based on reason?
4. How are rounding remainders assigned during proportional Payment Allocation?
5. Are invoice numbers sequential, and may gaps exist after voiding?
6. What timezone determines due-date rollover and Aging state?
7. How is an `Overpaid` Payment state changed after all associated Advertiser Credit is applied or refunded?

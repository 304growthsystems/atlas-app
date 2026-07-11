# Atlas Roles and Permissions

## Authorization model

Authorization is evaluated for an active Organization Membership, not for a User globally. A user with different roles in different organizations receives only the current organization's role. No role bypasses organization isolation.

Approved policy decisions are recorded in [FOUNDER_DECISIONS.md](./FOUNDER_DECISIONS.md).

Permissions use three scopes:

- **All:** all records in the current organization.
- **Assigned:** records assigned to the member plus the minimum related records needed to perform the work.
- **Own advertiser:** only records belonging to advertiser account(s) explicitly linked to an Advertiser membership.

Role checks must be enforced on the server for every command and query. Hiding interface controls is not authorization. Sensitive exports, attachments, reports, search results, audit values, and timeline events follow the same scope.

Legend:

- `✓` permitted within the role's scope.
- `V` view only within scope.
- `L` limited operation described in Notes.
- `—` not permitted.

## Role definitions

### Owner

Full organization access, including membership/role management, ownership transfer, billing-plan settings, organization-wide configuration, and destructive organization actions. At least one active Owner must remain.

### Administrator

Broad operational access. Cannot transfer ownership, remove/demote the last Owner, change billing plan, delete/close the Organization, or perform other ownership-only actions.

### Sales Manager

Organization-wide sales access: sales team visibility, Advertisers, Opportunities, Placements, related Tasks, campaign inventory needed for selling, and sales reporting. No financial transaction authority unless separately granted by a future permission system.

### Salesperson

Assigned-scope access to Advertisers, Opportunities, Placements, Tasks, relevant campaign inventory, and commission-related data. Assignment must be explicit; general organization-wide customer or financial access is prohibited.

### Designer

Artwork/proof/approval workflow access and only the Advertiser contact/location/campaign/placement data required to execute that work. No broad sales notes or financial details.

### Finance

Invoices, Payments, Refunds, financial reporting, Advertiser billing contacts, and related campaign/placement context. No sales-team administration or artwork modification.

### Advertiser

Portal-only access to Advertisers granted through separate active Advertiser Portal Memberships. A user may represent multiple Advertisers but must select an explicit Advertiser context; every query and command is constrained to that context. It cannot see internal notes, margin/cost data, unselected or ungranted advertisers, other slots' buyers, internal audit records, or staff-only reports.

## Organization and membership permissions

| Action | Owner | Administrator | Sales Manager | Salesperson | Designer | Finance | Advertiser | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| View organization profile | ✓ | ✓ | V | V | V | V | V | Expose only fields needed by role |
| Edit operational organization settings | ✓ | ✓ | — | — | — | — | — | Includes product configuration, not billing plan |
| View members | ✓ | ✓ | L | — | L | L | — | Manager sees sales team; Designer/Finance see staff identity needed for attribution |
| Invite/remove non-Owner members | ✓ | ✓ | — | — | — | — | — | Removal cannot violate record/audit history |
| Assign/change roles | ✓ | L | — | — | — | — | — | Administrator cannot grant Owner or change Owners |
| Transfer ownership | ✓ | — | — | — | — | — | — | Must retain active Owner and audit transfer |
| Change billing plan | ✓ | — | — | — | — | — | — | Ownership-only |
| Close/delete organization | ✓ | — | — | — | — | — | — | Exact destructive policy remains undefined |
| View audit log | ✓ | ✓ | L | — | — | L | — | Manager: sales events; Finance: financial events only |

## Advertiser, contact, and location permissions

| Action | Owner | Administrator | Sales Manager | Salesperson | Designer | Finance | Advertiser | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| List/view Advertisers | ✓ | ✓ | ✓ | Assigned | L | L | Own | Designer gets production contacts; Finance gets billing contacts |
| Create Advertiser | ✓ | ✓ | ✓ | ✓ | — | — | — | Duplicate review required |
| Edit core Advertiser details | ✓ | ✓ | ✓ | Assigned | — | L | L | Finance: billing fields; Advertiser: approved portal fields only |
| Archive Advertiser | ✓ | ✓ | L | — | — | — | — | Sales Manager only when no blocking active records |
| Manage Contacts/Locations | ✓ | ✓ | ✓ | Assigned | L | L | L | Limited roles only fields relevant to their function |
| Set primary Contact/Location | ✓ | ✓ | ✓ | Assigned | — | L | L | Finance may set billing contact only if modeled separately |
| View advertiser timeline | ✓ | ✓ | ✓ | Assigned | L | L | L | Each limited role sees only permitted event types/fields |
| Add calls/emails/sales notes | ✓ | ✓ | ✓ | Assigned | — | — | — | Internal notes hidden from Advertiser |
| View another advertiser | ✓ | ✓ | ✓ | Only if assigned | Only if work requires | Only if billing requires | — | Cross-advertiser leakage prohibited |

## Campaign and inventory permissions

| Action | Owner | Administrator | Sales Manager | Salesperson | Designer | Finance | Advertiser | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| List/view Campaigns | ✓ | ✓ | ✓ | V | V | V | L | Advertiser sees only campaigns containing its records |
| Create/edit Draft Campaign | ✓ | ✓ | L | — | — | L | Manager may create; Finance edits cost fields only |
| Configure dates/product/territory | ✓ | ✓ | ✓ | — | V | — | — | Changes near deadlines audited |
| Configure campaign costs | ✓ | ✓ | V | — | — | ✓ | — | Sales may see only price/margin data permitted by policy |
| Add/edit Available slots | ✓ | ✓ | ✓ | — | V | V | — | Occupied slot changes restricted |
| Mark slot Unavailable/House Ad | ✓ | ✓ | ✓ | — | — | — | — | Reason and audit required |
| View slot occupancy | ✓ | ✓ | ✓ | V | V | V | L | Advertiser sees only own placement, not competitor identity |
| Enable category exclusivity | ✓ | ✓ | ✓ | — | V | — | — | Campaign configuration change audited |
| Override category conflict | ✓ | ✓ | L | — | — | — | — | Sales Manager permission requires founder approval |
| Advance sales-stage campaign statuses | ✓ | ✓ | ✓ | — | V | V | — | Draft through Proofing, subject to gates |
| Mark Ready for Print | ✓ | ✓ | — | — | ✓ | — | — | All readiness gates must pass |
| Mark Sent to Printer | ✓ | ✓ | — | — | ✓ | — | — | Submission details required |
| Mark Mailed/Published | ✓ | ✓ | — | — | — | — | — | Must record evidence |
| Complete Campaign | ✓ | ✓ | — | — | — | V | — | Closeout gate required |
| Cancel Campaign | ✓ | ✓ | L | — | — | V | — | Manager only before production; founder confirmation needed |

## Opportunity and placement permissions

| Action | Owner | Administrator | Sales Manager | Salesperson | Designer | Finance | Advertiser | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| View Opportunities | ✓ | ✓ | ✓ | Assigned | — | — | — | Internal pipeline hidden from Advertiser |
| Create/update Opportunity | ✓ | ✓ | ✓ | Assigned | — | — | — | Stage and assignment rules apply |
| Assign/reassign Salesperson | ✓ | ✓ | ✓ | — | — | — | — | Changes future responsibility only |
| Transfer commission ownership | ✓ | ✓ | — | — | — | — | — | Administrator approval, reason, and audit required |
| Mark Opportunity Won/Lost | ✓ | ✓ | ✓ | Assigned | — | — | — | Won requires placement; Lost requires reason |
| Create renewal Opportunity | ✓ | ✓ | ✓ | Assigned | — | — | — | System may suggest but not finalize |
| View Placements | ✓ | ✓ | ✓ | Assigned | L | L | Own | Limited roles see function-required fields |
| Hold/Reserve slot | ✓ | ✓ | ✓ | Assigned | — | — | — | Atomic occupancy/exclusivity checks |
| Confirm Placement | ✓ | ✓ | ✓ | L | — | V | — | Salesperson authority depends on commercial gate policy |
| Change sale price | ✓ | ✓ | ✓ | L | — | V | — | Salesperson discount limits are open |
| Cancel Held/Reserved Placement | ✓ | ✓ | ✓ | Assigned | — | V | L | Advertiser may request cancellation; staff executes it |
| Cancel Confirmed Placement | ✓ | ✓ | ✓ | — | — | L | L | Finance coordinates impact; Advertiser requests only |
| View commission-related data | ✓ | ✓ | ✓ | Own | — | — | — | Commission formula remains undefined |

## Artwork and proof permissions

| Action | Owner | Administrator | Sales Manager | Salesperson | Designer | Finance | Advertiser | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| View Artwork Package/proofs | ✓ | ✓ | ✓ | Assigned | ✓ | — | Own | Proof/file access tenant- and record-scoped |
| Request artwork | ✓ | ✓ | ✓ | Assigned | ✓ | — | — | Request authority may be narrowed later |
| Submit artwork/assets | ✓ | ✓ | ✓ | Assigned | ✓ | — | Own | Actor/source attribution required |
| Create design/proof version | ✓ | ✓ | — | — | ✓ | — | — | Versions immutable |
| Send proof | ✓ | ✓ | — | — | ✓ | — | — | Exact version and recipient recorded |
| Request revision | ✓ | ✓ | ✓ | Assigned | ✓ | — | Own | Staff acting for advertiser records true requester |
| Approve proof | ✓ | ✓ | — | — | — | — | Own | Advertiser approval requires an authorized contact; Designer cannot approve |
| Mark Artwork Print Ready | ✓ | ✓ | — | — | ✓ | — | — | Requires current approved version |
| Replace/delete approved version | — | — | — | — | — | — | — | Never permitted; create new version |

## Invoice, payment, and reporting permissions

| Action | Owner | Administrator | Sales Manager | Salesperson | Designer | Finance | Advertiser | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| View Invoice summary | ✓ | ✓ | ✓ | Assigned | — | ✓ | Own | Sales views commercial status; not payment method details |
| View full billing/payment details | ✓ | ✓ | — | — | — | ✓ | Own | Mask sensitive method data |
| Create/edit Draft Invoice | ✓ | ✓ | — | — | — | ✓ | — | Sales may request billing via task/workflow |
| Send Invoice | ✓ | ✓ | — | — | — | ✓ | — | Sent content immutable |
| Void Invoice | ✓ | ✓ | — | — | — | ✓ | — | Reason and audit required; approval threshold open |
| Record Payment result | ✓ | ✓ | — | — | — | ✓ | — | Advertiser may initiate future processor payment, not set status |
| Initiate/record Refund | ✓ | ✓ | — | — | — | L | — | Finance up to configured threshold; above threshold/full Invoice requires Owner/Admin approval |
| Apply Advertiser Credit | ✓ | ✓ | — | — | — | ✓ | — | Same advertiser, organization, and currency only |
| Manually change Payment Allocation | ✓ | ✓ | — | — | — | ✓ | — | Reason and allocation history required |
| View campaign costs/profit | ✓ | ✓ | L | L | — | ✓ | — | Sales visibility and margin granularity require approval |
| View sales reports | ✓ | ✓ | ✓ | Own | — | L | — | Finance limited to needed financial dimensions |
| View financial reports | ✓ | ✓ | L | — | — | ✓ | L | Advertiser only own statements/invoice history |
| Export financial data | ✓ | ✓ | — | — | — | ✓ | L | Advertiser exports own documents only; audit exports |

## Task, activity, and audit permissions

| Action | Owner | Administrator | Sales Manager | Salesperson | Designer | Finance | Advertiser | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| View Tasks | ✓ | ✓ | ✓ | Assigned | Assigned | Assigned | L | Advertiser only explicitly shared portal tasks |
| Create/assign Tasks | ✓ | ✓ | ✓ | L | L | L | Non-managers assign self or within permitted workflow |
| Update Task status | ✓ | ✓ | ✓ | Assigned | Assigned | Assigned | L | Advertiser may complete requested portal task if allowed |
| Cancel another user's Task | ✓ | ✓ | ✓ | — | — | — | — | Workflow-generated tasks may require domain action instead |
| Add Activity Event/note | ✓ | ✓ | ✓ | Assigned | L | L | L | Event visibility depends on content classification |
| Edit/delete Activity Event | — | — | — | — | — | — | — | Correction is appended; retention admin process not normal use |
| View scoped Audit Events | ✓ | ✓ | Sales | — | — | Finance | — | Sensitive values redacted |
| Edit/delete Audit Event | — | — | — | — | — | — | — | Never through normal application use |

## Record-level and field-level rules

1. **Assigned Salesperson scope:** Assignment through Opportunity, Placement, Advertiser account assignment, or Task must be explicit. Merely creating a record does not grant permanent access after reassignment.
2. **Designer minimum data:** Company name, relevant location, production contact, placement specification, deadlines, and artwork history. Hide invoices, payments, margins, unrelated sales notes, and unrelated contacts.
3. **Finance minimum data:** Company/billing contacts, invoice lines, payment/refund history, campaign/placement identifiers, sale amounts, and costs. Hide artwork files and unrelated pipeline notes.
4. **Advertiser portal:** Resolve active Advertiser Portal Memberships, require one explicit advertiser context, and filter every record by that advertiser plus current organization. Switching context requires a separate grant and authorization check. Internal notes, audit events, other advertisers, internal costs/profit, salesperson commission, and unshared tasks are excluded.
5. **Salesperson finance view:** May see price, invoice state, and outstanding amount for assigned sales needed for follow-up; payment method details and refund controls are excluded.
6. **Attachments:** File authorization is evaluated on every access, including expiring download links; knowing a file URL is insufficient.

## Permission-change and denial behavior

- Permission changes take effect on subsequent authorization checks and invalidate active access as soon as practical.
- Reassignment may remove Salesperson access but never changes historical actor attribution.
- Denied requests return no information that confirms existence of another tenant's or out-of-scope record.
- High-impact operations require explicit confirmation, reason, and audit even when role permits them.
- System automation operates as a named System actor with narrowly scoped service permission and creates audit events.

## Open questions requiring founder approval

1. May Sales Manager override category exclusivity and cancel campaigns before production?
2. What discount/price-change limits apply to Salespeople?
3. What evidence must Owner/Administrator retain when recording approval received outside the portal?
4. Which organization-wide sales and margin data may Salespeople see beyond their own commission data?
5. Can Administrators view/export the full audit log, including ownership and billing-plan events?
6. What constitutes assignment of an Advertiser to a Salesperson: direct account ownership, active Opportunity, active Placement, or any combination?
7. Are custom roles/permissions anticipated, or will fixed roles remain authoritative for the first release?

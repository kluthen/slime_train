---
id: rule_no_in_app_purchases
status: DRAFT
type: RULE
layer: BUSINESS
priority: 4
human_name: No purchases inside v1
tags: [monetization,contract-candidate]
parents:
  - [[req_scope_one_level_four_sections]]
version: 1.0
dependents: []
---

# No purchases inside v1

## INTENT
Guarantee that v1 offers nothing to buy inside the app.

## THE RULE / LOGIC
v1 is a paid app at about 3 to 5 dollars, with no purchases inside the app. Paid extra levels (about 2 dollars each) and a code required before any purchase are explicitly deferred to a later version, not part of v1.

## TECHNICAL INTERFACE
Parented to req_scope_one_level_four_sections. Flagged in contract_atd as a candidate for the guaranteed surface, pending human confirmation to promote to STABLE.

## EXPECTATION
No purchase flow of any kind is reachable inside the v1 build.

---
id: rule_parent_code_not_stored_plaintext
status: DRAFT
tags: [parent-gate,privacy,security]
human_name: Parent code never stored in plain text
version: 1.0
parents:
  - [[req_parent_gate_and_access]]
dependents: []
type: RULE
layer: BUSINESS
priority: 4
---

# Parent code never stored in plain text

## INTENT
Guarantee that the 6-digit parent code is never persisted on the phone in a form that a plain read of the save data would reveal.

## THE RULE / LOGIC
The parent code is stored locally only, as everywhere else in the app (no server, no account): it is never written to disk in plain text, at first-launch setup, on a change, or on a reset after a forgotten code. Whatever local storage holds instead (a hash or equivalent) is a technical choice for the implementer; this rule only guarantees that reading the save data directly never discloses the code. This does not weaken step-up: the code prompt still compares against the stored value, and a wrong entry still shakes, clears and counts toward the 5-in-a-row wait.

## TECHNICAL INTERFACE
Parented to req_parent_gate_and_access. Sibling guarantee to rule_no_network_connection (same parent, same privacy stance): protects the parent code the way that rule protects against remote access.

## EXPECTATION
No file or save on the phone holds the parent code in plain text, under any of the three ways the code is set (create, change, reset).

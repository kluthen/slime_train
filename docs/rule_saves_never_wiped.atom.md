---
id: rule_saves_never_wiped
status: DRAFT
dependents: []
layer: BUSINESS
priority: 4
human_name: Saves are never wiped
parents:
  - [[req_persistence_and_saves]]
version: 1.0
type: RULE
tags: [persistence,contract-candidate]
---

# Saves are never wiped

## INTENT
Guarantee that an app update never wipes a parent's existing save.

## THE RULE / LOGIC
Saves are never wiped. A released level isn't meant to change; if one does, the change is minor and ships with a save migration, and any slimes it displaces are treated as lost rather than the save being discarded. The save records the level's version, and slimes, objects and gates have stable IDs, which is what makes a migration possible instead of a reset.

## TECHNICAL INTERFACE
Parented to req_persistence_and_saves. Flagged in contract_atd as a candidate for the guaranteed surface, pending human confirmation to promote to STABLE.

## EXPECTATION
No update path clears an existing level save outright; any change to a released level arrives with a save migration.

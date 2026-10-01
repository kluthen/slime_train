---
id: rule_saves_never_wiped
status: STABLE
dependents: []
layer: BUSINESS
priority: 4
human_name: Saves are never wiped
parents:
  - [[req_persistence_and_saves]]
version: 1.1
type: RULE
tags: [persistence,contract-candidate]
---

# Saves are never wiped

## INTENT
Guarantee that an app update never wipes a parent's existing save.

## THE RULE / LOGIC
No player's build ever wipes a save: no update, migration or load-failure path deletes an existing level save; only a parent's explicit delete of one level's save removes it. A development aid that exists only in debug builds, is ignored by a release build and never reaches a release install, is outside this rule. A released level isn't meant to change; if one does, the change is minor and ships with a save migration, and any slimes it displaces are treated as lost rather than the save being discarded. The save records the level's version, and slimes, objects and gates have stable IDs, which is what makes a migration possible instead of a reset.

## TECHNICAL INTERFACE
Parented to req_persistence_and_saves. On contract_atd's guaranteed surface (STABLE, v1).

## EXPECTATION
No update path clears an existing level save outright; any change to a released level arrives with a save migration.

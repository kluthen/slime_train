---
id: rule_saves_never_wiped
status: STABLE
dependents: []
layer: BUSINESS
priority: 4
human_name: Saves are never wiped
parents:
  - [[req_persistence_and_saves]]
version: 1.2
type: RULE
tags: [persistence,contract-candidate]
---

# Saves are never wiped

## INTENT
Guarantee that an app update never wipes a parent's existing save.

## THE RULE / LOGIC
No player's build ever wipes a save: no update, migration or load-failure path deletes an existing level save; only a parent's explicit delete of one level's save removes it. A development aid that exists only in debug builds, is ignored by a release build and never reaches a release install, is outside this rule. A released level isn't meant to change; if one does, the change is minor and ships with a save migration, and the save is kept rather than discarded. Slimes the migration displaces are re-placed when their spot or a free spot exists, else lost: a displaced sleeper goes back asleep at its own stable ID's spot when the level still has that sleeper, otherwise at the level's nearest empty sleeper spot, whose stable ID it takes; an awake displaced slime, and a displaced sleeper left with no spot, are treated as lost. The save records the level's version, and slimes, objects and gates have stable IDs, which is what makes a migration possible instead of a reset.

## TECHNICAL INTERFACE
Parented to req_persistence_and_saves. On contract_atd's guaranteed surface (STABLE, v1). Reworded with the user's approval (2026-10-07): displaced slimes are re-placed when their spot or a free spot exists, else lost (before: every displaced slime was lost); the no-wipe guarantee is unchanged, recorded in contract_atd 1.2.

## EXPECTATION
No update path clears an existing level save outright; any change to a released level arrives with a save migration.

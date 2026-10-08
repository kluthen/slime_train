---
id: domain_saves_per_level
status: DRAFT
parents:
  - [[domain_architecture_rationale]]
dependents: []
layer: BUSINESS
priority: 2
tags: [architecture,rationale,persistence]
human_name: One save per level
type: DOMAIN
version: 1.1
---

# One save per level

## INTENT
Record why saves are kept one per level and never wiped.

## THE RULE / LOGIC
Saves are one per level and never wiped, so a parent can reset one level without losing others, and level updates migrate saves rather than breaking them. A save the build can't use, one missing a value a load reads or holding one of the wrong type included, is refused rather than crashing the load, and is kept rather than deleted (before the first store release it is set aside with its backup and the level starts fresh), so refusing a save never wipes it.

## TECHNICAL INTERFACE
Narrative context only; no code tag. Read by whoever designs ARCHITECTURE-layer atoms for persistence and saves, to understand why the constraint exists before proposing an alternative. As built, the checks that decide whether a save is refused are SaveChecks (src/sim/save_checks.gd, through SaveData.problems), and a refused save is set aside by SaveStore.set_aside_save (src/save/save_store.gd); req_persistence_and_saves states them in full.

## EXPECTATION
N/A (narrative atom, not independently testable). Its content is corroborated by the ARCHITECTURE-layer atoms that eventually implement this decision, and by the REQUIREMENT/RULE atoms whose behaviour depends on it (e.g. req_persistence_and_saves, rule_saves_never_wiped).

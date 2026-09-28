---
id: rule_released_level_stable_with_migration
status: DRAFT
type: RULE
priority: 4
human_name: Level rule 20: a released level changes only with a migration
tags: [level-rule,persistence]
parents:
  - [[req_level_design_rules]]
version: 1.0
layer: BUSINESS
dependents: []
---

# Level rule 20: a released level changes only with a migration

## INTENT
Require that any change to a released level stays minor and ships with a save migration.

## THE RULE / LOGIC
A released level isn't meant to change; any update is minor, ships with a save migration, and keeps stable IDs for slimes, objects and gates (see rule_saves_never_wiped).

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 20 of 20).

## EXPECTATION
Any post-release change to a shipped level's layout ships together with a save migration and preserves existing stable IDs.

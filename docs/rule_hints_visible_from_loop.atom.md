---
id: rule_hints_visible_from_loop
status: DRAFT
priority: 3
human_name: Level rule 9: exploration hints are visible from the loop
tags: [level-rule]
parents:
  - [[req_level_design_rules]]
dependents: []
type: RULE
layer: BUSINESS
version: 1.0
---

# Level rule 9: exploration hints are visible from the loop

## INTENT
Require that a level always shows, from the loop, that there is something to explore off it.

## THE RULE / LOGIC
Hints that there is something to explore are visible from the loop, so a child on the loop can discover exploration branches without having to already know they exist.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 9 of 20). Serves persona goal P3.G2.

## EXPECTATION
Every exploration branch in a shipped level has a hint visible from the loop itself.

---
id: rule_gravity_leads_back_to_loop
status: DRAFT
type: RULE
layer: BUSINESS
tags: [level-rule]
parents:
  - [[req_level_design_rules]]
version: 1.0
priority: 4
human_name: Level rule 7: gravity leads back to the loop
dependents: []
---

# Level rule 7: gravity leads back to the loop

## INTENT
Require that from anywhere a free slime can reach, gravity leads back toward the loop.

## THE RULE / LOGIC
From anywhere a free slime can reach, gravity leads back toward the loop. This is part of what makes 'lost' a safety net rather than a normal outcome (see rule_left_alone_and_lost).

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 7 of 20).

## EXPECTATION
No reachable off-loop area in a shipped level has terrain that leads a free slime away from every route back.

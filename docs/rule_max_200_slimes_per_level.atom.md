---
id: rule_max_200_slimes_per_level
status: DRAFT
type: RULE
priority: 4
parents:
  - [[req_level_design_rules]]
dependents: []
version: 1.0
layer: BUSINESS
human_name: Level rule 16: at most 200 slimes per level
tags: [level-rule,performance]
---

# Level rule 16: at most 200 slimes per level

## INTENT
Cap the total number of base slimes a level may contain.

## THE RULE / LOGIC
At most 200 slimes per level, counted in base slimes. Where many pile up on one screen, they should be mostly still (for example, filling a basket), to keep this within the performance targets on the floor phone.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 16 of 20). Drives req_platform_and_performance_targets's floor-phone worst case.

## EXPECTATION
No shipped level exceeds 200 base slimes in total.

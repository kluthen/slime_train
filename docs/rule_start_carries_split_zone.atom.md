---
id: rule_start_carries_split_zone
status: REVIEW
type: RULE
layer: BUSINESS
priority: 3
dependents: []
human_name: Level rule 4: the start of the loop carries a split zone
tags: [level-rule]
parents:
  - [[req_level_design_rules]]
version: 1.0
---

# Level rule 4: the start of the loop carries a split zone

## INTENT
Require that every level places a split zone at the start of its loop.

## THE RULE / LOGIC
The start of the loop carries a split zone. In v1 it is the only split zone in the level (see rule_split_zone_only_splitter for what a split zone does).

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 4 of 20).

## EXPECTATION
Every level's start-of-loop location contains a working split zone.

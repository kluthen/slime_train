---
id: rule_exploration_branch_has_route_back
status: DRAFT
layer: BUSINESS
priority: 4
human_name: Level rule 8: every exploration branch has a route back
tags: [level-rule]
version: 1.0
type: RULE
parents:
  - [[req_level_design_rules]]
dependents: []
---

# Level rule 8: every exploration branch has a route back

## INTENT
Require that every exploration branch includes its own authored route back to the loop.

## THE RULE / LOGIC
Every exploration branch includes its own route back to the loop, authored as level data (a path drawn in the editor), so a heading-back slime never needs general pathfinding.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 8 of 20). Used by req_offscreen_simulation and req_call_mechanic's heading-back phase.

## EXPECTATION
Every exploration branch in a shipped level has its own authored route back to the loop.

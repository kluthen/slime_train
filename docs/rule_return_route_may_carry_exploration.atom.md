---
id: rule_return_route_may_carry_exploration
status: DRAFT
layer: BUSINESS
tags: [level-rule]
version: 1.0
priority: 2
human_name: Level rule 14: a return route may carry exploration
parents:
  - [[req_level_design_rules]]
dependents: []
type: RULE
---

# Level rule 14: a return route may carry exploration

## INTENT
Allow a return route to carry exploration opportunities, while forbidding a later gate from making them unreachable.

## THE RULE / LOGIC
A return route may carry exploration opportunities, but opening a later frontier gate must never make them unreachable. Even after a return route stops being used for the main flow (its section's gate is open), any exploration branch it carries must stay reachable.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 14 of 20). Constrains req_loop_and_world's gate-opening behaviour.

## EXPECTATION
After every gate in a level opens, every exploration branch that was ever reachable from a return route remains reachable.

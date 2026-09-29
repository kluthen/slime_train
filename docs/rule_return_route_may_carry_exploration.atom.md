---
id: rule_return_route_may_carry_exploration
status: DRAFT
layer: BUSINESS
tags: [level-rule]
version: 1.1
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
A return route may carry exploration opportunities, but opening a later frontier gate must never make them unreachable. Once a return route stops carrying the flow (its section's gate is open), every exploration opportunity it carries stays reachable. A gate may shut the old return route's entrance with a lid; the level then provides another way to reach that route's exploration opportunities.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 14). Constrains req_loop_and_world's gate-opening behaviour, including the gate's optional lid over the old return route's entrance.

## EXPECTATION
After every gate in a level opens, every exploration opportunity that was ever reachable from a return route remains reachable, by another way wherever a gate's lid has shut that route's entrance.

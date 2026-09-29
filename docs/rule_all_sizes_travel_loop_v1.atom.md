---
id: rule_all_sizes_travel_loop_v1
status: REVIEW
type: RULE
layer: BUSINESS
human_name: Level rule 2: any size can travel the loop in v1
tags: [level-rule]
parents:
  - [[req_level_design_rules]]
dependents: []
version: 1.0
priority: 3
---

# Level rule 2: any size can travel the loop in v1

## INTENT
Require that in v1, a slime of any size can travel the whole loop the same way.

## THE RULE / LOGIC
A slime of any size can travel the loop. In v1 there are no filters, so every size takes the same way through every fork. Size-based forks (a size filter sending different sizes down different branches) are explicitly deferred to a later version and are not part of this rule.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 2 of 20). Consistent with req_switch_basket_gate_set's 'no filters in v1' statement.

## EXPECTATION
No level component in v1 blocks or redirects a slime based on its size.

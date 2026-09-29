---
id: rule_return_route_joins_start_behind_train
status: DRAFT
parents:
  - [[req_level_design_rules]]
version: 1.0
dependents: []
type: RULE
layer: BUSINESS
human_name: Level rule 22 (first half): a return route joins the start behind the train
priority: 4
tags: [level-rule]
---

# Level rule 22 (first half): a return route joins the start behind the train

## INTENT
Make slimes coming home by a return route join the train from behind, never meet it head on.

## THE RULE / LOGIC
A return route delivers slimes into the start behind the loop's start, travelling the loop's way, never along the loop's first stretch against the flow: slimes coming home join behind the train rather than meeting it head on. This holds whatever the return route is made of (a slide, wind, a conveyor...), which is decided per level.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 22, first half; rule_no_called_ledge_over_loop is the second). Constrains every return route described by rule_return_route_per_section and req_loop_and_world.

## EXPECTATION
In every level, each return route ends in the start behind the loop's start and moves the loop's way; no return route runs along the loop's first stretch against the flow.

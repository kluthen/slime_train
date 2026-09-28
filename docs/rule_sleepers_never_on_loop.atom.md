---
id: rule_sleepers_never_on_loop
status: DRAFT
layer: BUSINESS
priority: 3
tags: [level-rule]
parents:
  - [[req_level_design_rules]]
dependents: []
type: RULE
human_name: Level rule 17: sleepers never sit on the loop
version: 1.0
---

# Level rule 17: sleepers never sit on the loop

## INTENT
Require that every sleeper is placed off the loop.

## THE RULE / LOGIC
Sleepers never sit on the loop (see req_slime_states). Level design must place every sleeper somewhere off the loop's route.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 17 of 20).

## EXPECTATION
No sleeper is ever placed on the loop's drawn route in a shipped level.

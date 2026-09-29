---
id: rule_loop_travelable_with_no_input
status: REVIEW
priority: 5
tags: [level-rule]
parents:
  - [[req_level_design_rules]]
version: 1.0
type: RULE
layer: BUSINESS
human_name: Level rule 1: loop travelable with no input
dependents: []
---

# Level rule 1: loop travelable with no input

## INTENT
Require that the loop can be travelled with no input at all.

## THE RULE / LOGIC
Every level's loop must be fully travelable by the train with zero player input, at all times, forever (the watching-is-playing design stance applies structurally, not just as a preference).

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 1 of 20).

## EXPECTATION
From a fresh save, with no input at all, the train keeps travelling the whole current loop for a full session (definition of done item 1).

---
id: rule_gate_opens_via_switch_basket_set
status: DRAFT
layer: BUSINESS
tags: [level-rule]
version: 1.0
type: RULE
priority: 4
human_name: Level rule 12: a frontier gate opens via the switch-plus-basket set
parents:
  - [[req_level_design_rules]]
dependents: []
---

# Level rule 12: a frontier gate opens via the switch-plus-basket set

## INTENT
Require that every frontier gate in a level is opened only through the switch-plus-basket pattern.

## THE RULE / LOGIC
A frontier gate opens through the switch-plus-basket set; in v1 this is the only pattern used (see req_switch_basket_gate_set). Other frontier-gate patterns are explicitly deferred to a later version.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 12 of 20).

## EXPECTATION
Every gate in a shipped v1 level is paired with exactly one switch and one basket, and no other gate-opening mechanism exists.

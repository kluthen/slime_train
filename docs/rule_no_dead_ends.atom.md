---
id: rule_no_dead_ends
status: DRAFT
type: RULE
layer: BUSINESS
priority: 5
human_name: Level rule 3: no dead ends
tags: [level-rule]
parents:
  - [[req_level_design_rules]]
dependents: []
version: 1.0
---

# Level rule 3: no dead ends

## INTENT
Require that every branch of the loop joins the loop again.

## THE RULE / LOGIC
No dead ends: every branch joins the loop again. A slime on any branch of the loop is still part of the train.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 3 of 20).

## EXPECTATION
No level ships a branch of the loop that fails to rejoin it.

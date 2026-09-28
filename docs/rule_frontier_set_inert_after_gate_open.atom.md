---
id: rule_frontier_set_inert_after_gate_open
status: DRAFT
tags: [level-rule]
dependents: []
type: RULE
priority: 3
parents:
  - [[req_level_design_rules]]
version: 1.0
layer: BUSINESS
human_name: Level rule 15: a frontier set is inert once its gate is open
---

# Level rule 15: a frontier set is inert once its gate is open

## INTENT
Require that a frontier switch and basket stop responding once their gate has opened.

## THE RULE / LOGIC
Once its gate is open, a frontier set (switch and basket) is inert for good; it may be removed from the level or turned into a landscape feature. This applies permanently, for the life of the save (see rule_saves_never_wiped).

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 15 of 20). Restates part of req_switch_basket_gate_set at the level-design-rule level.

## EXPECTATION
Once a gate is open, tapping its switch does nothing, and its basket takes no more slimes (definition of done item 13).

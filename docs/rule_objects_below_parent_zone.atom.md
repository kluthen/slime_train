---
id: rule_objects_below_parent_zone
status: DRAFT
parents:
  - [[req_level_design_rules]]
priority: 3
version: 1.0
dependents: []
type: RULE
layer: BUSINESS
human_name: Level rule 21: interactive objects below the parent zone
tags: [level-rule]
---

# Level rule 21: interactive objects below the parent zone

## INTENT
Keep every interactive object tappable, out from under the parent zone, which takes any tap on it first.

## THE RULE / LOGIC
At the rails' framing, every interactive object sits fully below the parent zone (the 7 mm band along the top of the screen). This holds for every level, the test level included.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 21). Follows from req_controls_tap_zones, where the parent zone is checked before any object, and from req_interactive_objects_general's hit areas.

## EXPECTATION
A level-rules check finds every interactive object fully below the parent zone at the rails' framing across the whole level, and fails a level where an object sits under the band.

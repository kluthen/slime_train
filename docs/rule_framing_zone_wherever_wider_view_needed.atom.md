---
id: rule_framing_zone_wherever_wider_view_needed
status: DRAFT
priority: 2
version: 1.0
human_name: Level rule 19: a framing zone wherever a wider view is needed
tags: [level-rule,camera]
parents:
  - [[req_level_design_rules]]
dependents: []
type: RULE
layer: BUSINESS
---

# Level rule 19: a framing zone wherever a wider view is needed

## INTENT
Require that any place in a level needing a wider camera view is covered by a framing zone.

## THE RULE / LOGIC
Wherever a wider view is needed, a framing zone sets the zoom and position (see req_camera_rails_and_framing).

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 19 of 20).

## EXPECTATION
No part of a shipped level needs a wider view than its default zoom without a framing zone covering it.

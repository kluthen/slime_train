---
id: rule_return_route_per_section
status: DRAFT
layer: BUSINESS
priority: 4
dependents: []
type: RULE
human_name: Level rule 13: each section has its own return route
tags: [level-rule]
parents:
  - [[req_level_design_rules]]
version: 1.0
---

# Level rule 13: each section has its own return route

## INTENT
Require that each section provides its own return route to the start from its unopened frontier gate.

## THE RULE / LOGIC
Each section has its own return route to the start from its unopened frontier gate. It is part of the loop and has its own camera rail (see req_loop_and_world and req_camera_rails_and_framing). What the return route is physically made of (a slide, wind, a conveyor) is decided per level and is not settled by this spec (see Known gaps).

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 13 of 20).

## EXPECTATION
Every section in a shipped level has exactly one return route from its own unopened frontier gate back to the start, with its own camera rail.

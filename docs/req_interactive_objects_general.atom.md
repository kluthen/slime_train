---
id: req_interactive_objects_general
status: DRAFT
type: REQUIREMENT
layer: BUSINESS
priority: 3
human_name: Interactive objects
parents:
  - [[req_loop_and_world]]
dependents:
  - [[req_switch_basket_gate_set]]
tags: [objects]
version: 1.0
---

# Interactive objects

## INTENT
Define the rules shared by every interactive object, before their individual behaviours.

## THE RULE / LOGIC
Every interactive object is a reusable component configured in the Godot editor, and its state is saved. A tap on an object operates it; a tap anywhere else is a call (see req_controls_tap_zones for the full tap-zone order). Hit areas are larger than the drawn object, to suit small fingers. A signpost stands at every fork of the loop and shows which way the loop goes, but is not itself interactive.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Governs req_switch_basket_gate_set.

## EXPECTATION
Every tap on an interactive object operates it rather than issuing a call; every signpost is present at its fork and shows the loop's direction without responding to taps.

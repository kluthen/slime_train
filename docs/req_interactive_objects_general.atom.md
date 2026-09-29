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
version: 1.1
---

# Interactive objects

## INTENT
Define the rules shared by every interactive object, before their individual behaviours.

## THE RULE / LOGIC
Every interactive object is a reusable component configured in the Godot editor, and its state is saved. A tap on an object that answers taps right now operates it; a tap anywhere else is a call (see req_controls_tap_zones for the full tap-zone order). Only something that answers a tap takes it: a tap on a basket, a gate, a signpost, or a switch that isn't answering (its basket full, or inert for good once its gate is open) is a call. An object's hit area is its drawing grown by 5 mm on every side, and never smaller than 20 x 20 mm, both measured on the screen at the current zoom: zooming out shrinks the drawing, never the hit area's floor. Where two hit areas overlap, the object whose centre is nearest the tap takes it. A signpost stands at every fork of the loop and shows which way the loop goes, but is not itself interactive.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Governs req_switch_basket_gate_set.

## EXPECTATION
A tap within an object's hit area (its drawing plus 5 mm, at least 20 x 20 mm on the screen at any zoom) operates it when it answers taps, and calls otherwise (definition of done item 18). A tap on a basket, a gate, a signpost, or a switch whose basket is full or whose gate is open is a call; where hit areas overlap, the object with the nearest centre takes the tap. Every signpost is present at its fork and shows the loop's direction without taking taps.

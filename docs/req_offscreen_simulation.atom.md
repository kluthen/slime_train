---
id: req_offscreen_simulation
status: DRAFT
human_name: Off-screen simulation
tags: [performance,offscreen]
parents:
  - [[req_loop_and_world]]
dependents: []
version: 1.0
type: REQUIREMENT
layer: BUSINESS
priority: 4
---

# Off-screen simulation

## INTENT
Define how slimes and objects behave once off screen, since physics only runs near the screen.

## THE RULE / LOGIC
Physics runs only for slimes on or near the screen. Off screen, a train slime is a position along the loop moving at a deterministic pace; when the view comes near it, it is spawned just outside the view and physics takes over. A free slime that leaves the screen is placed on the nearest point of its area's route back and follows it at the same deterministic pace; if no route back is near, it is lost. Fusion and waking happen only on screen. Baskets keep counting weight off screen and can fill there. Sleepers don't simulate until something touches them, slimes in a full basket use a simplified state, and slimes on screen may use fewer points when zoomed out.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Interacts with rule_left_alone_and_lost and req_switch_basket_gate_set (off-screen basket filling).

## EXPECTATION
A basket filled while off screen plays its reward and opens the gate when it comes into view (definition of done item 10).

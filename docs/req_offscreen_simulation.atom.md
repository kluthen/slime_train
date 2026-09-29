---
id: req_offscreen_simulation
status: REVIEW
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
Physics runs only for slimes on or near the screen. Off screen, a train slime is a position along the loop moving at a deterministic pace; when the view comes near it, it is spawned just outside the view and physics takes over. A free slime that leaves the screen is placed on the nearest point of its area's route back and follows it at the same deterministic pace; if no route back is near, it is lost. Fusion and waking happen only on screen. Baskets keep counting weight off screen and can fill there. Sleepers don't simulate until something touches them, slimes in a full basket use a simplified state, and slimes on screen may use fewer points when zoomed out. A resting pile of slimes — including a full basket's slimes, but not only them — stops being simulated, contact solving included, until something disturbs it; this is the first and cheapest of the fallbacks that keep the simulation within budget, since most of a big crowd on screen at once is expected to be a still pile rather than 200 slimes all moving.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Interacts with rule_left_alone_and_lost and req_switch_basket_gate_set (off-screen basket filling). The resting-pile clause is restated from the technical direction's fallback list, not yet from the master spec's own off-screen section, which currently only states the sleeper and full-basket cases; flagged for spec-writer to fold the resting-pile clause into the master spec's own text.

## EXPECTATION
A basket filled while off screen plays its reward and opens the gate when it comes into view (definition of done item 10).

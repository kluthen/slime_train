---
id: req_offscreen_simulation
status: DRAFT
human_name: Off-screen simulation
tags: [performance,offscreen]
parents:
  - [[req_loop_and_world]]
dependents: []
version: 1.2
type: REQUIREMENT
layer: BUSINESS
priority: 4
---

# Off-screen simulation

## INTENT
Define how slimes and objects behave once off screen, since physics only runs near the screen.

## THE RULE / LOGIC
Physics runs only for slimes on or near the screen. Off screen, a train slime is a position along the loop moving at a deterministic pace; when the view comes near it, it is spawned just outside the view and physics takes over. A free slime that leaves the screen is placed on the nearest point of its area's route back and follows it at the same deterministic pace. If no route back is near, it is lost: it heads straight for the loop when the loop is near; otherwise it stays where it is until the lost timer (10 s, then 1 min) moves it to the start of the loop. Fusion and waking happen only on screen. Baskets keep counting weight off screen and can fill there. On screen too, a resting pile of slimes stops simulating, contacts included, until something disturbs it; this is the first fallback for performance, since most of a big crowd on screen is expected to be a still pile. A pile rests once every slime in it has stayed within about a pixel of where it started counting; a big pile of base slimes in the open may take about a minute to rest. Sleepers don't simulate until something touches them, slimes in a full basket use a simplified state, and slimes on screen may use fewer points when zoomed out.

## TECHNICAL INTERFACE
Parented to req_loop_and_world. Interacts with rule_left_alone_and_lost (the lost timer) and req_switch_basket_gate_set (off-screen basket filling).

Pending the user's sign-off (proposed, not settled; the rule above is what is settled): the build also gives slimes fewer ring points when many slimes are active, not only when zoomed out. The crowd count is the ACTIVE slimes that are not sleepers on a tick; resting and parked slimes don't count, and the count comes from the simulation's state only, never from the frame rate, so runs repeat. Detail levels 0 to 3 give 12, 10, 8, 6 points to a size-1 slime (15, 12, 10, 8 at size 2; 18, 15, 12, 9 at size 3). The level rises at 20, 30 and 40 active slimes and falls only at 15, 25 and 35, so rings never reshape back and forth. The level used is the higher of the crowd's and the zoom's; zoomed out gives at least level 2. Only ACTIVE rings are reshaped, so a reshape never wakes a resting pile, and a slime waking or unparking takes the current level on that tick. Pile slimes (in a basket, or asleep at bedtime) stop at level 2. Implemented in src/sim/offscreen.gd and src/sim/slime_bodies.gd; saved as described in req_persistence_and_saves.

## EXPECTATION
A basket filled while off screen plays its reward and opens the gate when it comes into view (definition of done item 10). A pile stops simulating only once each of its slimes has stayed within about a pixel of where it started counting, and simulates again when something disturbs it.

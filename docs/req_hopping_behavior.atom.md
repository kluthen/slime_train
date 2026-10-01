---
id: req_hopping_behavior
status: DRAFT
parents:
  - [[req_slime_states]]
dependents: []
version: 1.2
human_name: Hopping behaviour
tags: [slimes,movement]
type: REQUIREMENT
layer: BUSINESS
priority: 3
---

# Hopping behaviour

## INTENT
Define how each slime state moves, since slimes move only by hopping.

## THE RULE / LOGIC
Slimes move only by hopping, never sliding or walking. A train slime hops forward along the loop every roughly 1.5-3 s, with a little random timing per slime so the train bounces unevenly. A slime answering a call hops toward the call point a bit more often than a train slime, jumping upward when the point is higher, and bigger slimes jump higher. An unsure slime takes small, lazy hops in random directions near the call point. A slime heading back hops along its area's route back. A sleeper, a bedtime-asleep slime, a slime covered by others, and a slime in a basket (any basket, filling or full) do not hop. Bigger slimes hop a little less often, but further and higher than smaller ones. In the last minute of a session (the wind-down), every slime hops more slowly.

## TECHNICAL INTERFACE
Parented to req_slime_states.

Pending the user's sign-off (built in chunk 22e, proposed, not settled; the rule above is what is settled): when its hop is due, a train slime standing on something holds instead of hopping while more than 30 slimes that cost physics (neither resting, parked, sleepers nor in a basket) have their centre within 240 px of its hop's landing point and ahead of it, or while its hop would come within the two slimes' radii plus 24 px of a holding train slime ahead of it (a jam), so a slime arriving behind a queue stops short of it. A holder checks again every 0.5 s (30 ticks) without a random draw, and hops anyway after 5 s (300 ticks). A holder stays a train slime; its hold also ends when it is parked, leaves the train, is moved to the loop's start or reaches a slide. Implemented in src/sim/train.gd (HOLD_CROWD, HOLD_CROWD_RADIUS, JAM_GAP, HOLD_RECHECK_TICKS, HOLD_CAP_TICKS), the crowd count in SlimeBodies.awake_count_ahead; the hold is saved as described in req_persistence_and_saves, and a holder may rest as described in req_offscreen_simulation. Chunk 22e's measure: the hold did not lower the share of short hops (the crowd check counts the train's own queue and rarely fires; the jam check starts most holds and spreads them backwards; most holds end at the 5 s cap), so a second round, also proposed, reworks it.

## EXPECTATION
Observed hop timing and height for each state matches the rule above; slimes in a basket (filling or full), sleepers, and bedtime-asleep slimes never hop.

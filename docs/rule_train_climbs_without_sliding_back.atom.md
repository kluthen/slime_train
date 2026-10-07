---
id: rule_train_climbs_without_sliding_back
status: REVIEW
version: 1.1
priority: 3
tags: [slimes,movement,train,climb]
parents:
  - [[req_hopping_behavior]]
type: RULE
layer: BUSINESS
human_name: The hold on a climb: a standing train slime doesn't slide back
dependents: []
---

# The hold on a climb: a standing train slime doesn't slide back

## INTENT
Keep the train from losing on a climb, between hops, the ground its hops gained.

## THE RULE / LOGIC
A train slime standing between hops on a rise of the outgoing route keeps its place instead of sliding back down the slope. A slime on a return route's slide is carried as before, and a slime knocked off the route is not held.

## TECHNICAL INTERFACE
Parented to req_hopping_behavior (slimes move only by hopping, never sliding). Implemented in Train.steer (src/sim/train.gd) with SlimeBodies.hold_on_slope (src/sim/slime_bodies.gd): a supported, active train slime whose next hop is more than one and a half ticks away, on the outgoing route at its own progress (not steering from a point behind), on a stretch rising more than HOLD_FROM (0.1, rise over run) and no steeper than GRIP_MAX_SLOPE, has its motion down the slope cancelled after the grip and is given HOLD_LIFT (0.5) of one tick's pull along the slope, up it. No new state, nothing saved; the same on both simulation ticks. Measured alone on a rise: about 1.6 px/s of slide left, against 12.9 px/s with the grip only.

Decided by the user (2026-10-07): this rule is kept in v1 as built in chunk 24g, the fix for the train's jam on climbs, with the built values.

## EXPECTATION
A base train slime standing between hops on an outgoing climb of 0.4 rise over run slides back less than 6 px in 2 s (with the grip alone, more than 18 px), and no motion down the climb is left after a held tick. It is not held on the tick its hop is due, in the air, once knocked off the route, or on a return route's slide up a climb, which still carries it up.

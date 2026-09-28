---
id: req_hopping_behavior
status: DRAFT
parents:
  - [[req_slime_states]]
dependents: []
version: 1.0
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
Slimes move only by hopping, never sliding or walking. A train slime hops forward along the loop every roughly 1.5-3 s, with a little random timing per slime so the train bounces unevenly. A slime answering a call hops toward the call point a bit more often than a train slime, jumping upward when the point is higher, and bigger slimes jump higher. An unsure slime takes small, lazy hops in random directions near the call point. A slime heading back hops along its area's route back. A sleeper, a bedtime-asleep slime, a slime covered by others, and a slime resting in a full basket do not hop. Bigger slimes hop a little less often, but further and higher than smaller ones. In the last minute of a session (the wind-down), every slime hops more slowly.

## TECHNICAL INTERFACE
Parented to req_slime_states.

## EXPECTATION
Observed hop timing and height for each state matches the table above; slimes in a full basket, sleepers, and bedtime-asleep slimes never hop.

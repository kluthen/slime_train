---
id: req_hopping_behavior
status: DRAFT
parents:
  - [[req_slime_states]]
dependents:
  - [[rule_train_climbs_without_sliding_back]]
  - [[rule_train_relay_on_take_off]]
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
Slimes move only by hopping, never sliding or walking. A train slime hops forward along the loop every roughly 1.5-3 s, with a little random timing per slime so the train bounces unevenly. A slime a basket releases hops away at once instead of waiting out its own hop timer. A slime answering a call hops toward the call point a bit more often than a train slime, jumping upward when the point is higher, and bigger slimes jump higher. An unsure slime takes small, lazy hops in random directions near the call point. A slime heading back hops along its area's route back. A sleeper, a bedtime-asleep slime, a slime covered by others, and a slime in a basket (any basket, filling or full) do not hop. Bigger slimes hop a little less often, but further and higher than smaller ones. In the last minute of a session (the wind-down), every slime hops more slowly.

## TECHNICAL INTERFACE
Parented to req_slime_states. A train slime's hopping is refined by rule_train_climbs_without_sliding_back (the hold on a climb) and rule_train_relay_on_take_off (the relay), both kept in v1 by the user (2026-10-07). A train slime doesn't delay its hop because slimes it can't fuse with crowd its landing spot: that lean was tried and withdrawn from v1 by the user (2026-10-07). Where a basket releases its slimes is req_switch_basket_gate_set's.
Built, the release hop: FrontierSets._release (src/sim/frontier_sets.gd) runs out a released slime's hop timer, so it hops on the tick after it lands at the outlet (3 ticks after its release at basket 2). Guarded by tests/e2e/test_basket_drain_e2e.gd.

## EXPECTATION
Observed hop timing and height for each state matches the rule above; slimes in a basket (filling or full), sleepers, and bedtime-asleep slimes never hop.

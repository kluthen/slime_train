---
id: rule_geyser_spreads_arrivals_at_loop_start
status: DRAFT
priority: 4
human_name: The geyser: a level object that launches arrivals onto free spots
type: RULE
version: 2.0
tags: [objects,geyser,not-built,after-v1]
parents:
  - [[req_loop_and_world]]
dependents: []
layer: BUSINESS
---

# The geyser: a level object that launches arrivals onto free spots

## INTENT
Keep a flow of train slimes arriving at one spot of the loop, such as the loop's start where the return routes end, from landing on the pile there.

## THE RULE / LOGIC
A geyser is a reusable object a level places on the loop, configured in the editor like any other component: a train slime travelling the loop's way into it is lifted straight up above the slimes piled over it and launched high, so it comes down on the emptiest of a few seeded free spots along a stretch of the loop ahead of it instead of on the pile.

## TECHNICAL INTERFACE
Parented to req_loop_and_world (what a level does with a flow it brings back onto the loop). It sits with rule_arrivals_clear_faster_than_they_arrive (a geyser gives the arrivals room, not pace) and rule_return_route_joins_start_behind_train. Scheduled after v1 (the user's decision, 2026-10-07): built once v1 is finished, with v2's level work; v1's objects don't include it and no v1 level places one, the test level included. Not built on main: tried on the throwaway branch exp/geyser, as part of the loop's start rather than as an object; no code tag until it lands on main. Where a level may place one is level rule 25 (proposed, after v1; see req_level_design_rules).

Pending the user's sign-off (proposed, not settled; the rule and expectation are what is settled until then):
Catch and properties. Each placement sets its catch (a box: a train slime travelling the loop's way whose centre enters it is launched), its landing span (from and to, in px along the loop, ahead of the catch), its apex and its jitter, its draws per arrival, its lift's cap, and one switch: fused slimes land only inside a split zone (on for a placement at the loop's start, so fused arrivals still split there; off elsewhere). A slime put inside the catch rather than travelling into it (a move to the loop start, a load) is never launched. It takes no tap (a tap on it is a call) and has no state of its own.
Landing limits, whatever the placement. Only on the loop's own route, on a free spot (no ring there, slimes in flight counted where they come down), so never on top of the waiting queue; never onto or under a ledge guarded by rule_no_called_ledge_over_loop, nor anywhere else off the loop; never at or past a gate; a spot whose flight would hit the terrain isn't used. With no usable spot the slime isn't lifted or launched and carries on as it would without the geyser.
Off screen. A parked slime reaching the catch isn't flown: it is placed directly on a free spot of the span; with none free it stays in the parked single file.
Determinism. Its draws come from their own derived random stream per tick and slime; the state hash is the same on both simulation ticks; nothing new is saved (a slime in flight is ordinary physics).
Defaults, tuned in the build: a lift of at most 240 px, ending 6 px clear of the pile; an apex about 260 px above the higher of the launch point and the landing, plus or minus 25 %, seeded; 10 landing draws per arrival. The test level, once the geyser is built, places one with its catch over the return routes' end (the pocket behind the loop's start) and its span 150 to 700 px along the loop, fused slimes landing only inside the split zone.
By eye: the idle camera may follow a launched slime away from the catch; seen, not changed.

## EXPECTATION
Once built (after v1), in test mode on a level that places a geyser where a flow arrives, each train slime travelling into its catch is launched and comes down on a free spot along its span, not on the slimes piled there; with the geyser placed, far fewer slimes crowd within 240 px of that spot, and it clears faster, than without it on the same run. No v1 level places a geyser.

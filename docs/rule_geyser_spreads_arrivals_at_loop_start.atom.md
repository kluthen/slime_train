---
id: rule_geyser_spreads_arrivals_at_loop_start
status: DRAFT
priority: 4
human_name: The geyser: arrivals at the loop's start are launched onto free spots
type: RULE
version: 1.0
tags: [loop,loop-start,geyser,not-built]
parents:
  - [[req_loop_and_world]]
dependents: []
layer: BUSINESS
---

# The geyser: arrivals at the loop's start are launched onto free spots

## INTENT
Keep train slimes coming home by a return route from landing on the pile at the loop's start.

## THE RULE / LOGIC
At the loop's start, a train slime coming home by a return route is lifted straight up above the slimes piled over it and launched high, so it comes down on the emptiest of a few seeded free spots spread along the loop's first stretch instead of on the pile. In v1 this geyser is part of the loop's start in every level, not an object a level places or tunes.

## TECHNICAL INTERFACE
Parented to req_loop_and_world (what the loop's start does with the flow a return route sends back). It sits with rule_arrivals_clear_faster_than_they_arrive (the geyser gives the arrivals room, not pace) and rule_return_route_joins_start_behind_train. The user's decision (2026-10-06): the geyser is in v1, in its "high and wide" form, with its landing limits fixed, built together with the dip-nudge change (rule_dip_may_nudge_fusion). Not built on main yet: tried on the throwaway branch exp/geyser; no code tag until it lands on main.

Pending the user's sign-off (proposed, not settled; the rule and expectation above are what is settled until then):
When. Only a train slime coming home by a return route is launched. A move to the loop start (a lost, stuck or stalled slime) is never launched: it already lands on a free spot. With no usable spot the slime isn't launched and carries on as it would without the geyser.
Landing limits. Only on the loop's own route, on a free spot (no ring there, slimes in flight counted where they come down), so never on top of the waiting queue; never onto a ledge guarded by rule_no_called_ledge_over_loop, nor anywhere else off the loop; never at or past a gate; a fused slime lands only inside a split zone, while a base slime may land past the start's split zone, since it has nothing to split. A spot whose flight would hit the terrain isn't used.
Off screen. A parked arrival isn't flown: it is placed directly on a free drawn spot; with none free it stays in the parked single file.
Determinism. Its draws come from their own derived random stream per tick and slime; the state hash is the same on both simulation ticks; nothing new is saved (a slime in flight is ordinary physics).
Numbers, tuned in the build: a lift of at most 240 px, ending 6 px clear of the pile; an apex about 260 px above the higher of the launch point and the landing, plus or minus 25 %, seeded; 10 landing draws, uniform on 150 to 700 px along the loop.
By eye: the idle camera may follow a launched slime away from the start; seen, not changed.

## EXPECTATION
In test mode, with a return route bringing slimes home to the loop's start, each arriving train slime is launched and comes down on a free spot along the loop's first stretch, not on the slimes piled at the start; with the geyser on, far fewer slimes crowd within 240 px of the loop's start, and the start clears faster, than with it off on the same run.

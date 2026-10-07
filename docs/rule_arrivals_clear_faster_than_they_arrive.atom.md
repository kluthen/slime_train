---
id: rule_arrivals_clear_faster_than_they_arrive
status: DRAFT
priority: 4
tags: [level-rule]
dependents: []
type: RULE
version: 1.2
human_name: Level rule 24: where slimes arrive fast
parents:
  - [[req_level_design_rules]]
layer: BUSINESS
---

# Level rule 24: where slimes arrive fast

## INTENT
Keep every spot where a flow lands slimes from turning into a pile that feeds itself.

## THE RULE / LOGIC
Where slimes arrive fast (the end of a return route at the loop's start, a slide's end, a basket's outlet), the place where they land lets them move away faster than they arrive: it gives them enough room and a clear way onward to move off before the next ones land. Otherwise each arrival lands on the ones before it, and the pile feeds itself. At the loop's start, where slimes leave only by joining the train, the arrivals never outpace what the train takes off it.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 24). It is the flow-made case of the concern about spots where many slimes gather awake (level rule 23, rule_no_spot_where_slimes_gather_awake): a gathering spot that arrivals outpacing departures create, wherever the layout puts it. It sits with rule_return_route_joins_start_behind_train (where a return route comes home; that place must also clear fast enough), rule_start_carries_split_zone and rule_geyser_spreads_arrivals_at_loop_start (a geyser, a level object scheduled after v1, spreads the arrivals over a stretch of the loop: it gives them room, not pace, so it doesn't by itself satisfy this rule).

Pending the user's sign-off (the rule's direction is the user's, 2026-10-03, and its strengthening at the loop's start is the user's ask, 2026-10-06; its wording, reading and checks are proposed, not settled):
Reading. Where a split zone meets the arrivals, count them in base slimes: a size 3 coming home lands as three. The way onward counts by its pace, not only its room: at the loop's start slimes leave by joining the train at its hop pace, so a return route that brings them faster than the train carries them off fills the start however wide it is; the rule is a rate, arrivals against departures, not a size alone. The rule is about the level's own arrivals (a return route, a slide, an outlet); the safety nets' moves to the loop start (lost, stuck and stalled slimes) are paced one at a time by the loop-start queue and land on free spots, and are not what it governs.
Checks. Over the level's own scripted runs (the stress fixtures excepted), from the first arrival on: the mean arrivals per 600 ticks at the loop's start stay at or below the mean departures per 600 ticks past the end of its first stretch (past a geyser's farthest landing where one is placed; 750 px along the loop on the test level); the largest awake cluster with a slime within 240 px of the loop's start stays within the limit set for gathering spots (itself proposed: at most 20 slimes, or above that for at most 5 s in a row); and over a 10,000-tick tools/thru.gd run no slime is stuck again within 600 ticks (10 s) of landing there. Built: the level run tool tools/train_flow_probe.gd counts, per 600 ticks, the arrivals at the loop's start, the departures past 240 and 750 px, and the largest awake cluster with a slime within 240 px of the start (the camera held on the start with --hold-view); a geyser's launches and landings are added once the geyser is built. Still open, settled after v1: the rate window and the threshold. By eye in test mode: each arrival spot clears while slimes keep coming, and no pile there grows (an item in each level's rules checklist). The level-rules checker reads only the scene, so it lists this rule as a run check and a by-eye item, with no automatic check.
When it fails, the designer gives the first stretch more room (longer, or wider so waiting slimes sit apart), makes the train faster off it (a gentler first slope), places a geyser once it is built (after v1) to spread the arrivals over the room there is, or paces the return route's end (an idea still open, not built).
Known state: the test level fails the rate check. Measured after the train's climb fix (rule_train_climbs_without_sliding_back, rule_train_relay_on_take_off), on s3-basket-59of60 with the camera held on the start, seeds 1 and 2, per 600 ticks from tick 9000: about 18 arrivals (18.5 / 17.8) against about 7.5 departures past 750 px (7.6 / 7.4; 2.5 / 3.1 before the fix), the largest awake cluster near the start at most 95 / 89. This is a known gap of the test level, not a v1 blocker (the user's decision); the test level's start is reviewed after v1, with the geyser.

## EXPECTATION
In every level, at each spot where a flow lands slimes, the slimes keep moving off while arrivals go on, and no pile there grows; at the loop's start, slimes leave its first stretch at least as fast as they arrive there.

---
id: rule_arrivals_clear_faster_than_they_arrive
status: DRAFT
priority: 4
tags: [level-rule]
dependents: []
type: RULE
version: 1.1
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
Parented to req_level_design_rules (level rule 24). It is the flow-made case of the concern about spots where many slimes gather awake (level rule 23, which has no atom yet): a gathering spot that arrivals outpacing departures create, wherever the layout puts it. It sits with rule_return_route_joins_start_behind_train (where a return route comes home; that place must also clear fast enough), rule_start_carries_split_zone and rule_geyser_spreads_arrivals_at_loop_start (the geyser spreads the arrivals over the loop's first stretch: it gives them room, not pace, so it doesn't by itself satisfy this rule).

Pending the user's sign-off (the rule's direction is the user's, 2026-10-03, and its strengthening at the loop's start is the user's ask, 2026-10-06; its wording, reading and checks are proposed, not settled):
Reading. Where a split zone meets the arrivals, count them in base slimes: a size 3 coming home lands as three. The way onward counts by its pace, not only its room: at the loop's start slimes leave by joining the train at its hop pace, so a return route that brings them faster than the train carries them off fills the start however wide it is; the rule is a rate, arrivals against departures, not a size alone. The rule is about the level's own arrivals (a return route, a slide, an outlet); the safety nets' moves to the loop start (lost, stuck and stalled slimes) are paced one at a time by the loop-start queue and land on free spots, and are not what it governs.
Checks. Over the level's own scripted runs (the stress fixtures excepted), from the first arrival on: the mean arrivals per 600 ticks at the loop's start stay at or below the mean departures per 600 ticks past the end of its first stretch (past the geyser's farthest landing; 750 px along the loop on the test level); the largest awake cluster with a slime within 240 px of the loop's start stays within the limit set for gathering spots (itself proposed: at most 20 slimes, or above that for at most 5 s in a row); and over a 10,000-tick tools/thru.gd run no slime is stuck again within 600 ticks (10 s) of landing there. A level run tool counts the rates and the cluster (planned with the geyser, not built on main); the rate window and the threshold are still open. By eye in test mode: each arrival spot clears while slimes keep coming, and no pile there grows (an item in each level's rules checklist). The level-rules checker reads only the scene, so it lists this rule as a run check and a by-eye item, with no automatic check.
When it fails, the designer gives the first stretch more room (longer, or wider so waiting slimes sit apart), makes the train faster off it (a gentler first slope), or paces the return route's end (an idea still open, not built).
Known state: the test level fails the rate check today (about 15 to 18 arrivals per 600 ticks once its third basket fires, against 2 to 3 departures past 750 px, with or without the geyser); it is measured again once the geyser and the dip-nudge change (rule_dip_may_nudge_fusion) are built.

## EXPECTATION
In every level, at each spot where a flow lands slimes, the slimes keep moving off while arrivals go on, and no pile there grows; at the loop's start, slimes leave its first stretch at least as fast as they arrive there.

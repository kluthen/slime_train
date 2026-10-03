---
id: rule_arrivals_clear_faster_than_they_arrive
status: DRAFT
priority: 4
tags: [level-rule]
dependents: []
type: RULE
version: 1.0
human_name: Level rule 24: where slimes arrive fast, they get away faster than they arrive
parents:
  - [[req_level_design_rules]]
layer: BUSINESS
---

# Level rule 24: where slimes arrive fast, they get away faster than they arrive

## INTENT
Keep every spot where a flow lands slimes from turning into a pile that feeds itself.

## THE RULE / LOGIC
Where slimes arrive fast (the end of a return route at the loop's start, a slide's end, a basket's outlet), the place where they land lets them move away faster than they arrive: it gives them enough room and a clear way onward to move off before the next ones land. Otherwise each arrival lands on the ones before it, and the pile feeds itself.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 24). It is the flow-made case of the concern about spots where many slimes gather awake (level rule 23, which has no atom yet): a gathering spot that arrivals outpacing departures create, wherever the layout puts it. It sits with rule_return_route_joins_start_behind_train (where a return route comes home; that place must also clear fast enough) and rule_start_carries_split_zone.

Pending the user's sign-off (the rule's direction is the user's, 2026-10-03; its wording, reading and checks are proposed, not settled):
Reading. Where a split zone meets the arrivals, count them in base slimes: a size 3 coming home lands as three. The way onward counts by its pace, not only its room: at the loop's start slimes leave by joining the train at its hop pace, so a return route that brings them faster than the train carries them off fills the start however wide it is; a designer reads the rule as arrivals against departures, not as a size alone. The rule is about the level's own arrivals (a return route, a slide, an outlet), which nothing paces; the safety nets' moves to the loop start (lost, stuck and stalled slimes) are paced one at a time by the loop-start queue and land on free spots, and are not what it governs.
Checks. By eye in test mode: each arrival spot clears while slimes keep coming, and no pile there grows (an item in each level's rules checklist). Over the level's own scripted runs (its played test from fresh and each basket's fire-and-drain; the stress fixtures excepted), the largest awake cluster with a slime within 240 px of where slimes land stays within the limit set for gathering spots (itself proposed: at most 20 slimes, or above that for at most 5 s in a row). Over a 10,000-tick tools/thru.gd run, no slime is stuck again within 600 ticks (10 s) of landing there; thru.gd counts stuck moves level-wide today, and telling the arrival spot apart is a small tool addition, not scheduled. No automatic level-rules checker check in v1: the rule hangs on rates only a run shows, and the checker reads the scene.

## EXPECTATION
In every level, at each spot where a flow lands slimes, the slimes keep moving off while arrivals go on, and no pile there grows.

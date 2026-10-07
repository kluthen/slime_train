---
id: rule_no_spot_where_slimes_gather_awake
status: DRAFT
type: RULE
tags: [level-rule,performance]
parents:
  - [[req_level_design_rules]]
dependents: []
layer: BUSINESS
version: 1.1
priority: 4
human_name: Level rule 23: no spot where many slimes gather awake
---

# Level rule 23: no spot where many slimes gather awake

## INTENT
Keep every level from having a spot where many slimes gather awake, since an awake cluster keeps waking itself and costs physics every tick.

## THE RULE / LOGIC
A level keeps apart the places where slimes pile up: a bowl or dip next to a basket, an outlet releasing into a crowd, a narrow ledge where the train queues, and the landing spot of a sleeper shelf next to any of these. A pile that rests costs little; an awake cluster keeps waking itself and costs every tick. Whether a level keeps this rule is measured by the largest awake cluster over the level's own scripted runs, its played test and each basket's fire-and-drain. A basket's own fill doesn't count: slimes inside a basket's box, where its caught slimes rest, are left out of the measure, while a pile outside a basket still counts.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 23). The rule's direction is the user's (approved 2026-09-30): no spot where many slimes gather awake, measured by the largest awake cluster over a level's played test and each basket's fire-and-drain. Leaving a basket's own fill out of the measure is the user's (2026-10-07). rule_arrivals_clear_faster_than_they_arrive (level rule 24) is its flow-made case: a gathering spot that arrivals outpacing departures create.

Pending the user's sign-off (proposed, not settled; the direction and the basket-fill exclusion above are what is settled until then; the build does both the measure and the exclusion):
Measure. An awake cluster is a group of touching slimes that cost physics, counted in slimes. A slime is inside a basket's box when its centre is inside the box; the largest awake cluster is taken over the other slimes only, so two piles outside a basket aren't joined into one through the slimes in it. Over the level's own scripted runs (its played test from fresh, and each basket's fire-and-drain; the stress fixtures excepted), the largest awake cluster stays at or under 20 slimes, or goes above 20 for at most 5 s in a row; a run above 20 for more than 5 s in a row fails. A cluster the player builds with calls is accepted: crowd detail and the tick cap cover it. The limit is not yet calibrated.
Built: the measure is tools/level_check/cluster_watch.gd (ClusterWatch: the largest awake cluster sampled every 0.1 s, the seconds above the limit in all and the longest stretch in a row, and the verdict); the level bench (tools/bench_level.gd) prints those numbers per case with no verdict; a level's played test records them per section and per basket drain (the new-level template's test fails on them; the test level's records them with no verdict while the open questions below stand); the level-rules checker (tools/level_check/rules_placement.gd) lists rule 23 as MANUAL, pointing at the played test and the bench, naming the shapes to look for by eye, and saying a basket's own fill is left out. The exclusion is built: DebugCounts.largest_cluster (src/debug/debug_counts.gd) takes boxes to leave out, dropping every slime whose centre is inside one before clustering; ClusterWatch passes it the level's basket boxes (ClusterWatch.basket_boxes); the debug overlay and the performance log line still count every slime. Guarded by tests/unit/test_cluster_watch.gd (with the exclusion: a full basket above the limit passes, a pile outside the basket above it fails, a pile against a full basket counts only its own slimes, two piles don't join through a basket's slimes, and with no level the count is the overlay's), tests/e2e/test_level_checker.gd and tests/e2e/test_rule_23_e2e.gd (a synthetic level: a basket draining into a bowl where the train queues fails, the same basket a screen apart passes). Measured on the test level with the fill left out (2026-10-07): every section stays within the proposed limit; section 3's play peaks at 23 slimes for 0.1 s in a row, and its basket's drain at 5 (with the fill counted they were 59 slimes for 21.9 s and 55 for 11.3 s). On the level bench, section 3 with its basket at 59 of 60 reads 37 slimes, above the limit for 2.6 s in a row: the pile outside the basket, which still counts.
Open, for the user: (a) whether a dense train queue on the loop counts as a cluster (it reads as one long touching group: the stress-moving fixture's dense train reads as one cluster of 133), or the measure counts only groups off the loop, or piles by area. (b) Whether the test level's section 3 needs an edit (proposed: no edit, since it now passes under the proposed limit; to be measured again after the remaining crowding fixes and if the limit is recalibrated; a small edit is the user's call). The test level's rule 23 numbers carry no verdict until these are settled.

## EXPECTATION
In every level, over its played test and each basket's fire-and-drain, no awake cluster stays above the rule's limit for longer than the rule allows; the level-rules check reports where that result comes from.

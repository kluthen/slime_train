---
id: rule_no_spot_where_slimes_gather_awake
status: DRAFT
type: RULE
tags: [level-rule,performance]
parents:
  - [[req_level_design_rules]]
dependents: []
layer: BUSINESS
version: 1.0
priority: 4
human_name: Level rule 23: no spot where many slimes gather awake
---

# Level rule 23: no spot where many slimes gather awake

## INTENT
Keep every level from having a spot where many slimes gather awake, since an awake cluster keeps waking itself and costs physics every tick.

## THE RULE / LOGIC
A level keeps apart the places where slimes pile up: a bowl or dip next to a basket, an outlet releasing into a crowd, a narrow ledge where the train queues, and the landing spot of a sleeper shelf next to any of these. A pile that rests costs little; an awake cluster keeps waking itself and costs every tick. Whether a level keeps this rule is measured by the largest awake cluster over the level's own scripted runs, its played test and each basket's fire-and-drain.

## TECHNICAL INTERFACE
Parented to req_level_design_rules (level rule 23). The rule's direction is the user's (approved 2026-09-30): no spot where many slimes gather awake, measured by the largest awake cluster over a level's played test and each basket's fire-and-drain. rule_arrivals_clear_faster_than_they_arrive (level rule 24) is its flow-made case: a gathering spot that arrivals outpacing departures create.

Pending the user's sign-off (proposed, not settled; the direction above is what is settled until then; the build already does this):
Measure. An awake cluster is a group of touching slimes that cost physics, counted in slimes. Over the level's own scripted runs (its played test from fresh, and each basket's fire-and-drain; the stress fixtures excepted), the largest awake cluster stays at or under 20 slimes, or goes above 20 for at most 5 s in a row; a run above 20 for more than 5 s in a row fails. A cluster the player builds with calls is accepted: crowd detail and the tick cap cover it. The limit is not yet calibrated.
Built: the measure is tools/level_check/cluster_watch.gd (ClusterWatch: the largest awake cluster sampled every 0.1 s, the seconds above the limit in all and the longest stretch in a row, and the verdict); the level bench (tools/bench_level.gd) prints those numbers per case with no verdict; a level's played test records them per section and per basket drain (the new-level template's test fails on them; the test level's records them with no verdict while the open questions below stand); the level-rules checker (tools/level_check/rules_placement.gd) lists rule 23 as MANUAL, pointing at the played test and the bench and naming the shapes to look for by eye. Guarded by tests/unit/test_cluster_watch.gd, tests/e2e/test_level_checker.gd and tests/e2e/test_rule_23_e2e.gd (a synthetic level: a basket draining into a bowl where the train queues fails, the same basket a screen apart passes).
Open, for the user: (a) whether a basket's own fill counts toward the cluster. As built, it does: the test level's section 3 goes above the limit (59 slimes, 21.9 s in a row in its play; 55, 11.3 s in a row in its basket's drain) because its basket's own pile of 59 to 60 slimes is one cluster above the limit by itself, wherever the basket stands. The proposed default is to leave a basket's own slimes out of the count (only slimes outside a basket's box), the alternative being a basket's quota capped under the limit. (b) Whether a dense train queue on the loop counts as a cluster (it reads as one long touching group, as measured on the stress fixtures), or the measure counts only groups off the loop, or piles by area. (c) Whether the test level's section 3 needs an edit once the other crowding fixes have landed (proposed: no edit; a small edit is the user's call). The test level's rule 23 numbers carry no verdict until these are settled.

## EXPECTATION
In every level, over its played test and each basket's fire-and-drain, no awake cluster stays above the rule's limit for longer than the rule allows; the level-rules check reports where that result comes from.

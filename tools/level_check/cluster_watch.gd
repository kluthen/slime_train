class_name ClusterWatch
extends RefCounted
## Level rule 23's measure (chunk 24, item 24.7; specs/level-design.md rule
## 23, D143, O107): the largest awake cluster over a run, and how long it
## stays above the limit. Fed a simulation every tick (watch()), it samples
## every SAMPLE_TICKS ticks the largest awake cluster as the debug overlay
## and the PERF line count it (DebugCounts.largest_cluster: the biggest group
## of touching Physics slimes, counted in slimes), less the slimes inside a
## basket's box (D163, user 2026-10-07: a basket's own fill doesn't count;
## the pile outside it still does; basket_boxes()): inside by the centre,
## and less the train slimes on the loop's route (user 2026-10-07: rule 23
## targets piles off the route; a queue on the route is rule 24's business,
## the train's flow; on_route_ids()). The cluster is counted over the other
## slimes only, so two piles don't join through a basket's slimes or a
## queue. Every other awake slime counts: free, a train slime knocked off
## the route, stacked on others or due a move to the loop start. A released
## slime is a train slime: on the route it is left out too. It keeps:
##   largest          the largest cluster sampled;
##   ticks_above      the ticks sampled above LIMIT, in all;
##   longest_above    the longest stretch of them in a row, ticks;
##   samples          how many samples were taken.
## A sample stands for the SAMPLE_TICKS ticks up to the next one, so the
## times are good to SAMPLE_TICKS ticks (0.1 s).
##
## The rule's verdict (passes()): the run never stays above LIMIT slimes for
## more than HOLD_SECONDS in a row. The limit is the one rule 23 proposes
## (20 slimes for more than 5 s), kept here until chunk 24 calibrates it and
## specs/tuning.md holds it (O107). Read only: it never changes the state
## (no hash moves). Used by the level bench (tools/bench_level.gd), the
## levels' played tests and the level-rules checker's rule 23 line, which
## points at both.
# @spec-link [[req_level_design_rules]]
# @spec-link [[rule_no_spot_where_slimes_gather_awake]]

## Above this many slimes a cluster counts against the rule (rule 23's
## proposed limit; 20 is where crowd detail steps to level 1, D140).
const LIMIT := 20
## The longest a cluster may stay above LIMIT in a row, seconds.
const HOLD_SECONDS := 5.0
## A sample every this many ticks (0.1 s).
const SAMPLE_TICKS := 6

var largest := 0
var ticks_above := 0
var longest_above := 0
var samples := 0
var _run := 0


## Samples `sim` when its tick falls on a sample (every SAMPLE_TICKS ticks).
## Call it once per tick, after the step.
# @spec-link [[req_level_design_rules]]
func watch(sim: Simulation) -> void:
	if sim.tick % SAMPLE_TICKS == 0:
		sample(largest_cluster(sim))


## The largest awake cluster of `sim` as rule 23 counts it: the debug
## overlay's (DebugCounts.largest_cluster) with the slimes whose centre is
## inside a basket's box (basket_boxes()) and the train slimes on the route
## (on_route_ids()) left out. Read only.
# @spec-link [[rule_no_spot_where_slimes_gather_awake]]
static func largest_cluster(sim: Simulation) -> int:
	return DebugCounts.largest_cluster(sim.slimes, basket_boxes(sim.level), on_route_ids(sim))


## The ids of `sim`'s train slimes on the loop's route, ascending (D165's
## proposed reading): in state train, followed by the train (Train.tracks),
## not due a move to the loop start (LoopStartQueue.due: stalled, out of
## bounds or stuck), and with their centre no more than Train.OFF_ROUTE px
## from the route point at their progress
## (Train.position_at(Train.distance_of)): the train's own "knocked off the
## route" distance (Train.steering_distance), so a slime knocked off the
## route, or stacked on others more than that above it, isn't on it. A train
## slime the train doesn't follow yet (made since the last tick) isn't known
## on the route and isn't in. None without a train. Read only.
# @spec-link [[rule_no_spot_where_slimes_gather_awake]]
static func on_route_ids(sim: Simulation) -> PackedInt32Array:
	var out := PackedInt32Array()
	var train := sim.train
	if train == null or train.length() <= 0.0:
		return out
	var bodies := sim.slimes
	var due := {}
	for entry in LoopStartQueue.due(sim):
		due[entry["id"]] = true
	for slime_id in train.tracked_ids():
		if not bodies.has(slime_id) or bodies.state_of(slime_id) != SlimeBodies.TRAIN or due.has(slime_id):
			continue
		var at := train.position_at(train.distance_of(slime_id))
		if bodies.centre_of(slime_id).distance_to(at) <= Train.OFF_ROUTE:
			out.append(slime_id)
	return out


## The boxes of `level`'s baskets (LevelData.baskets' "box": a slime whose
## centre is inside is in the basket, the one FrontierSets catches by),
## ordered by stable ID; none for no level.
# @spec-link [[rule_no_spot_where_slimes_gather_awake]]
static func basket_boxes(level: LevelData) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	if level == null:
		return boxes
	var ids := level.baskets.keys()
	ids.sort()
	for id in ids:
		boxes.append(level.baskets[id]["box"] as Rect2)
	return boxes


## Takes one sample: `cluster`, the largest awake cluster now, in slimes. It
## stands for SAMPLE_TICKS ticks.
# @spec-link [[req_level_design_rules]]
func sample(cluster: int) -> void:
	samples += 1
	largest = maxi(largest, cluster)
	if cluster > LIMIT:
		ticks_above += SAMPLE_TICKS
		_run += SAMPLE_TICKS
		longest_above = maxi(longest_above, _run)
	else:
		_run = 0


## The seconds sampled above LIMIT, in all.
func above_limit_s() -> float:
	return float(ticks_above) / Simulation.TICK_RATE


## The longest stretch above LIMIT in a row, seconds.
func longest_above_s() -> float:
	return float(longest_above) / Simulation.TICK_RATE


## Whether the run keeps rule 23: never above LIMIT for more than
## HOLD_SECONDS in a row.
# @spec-link [[req_level_design_rules]]
func passes() -> bool:
	return longest_above_s() <= HOLD_SECONDS


## The numbers as `name=value` fields, the bench's RESULT line's shape:
## "largest_cluster=N above_limit_s=S longest_above_s=S".
func fields() -> String:
	return "largest_cluster=%d above_limit_s=%.1f longest_above_s=%.1f" % [largest, above_limit_s(),
			longest_above_s()]


## The numbers and the verdict, for a test's log: fields() and "rule 23
## PASS" or "FAIL" (above LIMIT for more than HOLD_SECONDS in a row).
func report() -> String:
	return "%s: rule 23 %s (above %d slimes for more than %.0f s in a row fails)" % [fields(),
			"PASS" if passes() else "FAIL", LIMIT, HOLD_SECONDS]

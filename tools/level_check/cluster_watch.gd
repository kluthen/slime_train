class_name ClusterWatch
extends RefCounted
## Level rule 23's measure (chunk 24, item 24.7; specs/level-design.md rule
## 23, D143, O107): the largest awake cluster over a run, and how long it
## stays above the limit. Fed a simulation every tick (watch()), it samples
## every SAMPLE_TICKS ticks the largest awake cluster as the debug overlay
## and the PERF line count it (DebugCounts.largest_cluster: the biggest group
## of touching Physics slimes, counted in slimes), less the slimes inside a
## basket's box (user, 2026-10-07: a basket's own fill doesn't count; the
## pile outside it still does; basket_boxes()), and keeps:
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
## inside a basket's box left out (basket_boxes()). Read only.
# @spec-link [[rule_no_spot_where_slimes_gather_awake]]
static func largest_cluster(sim: Simulation) -> int:
	return DebugCounts.largest_cluster(sim.slimes, basket_boxes(sim.level))


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

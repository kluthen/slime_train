class_name CelebrationHops
extends RefCounted
## The celebration's double hop (item 23.11, ux D4; master spec §5.1): when
## the level's celebration begins, every awake slime on screen (a train or
## free slime whose centre is in the view) hops twice, in place. Pure
## simulation logic, owned by FrontierSets: begin() when the burst begins,
## step() once a tick while it plays (not at bedtime, when the celebration
## stands still), after the slime bodies have ticked.
##
## Each chosen slime hops straight up at HOP_STRENGTH as soon as it stands on
## something (SlimeBodies.hop), then again on landing. A slime that can't
## hop (asleep, caught by a basket, gone) waits; whatever is still due when
## the burst ends is dropped. Slimes that come into view during the burst
## don't join in. The hops still due are state: in dump() (so the state
## hash) and in saves (transient.frontier, SaveData). No randomness: the
## slimes are taken in id order.
# @spec-link [[req_level_completion_celebration]]
# @spec-link [[req_hopping_behavior]]

## How many times each slime hops.
const HOPS := 2
## A celebration hop's strength (1 is a full hop): about 50 px high, half a
## second in the air, so the two hops fit well inside the 4 s burst.
## D124, approved in D125 (specs/tuning.md).
const HOP_STRENGTH := 0.6

## Slime id -> the hops it still has to do.
var _due := {}


## The burst begins: every awake slime on screen now has HOPS hops to do.
func begin(sim: Simulation) -> void:
	_due.clear()
	var view := Fusion.view_rect(sim.view)
	for slime_id in sim.slimes.ids():
		var state := sim.slimes.state_of(slime_id)
		if (state == SlimeBodies.TRAIN or state == SlimeBodies.FREE) and view.has_point(sim.slimes.centre_of(slime_id)):
			_due[slime_id] = HOPS


## One tick. `playing`: whether the burst still plays; once it doesn't, the
## hops still due are dropped. Each slime with a hop due that stands on
## something hops now.
func step(sim: Simulation, playing: bool) -> void:
	if not playing:
		_due.clear()
		return
	for slime_id in _sorted_ids():
		if not sim.slimes.has(slime_id):
			_due.erase(slime_id)
			continue
		if sim.slimes.hop(slime_id, Vector2.UP, HOP_STRENGTH):
			_due[slime_id] -= 1
			if _due[slime_id] <= 0:
				_due.erase(slime_id)


## The hops still due as plain data: [[slime id, hops left]], ascending ids.
func dump() -> Array:
	var out := []
	for slime_id in _sorted_ids():
		out.append([slime_id, _due[slime_id]])
	return out


## Puts back dump()'s data (JSON numbers read as floats are made whole).
func restore(data: Array) -> void:
	_due.clear()
	for entry in data:
		_due[int(entry[0])] = int(entry[1])


func _sorted_ids() -> Array:
	var ids := _due.keys()
	ids.sort()
	return ids

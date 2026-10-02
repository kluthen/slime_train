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
## something (SlimeBodies.hop), then again on landing. A slime that can't hop
## (asleep, caught by a basket, gone) waits; whatever is still due when the
## burst ends is dropped. Slimes that come into view during the burst don't
## join in. The hops still due are state: in dump() (so the state hash) and
## in saves (transient.frontier, SaveData). No randomness: the slimes are
## taken in id order.
##
## The burst spares the holders and the resting train slimes (D147 (6),
## chunk 22f, proposed): a train slime on screen that holds its hop (Train.
## is_holding), resting or awake, or that rests (a holder, or a train slime
## resting by contact with one) is left out of the physical double hop and
## isn't woken: an awake holder hopping in place would jostle a resting
## queue awake, and its hold goes on untouched. Free slimes and the other
## awake train slimes hop as before. The spared slimes bounce in drawing only
## (lift_of(), read by SlimeRenderer): two arcs BOUNCE_HEIGHT px high,
## BOUNCE_ARC_TICKS each, back to back from the burst's start, timed like the
## double hop. The spared slimes and the bounce's clock aren't state (not in
## dump(), not saved, not in the hash): a reload during the burst drops the
## bounce. A spared holder whose hold ends during the bounce hops its train
## hop under its drawn bounce (accepted: under a second).
# @spec-link [[req_level_completion_celebration]]
# @spec-link [[req_hopping_behavior]]

## How many times each slime hops.
const HOPS := 2
## A celebration hop's strength (1 is a full hop): about 50 px high, half a
## second in the air, so the two hops fit well inside the 4 s burst.
## Proposed (the spec gives no value).
const HOP_STRENGTH := 0.6

## The drawing-only bounce of the slimes the burst spares (see the class
## doc): its height, px, and each of its HOPS arcs' length, ticks (about the
## half second a celebration hop spends in the air). Proposed.
# @spec-link [[req_level_completion_celebration]]
const BOUNCE_HEIGHT := 16.0
const BOUNCE_ARC_TICKS := 30

## Slime id -> the hops it still has to do.
var _due := {}
## The slimes the burst spares (slime id -> true) and the ticks the burst
## has played (step()), the drawn bounce's clock. Drawing only, not state.
# @spec-link [[req_level_completion_celebration]]
var _spared := {}
var _bounce_tick := 0


## The burst begins: every train or free slime on screen now has HOPS hops
## to do, but the train slimes holding or resting, which it spares (no hop,
## no wake; a drawn bounce instead, see the class doc).
# @spec-link [[req_level_completion_celebration]]
# @spec-link [[req_hopping_behavior]]
func begin(sim: Simulation) -> void:
	_due.clear()
	_spared.clear()
	_bounce_tick = 0
	var view := Fusion.view_rect(sim.view)
	for slime_id in sim.slimes.ids():
		var state := sim.slimes.state_of(slime_id)
		if not (state == SlimeBodies.TRAIN or state == SlimeBodies.FREE) \
				or not view.has_point(sim.slimes.centre_of(slime_id)):
			continue
		if state == SlimeBodies.TRAIN and (sim.slimes.calm_of(slime_id) == SlimeBodies.RESTING
				or (sim.train != null and sim.train.is_holding(slime_id))):
			_spared[slime_id] = true
		else:
			_due[slime_id] = HOPS


## One tick. `playing`: whether the burst still plays; once it doesn't, the
## hops still due are dropped. Each slime with a hop due that stands on
## something hops now.
func step(sim: Simulation, playing: bool) -> void:
	if not playing:
		_due.clear()
		_spared.clear()
		return
	_bounce_tick += 1
	for slime_id in _sorted_ids():
		if not sim.slimes.has(slime_id):
			_due.erase(slime_id)
			continue
		if sim.slimes.hop(slime_id, Vector2.UP, HOP_STRENGTH):
			_due[slime_id] -= 1
			if _due[slime_id] <= 0:
				_due.erase(slime_id)


## Whether the spared slimes' drawn bounce plays now (see the class doc).
## Read only: the renderer reads it.
# @spec-link [[req_level_completion_celebration]]
func bouncing() -> bool:
	return not _spared.is_empty() and _bounce_tick < HOPS * BOUNCE_ARC_TICKS


## How high slime `slime_id`'s drawn shape is lifted now, px: its bounce's
## arc if the burst spares it and the bounce plays, else 0. Read only.
# @spec-link [[req_level_completion_celebration]]
func lift_of(slime_id: int) -> float:
	if not _spared.has(slime_id) or not bouncing():
		return 0.0
	var t := float(_bounce_tick % BOUNCE_ARC_TICKS) / BOUNCE_ARC_TICKS
	return BOUNCE_HEIGHT * 4.0 * t * (1.0 - t)


## The hops still due as plain data: [[slime id, hops left]], ascending ids.
func dump() -> Array:
	var out := []
	for slime_id in _sorted_ids():
		out.append([slime_id, _due[slime_id]])
	return out


## Puts back dump()'s data (JSON numbers read as floats are made whole).
func restore(data: Array) -> void:
	_due.clear()
	_spared.clear()
	for entry in data:
		_due[int(entry[0])] = int(entry[1])


func _sorted_ids() -> Array:
	var ids := _due.keys()
	ids.sort()
	return ids

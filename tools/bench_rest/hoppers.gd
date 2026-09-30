extends RefCounted
## Awake slimes hopping against a resting pile (chunk 22, D107
## measurements), for tools/bench_rest.gd: `wanted` size-1 train slimes
## passing along the pile, over and over, as the train passes a pile lying
## on the loop (a basket's by day; the bowl's or the open pile's here). At
## bedtime no slime is awake in the game: the hoppers are the probe, extra
## to the level's population.
##   in:    a hopper starts on the loop UPSTREAM px before the pile's first
##          centre (the loop's point nearest there), one at a time, once no
##          other hopper is within SPAWN_GAP px of that point;
##   out:   a hopper whose centre gets DOWNSTREAM px past the pile's last
##          centre has passed (a pass) and goes; one found STRAY_BACK px
##          back of its start (sent back to the start of the loop, as a
##          stalled train slime is) or gone (fused) is a stray and goes too;
##          either way the next one starts in its place.
## Removing a hopper so far from the pile touches nothing of it.
# @spec-link [[req_offscreen_simulation]]

const UPSTREAM := 300.0
const DOWNSTREAM := 400.0
const SPAWN_GAP := 90.0
const STRAY_BACK := 300.0

var passes := 0
var strays := 0
var started := 0
var _sim: Simulation
var _wanted := 0
var _live: Array[int] = []
var _start_distance := 0.0
var _start_point := Vector2.ZERO
var _leave_x := 0.0


## Hoppers for `pile` (slime IDs, resting) in `sim`, `wanted` at a time.
func _init(sim: Simulation, pile: Array[int], wanted: int) -> void:
	_sim = sim
	_wanted = wanted
	var low := Vector2.INF
	var high := -Vector2.INF
	for slime_id in pile:
		var centre := sim.slimes.centre_of(slime_id)
		if centre.x < low.x:
			low = centre
		high.x = maxf(high.x, centre.x)
	var start := sim.level.loop.closest(low - Vector2(UPSTREAM, 0.0), sim.train.open_gates)
	_start_distance = start["distance"]
	_start_point = start["position"]
	_leave_x = high.x + DOWNSTREAM


## Before a tick: the hoppers that passed or strayed go, and one starts when
## fewer than `wanted` hop and its start is clear.
func before_tick() -> void:
	for slime_id in _live.duplicate():
		if not _sim.slimes.has(slime_id):
			strays += 1
			_live.erase(slime_id)
			continue
		var x := _sim.slimes.centre_of(slime_id).x
		if x > _leave_x or x < _start_point.x - STRAY_BACK:
			if x > _leave_x:
				passes += 1
			else:
				strays += 1
			_sim.slimes.remove(slime_id)
			_live.erase(slime_id)
	if _live.size() >= _wanted:
		return
	for slime_id in _live:
		if _sim.slimes.centre_of(slime_id).distance_to(_start_point) < SPAWN_GAP:
			return
	var slime := _sim.spawn_train_slime(started % Species.COUNT, 1, _start_distance)
	if slime >= 0:
		_live.append(slime)
		started += 1

class_name Hint
extends RefCounted
## The first-play hint (D65; O71's default, D95, D102): on a fresh save of
## the level, when no call has happened 10 s after the world shows, a
## wordless pulsing mark shows next to the first sleeper. The simulation holds
## whether it shows and where; the scene draws it (TapFeedback).
##
## - Due until the first call (any tap that calls: open ground or a
##   sleeper), which marks it `done`; the done mark goes into the level's
##   save (SaveData, "hint_done"), so deleting the save brings it back.
## - The 10 s count starts when the world shows (world_shown: the game calls
##   it each time it puts a simulation on screen) and restarts on every
##   showing while the hint is due.
## - Never shown during bedtime (`bedtime`, set by the session, chunk 17).
## - Its place: the level's sleeper nearest the first slime's marker (the
##   level rule puts the first sleeper there); none on a level without one.
# @spec-link [[req_first_play_hint]]

## How long without a call before the hint shows, ticks (10 s).
const DUE_TICKS := 10 * Simulation.TICK_RATE

## Whether the first call has happened (for this level's save).
var done := false
## The tick the world last showed: the count starts there.
var since := 0
## Whether bedtime is on: no hint then.
var bedtime := false
## Whether the hint shows now (update() sets it every tick).
var visible := false
## Where it shows, level pixels (the first sleeper's centre).
var position := Vector2.ZERO
## Whether the level has a place for it.
var placed := false


## Finds the hint's place on `data`: its sleeper nearest the first slime's
## marker (the smaller stable ID on a tie).
func place(data: LevelData) -> void:
	placed = false
	position = Vector2.ZERO
	if data == null or data.sleepers.is_empty() or data.first_slime.is_empty():
		return
	var from: Vector2 = data.first_slime["position"]
	var ids := data.sleepers.keys()
	ids.sort()
	var best := INF
	for id in ids:
		var at: Vector2 = data.sleepers[id]["position"]
		var gap := from.distance_squared_to(at)
		if gap < best:
			best = gap
			position = at
			placed = true


## The world shows at tick `tick`: while the hint is due, its count starts
## again from there.
func world_shown(tick: int) -> void:
	if not done:
		since = tick
		visible = false


## A call happened: the hint is done for good.
func called() -> void:
	done = true
	visible = false


## Whether the hint shows at `tick`: due, placed, not bedtime, and 10 s since
## the world showed.
func update(tick: int) -> void:
	visible = placed and not done and not bedtime and tick - since >= DUE_TICKS


## The state as plain data, for Simulation.dump().
func dump() -> Dictionary:
	return {"done": done, "since": since, "bedtime": bedtime, "visible": visible}

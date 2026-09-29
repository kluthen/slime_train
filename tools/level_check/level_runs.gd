class_name LevelRuns
extends RefCounted
## The level-rules checker's behaviour runs (LevelChecker, rules 1, 2 and 7):
## the simulation core (Simulation, no game scene, off-screen simulation
## off: every slime simulated, so the terrain decides), no input.

## A lap must be done within this many times the loop's length at a size's
## off-screen pace (Offscreen.pace: about 67 px/s for a size 1, slower than a
## train slime on open ground and much slower than a return route's carry).
const LAP_SLACK := 3.0
## How far apart the lap runs' slimes start, px along the loop.
const LAP_SPACING := 300.0
## How often a lap run checks its slimes, ticks.
const LAP_SAMPLE := 30


## Wakes sleeper `stable_id` alone in `sim` (every other slime taken out, so
## only the terrain is in the way) as a free slime heading back, and runs
## until it rejoins the train or `deadline` ticks. Returns the ticks it
## took, or -1 while it is still free. A sleeper `sim` doesn't have is an
## error.
static func way_back_ticks(sim: Simulation, stable_id: String, deadline: int) -> int:
	var me := -1
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == stable_id:
			me = slime_id
		else:
			sim.slimes.remove(slime_id)
	if me < 0:
		push_error("LevelRuns: %s isn't asleep in the level" % stable_id)
		return -1
	sim.slimes.set_state(me, SlimeBodies.FREE)
	sim.free_slimes.restore_record(me, {"phase": FreeSlimes.HEADING_BACK, "since": sim.tick,
			"point": sim.slimes.centre_of(me), "route": ""})
	for tick in deadline:
		sim.step()
		if sim.slimes.state_of(me) == SlimeBodies.TRAIN:
			return tick + 1
	return -1


## Laps of `sim`'s current loop with no input: every slime taken out, then
## one train slime per size of `sizes` (one species each, so none fuses),
## the smallest `from` px along the loop and each bigger one LAP_SPACING px
## ahead. Runs until every one has done a whole lap (its progress back where
## it started, plus the loop's length), one needs a safety net, or the
## limit: LAP_SLACK times the loop's length at the slowest size's off-screen
## pace. A safety net moves a slime to the start of the loop (a stalled
## train slime, Train.stalled; two slimes stuck in each other,
## StuckSlimes.stuck: chunk 23A), which would fake or spoil a lap, so any
## case ends the run. Returns {"ticks": size -> the tick its lap was done,
## or -1; "stalled": the cases ({"id", "tick", "reason"}); "limit": ticks;
## "length": the loop's, px}.
static func lap_ticks(sim: Simulation, sizes: Array, from: float) -> Dictionary:
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var length := sim.train.length()
	var order := sizes.duplicate()
	order.sort()
	var slimes := {}
	var start := {}
	var slowest := INF
	for k in order.size():
		var size: int = order[k]
		slimes[size] = sim.spawn_train_slime(k % Species.COUNT, size, from + LAP_SPACING * k)
		start[size] = sim.train.progress_of(slimes[size])
		slowest = minf(slowest, Offscreen.pace(size))
	var limit := ceili(LAP_SLACK * length / slowest * Simulation.TICK_RATE)
	var done := {}
	while sim.tick < limit and done.size() < slimes.size() and _safety_cases(sim).is_empty():
		sim.run(LAP_SAMPLE)
		for size in slimes:
			if not done.has(size) and sim.train.progress_of(slimes[size]) >= start[size] + length:
				done[size] = sim.tick
	var ticks := {}
	for size in slimes:
		ticks[size] = done.get(size, -1)
	return {"ticks": ticks, "stalled": _safety_cases(sim), "limit": limit, "length": length}


## The safety nets' cases so far: the stalled train slimes and the stuck
## pairs, {"id", "tick", "reason"} each.
static func _safety_cases(sim: Simulation) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	cases.append_array(sim.train.stalled)
	cases.append_array(sim.stuck_slimes.stuck)
	return cases

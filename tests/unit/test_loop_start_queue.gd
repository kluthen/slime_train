extends GutTest
## The loop-start queue (src/sim/loop_start_queue.gd, D150 (2), (3)): the
## safety nets only find the slimes due a move to the loop start (stalled,
## out of bounds, stuck, lost); the queue moves one per turn, the next turn
## 30 to 120 ticks after the last move (the first draw of
## "loop_start:gap:<move tick>"); out of bounds first, then first due first
## moved, ties by id; a slime that recovers while it waits leaves without a
## move and without spending a wait; a stuck pair's count goes on while its
## mover waits; the landing spot is a random free one on the first 240 px of
## the loop, inside a split zone, up to 8 draws from
## "loop_start:spot:<tick>", and with all 8 taken nobody moves and the head
## tries again on the next multiple of 30; the debug kill tool stays
## immediate and counts as a move; a save and reload mid-queue carries on
## the same.
##
## The world: a floor whose top is at y = 0 from x = -6000 to 6000. The loop
## runs along it at a base slime's centre height (y = -24) from x = -5000 to
## 5000 and returns under the floor (y = 400). Loop distance d is x = d - 5000
## on the outgoing part. Split zone t.split covers the loop's first SPLIT_END
## px. The wedge: no slime hops (SlimeBodies.auto_hops off), so a train
## slime's progress can't advance and it stalls at 60 s.
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[rule_stuck_slimes_moved_to_start]]
# @test-link [[rule_left_alone_and_lost]]
# @test-link [[req_persistence_and_saves]]

const STALL_TICKS := Train.STALL_TICKS
const SPLIT_END := 200.0
const OVERLAP := Vector2(0, -40)
## The checks run on ticks 0, 30, 60, 90: the fourth one makes a pair stuck.
const STUCK_TICK := StuckSlimes.CHECK_TICKS * (StuckSlimes.CHECKS - 1)
## Two base slimes' room: closer, their rings overlap.
const ROOM := 2.0 * (SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE)


func _level(split_end := SPLIT_END) -> LevelData:
	var data := LevelData.new("queue", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-5000, -24), Vector2(5000, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(5000, -24), Vector2(5000, 400), Vector2(-5000, 400), Vector2(-5000, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-4900, -24)}
	data.add_split_zone("t.split", Rect2(-5000, -300, split_end, 400))
	return data


func _terrain() -> TerrainSegments:
	return TerrainSegments.new([
		PackedVector2Array([Vector2(-6000, 0), Vector2(6000, 0), Vector2(6000, 300), Vector2(-6000, 300)]),
	])


## A simulation on the synthetic level, no slime yet (the first slime is
## removed), nobody hopping, the view on x 0.
func _sim(master_seed := 5, split_end := SPLIT_END) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level(split_end))
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(0, -200), 1.0, ScreenView.DEFAULT_SIZE)
	sim.slimes.auto_hops = false
	return sim


## Wedged base train slimes at `distances` px along the loop: each stalls
## STALL_TICKS after its first follow. Returns their ids.
func _wedged(sim: Simulation, distances: Array) -> Array[int]:
	var out: Array[int] = []
	for k in distances.size():
		out.append(sim.spawn_train_slime(k % 4, 1, distances[k]))
	return out


## The wait after a move at `tick` (the queue's derived stream).
func _gap(sim: Simulation, tick: int) -> int:
	return Rng.new(sim.rng.seed_value).derive("loop_start:gap:%d" % tick).randi_range(
			LoopStartQueue.TURN_MIN, LoopStartQueue.TURN_MAX)


## Every move to the loop start logged so far, by tick: {"id", "tick", "reason"}.
func _moves(sim: Simulation) -> Array:
	var out := []
	for entry in sim.train.stalled:
		out.append({"id": entry["id"], "tick": entry["tick"], "reason": entry["reason"]})
	for entry in sim.stuck_slimes.stuck:
		if entry["moved"]:
			out.append({"id": entry["id"], "tick": entry["tick"], "reason": StuckSlimes.STUCK})
	for entry in sim.offscreen.lost:
		out.append({"id": entry["id"], "tick": entry["tick"], "reason": Offscreen.LOST})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["tick"] < b["tick"])
	return out


## Runs `sim` until tick `tick` (that tick not yet stepped). With `clear`,
## each slime moved to the loop start is checked where it landed
## (_landed_free), then put out of the way, 60 px apart by id from x -3500
## (wedged, it would stay there and take the spots).
func _run_to(sim: Simulation, tick: int, clear := true) -> void:
	if not clear:
		sim.run(tick - sim.tick)
		return
	while sim.tick < tick:
		var before := _moves(sim).size()
		sim.run(1)
		var moves := _moves(sim)
		for k in range(before, moves.size()):
			var slime_id: int = moves[k]["id"]
			_landed_free(sim, slime_id, "slime %d at tick %d" % [slime_id, moves[k]["tick"]])
			var centre := sim.slimes.centre_of(slime_id)
			sim.slimes.translate(slime_id, Vector2(-3500.0 + 60.0 * slime_id, centre.y) - centre)


## Checks slime `slime_id` just landed on the loop's first stretch, inside
## the split zone, its ring overlapping no other.
func _landed_free(sim: Simulation, slime_id: int, label := "") -> void:
	var distance := sim.train.distance_of(slime_id)
	assert_between(distance, 0.0, LoopStart.STRETCH, label + ": on the first 240 px")
	var centre := sim.slimes.centre_of(slime_id)
	assert_true(sim.split_zones.covers(centre), label + ": inside a split zone")
	for other in sim.slimes.ids():
		if other != slime_id:
			var room := sim.slimes.radius_of(slime_id) + sim.slimes.radius_of(other) + 2.0 * SlimeBodies.EDGE
			assert_gte(centre.distance_to(sim.slimes.centre_of(other)), room - 0.01,
					label + ": clear of slime %d" % other)


## The first master seed from 1 whose wait after a move at `tick` is at
## least `at_least` ticks.
func _seed_with_gap(tick: int, at_least: int) -> int:
	var master_seed := 1
	while Rng.new(master_seed).derive("loop_start:gap:%d" % tick).randi_range(
			LoopStartQueue.TURN_MIN, LoopStartQueue.TURN_MAX) < at_least:
		master_seed += 1
	return master_seed


# --- Turns --------------------------------------------------------------------

func test_one_move_per_turn_each_wait_from_its_derived_stream() -> void:
	var sim := _sim()
	var ids := _wedged(sim, [3000.0, 3400.0, 3800.0])
	_run_to(sim, STALL_TICKS)
	assert_eq(_moves(sim), [], "nobody moved before 60 s")
	sim.run(1)
	# All three came due on one tick: the lowest id goes first, alone.
	assert_eq(_moves(sim), [{"id": ids[0], "tick": STALL_TICKS, "reason": Train.STALLED}])
	assert_eq(LoopStartQueue.due(sim).size(), 2, "the other two wait")
	var second := STALL_TICKS + _gap(sim, STALL_TICKS)
	var third := second + _gap(sim, second)
	_run_to(sim, third + 1)
	assert_eq(_moves(sim), [{"id": ids[0], "tick": STALL_TICKS, "reason": Train.STALLED},
			{"id": ids[1], "tick": second, "reason": Train.STALLED},
			{"id": ids[2], "tick": third, "reason": Train.STALLED}], "one per turn, each after its wait")
	for wait in [second - STALL_TICKS, third - second]:
		assert_between(wait, LoopStartQueue.TURN_MIN, LoopStartQueue.TURN_MAX)
	for slime_id in ids:
		assert_eq(sim.slimes.state_of(slime_id), SlimeBodies.TRAIN)


## A simulation whose turn is kept shut from tick STALL_TICKS - 10 until
## after tick STALL_TICKS + 60 by a kill tool move, with wedged train slimes
## x (due at STALL_TICKS + 50: followed afresh at tick 50), y and w (due at
## STALL_TICKS), x's id the lowest. Returns [sim, x, y, w, the tick the turn
## opens].
func _shut_turn() -> Array:
	var kill_at := STALL_TICKS - 10
	var sim := _sim(_seed_with_gap(kill_at, 75))
	var ids := _wedged(sim, [3000.0, 3400.0, 3800.0, 1000.0])
	_run_to(sim, 50)
	sim.train.track(ids[0], 3000.0)
	_run_to(sim, kill_at)
	assert_true(DebugKill.send_to_start(sim, ids[3]))
	return [sim, ids[0], ids[1], ids[2], kill_at + _gap(sim, kill_at)]


## The moves so far other than the kill tool's.
func _queue_moves(sim: Simulation) -> Array:
	return _moves(sim).filter(func(entry: Dictionary) -> bool: return entry["reason"] != Offscreen.LOST)


func test_out_of_bounds_first_then_first_due_first_moved() -> void:
	var run := _shut_turn()
	var sim: Simulation = run[0]
	var x: int = run[1]
	var y: int = run[2]
	var w: int = run[3]
	var opens: int = run[4]
	_run_to(sim, STALL_TICKS + 60)
	assert_eq(_queue_moves(sim), [], "the turn is shut")
	sim.slimes.translate(w, Vector2(0, 5000))
	var queue := LoopStartQueue.due(sim).map(func(entry: Dictionary) -> int: return entry["id"])
	assert_eq(queue, [w, y, x], "out of bounds, then the first due (y before x, though x's id is lower)")
	var second := opens + _gap(sim, opens)
	var third := second + _gap(sim, second)
	_run_to(sim, third + 1)
	# w was stalled first: it is logged under its earliest reason.
	assert_eq(_queue_moves(sim), [{"id": w, "tick": opens, "reason": Train.STALLED},
			{"id": y, "tick": second, "reason": Train.STALLED},
			{"id": x, "tick": third, "reason": Train.STALLED}])


func test_a_slime_that_recovers_while_it_waits_leaves_without_a_move_or_a_wait() -> void:
	var run := _shut_turn()
	var sim: Simulation = run[0]
	var x: int = run[1]
	var y: int = run[2]
	var w: int = run[3]
	var opens: int = run[4]
	_run_to(sim, STALL_TICKS + 60)
	# y and w, due first, get 30 px further along the loop: no longer stalled.
	for slime_id in [y, w]:
		sim.slimes.translate(slime_id, Vector2(Train.STALL_ADVANCE + 6.0, 0))
	_run_to(sim, opens + 1)
	assert_eq(_queue_moves(sim), [{"id": x, "tick": opens, "reason": Train.STALLED}],
			"y and w left the queue; x moved on the same turn")
	assert_almost_eq(sim.train.distance_of(y), 3400.0 + Train.STALL_ADVANCE + 6.0, 1.0, "y rides on where it was")


func test_lost_and_stuck_slimes_go_through_the_queue() -> void:
	var sim := _sim()
	sim.offscreen.enabled = true
	var big := sim.slimes.create(0, 2, OVERLAP, SlimeBodies.TRAIN)
	sim.train.track(big, 5000.0)
	var small := sim.slimes.create(1, 1, OVERLAP, SlimeBodies.TRAIN)
	sim.train.track(small, 5000.0)
	# A free slime far off screen with no way back: left alone, then lost.
	var free := sim.slimes.create(2, 1, Vector2(-3000, -1000), SlimeBodies.FREE)
	sim.run(1)
	assert_eq(sim.offscreen.away[free], 0)
	# Its count started earlier: it is lost from tick STUCK_TICK, as the pair
	# is stuck: due on one tick, the lower id goes first.
	sim.offscreen.away[free] = STUCK_TICK - Offscreen.LEFT_ALONE_TICKS - Offscreen.LOST_TICKS
	_run_to(sim, STUCK_TICK + 1)
	assert_eq(_moves(sim), [{"id": small, "tick": STUCK_TICK, "reason": StuckSlimes.STUCK}])
	assert_eq(sim.stuck_slimes.stuck.back()["other"], big)
	assert_eq(sim.slimes.state_of(free), SlimeBodies.FREE, "the lost one waits")
	assert_true(sim.offscreen.away.has(free), "its count kept")
	var lost_at := STUCK_TICK + _gap(sim, STUCK_TICK)
	_run_to(sim, lost_at + 1)
	assert_eq(sim.offscreen.lost, [{"id": free, "tick": lost_at, "reason": Offscreen.LOST}] as Array[Dictionary])
	assert_eq(sim.slimes.state_of(free), SlimeBodies.TRAIN, "back on the train")
	assert_false(sim.offscreen.away.has(free))


func test_the_stuck_count_goes_on_while_its_mover_waits() -> void:
	# A seed whose wait after tick 80 keeps the turn shut past two checks.
	var sim := _sim(_seed_with_gap(80, 75))
	var lone := _wedged(sim, [1000.0])[0]
	var big := sim.slimes.create(0, 2, OVERLAP, SlimeBodies.TRAIN)
	sim.train.track(big, 5000.0)
	var small := sim.slimes.create(1, 1, OVERLAP, SlimeBodies.TRAIN)
	sim.train.track(small, 5000.0)
	_run_to(sim, 80)
	assert_true(DebugKill.send_to_start(sim, lone))
	var opens := 80 + _gap(sim, 80)
	assert_gt(opens, 150)
	_run_to(sim, STUCK_TICK + 1)
	assert_eq(sim.stuck_slimes.dump()["counts"], [[big, small, StuckSlimes.CHECKS]], "stuck at tick 90")
	assert_eq(sim.stuck_slimes.stuck, [] as Array[Dictionary], "not moved: the turn is shut")
	_run_to(sim, 151)
	assert_eq(sim.stuck_slimes.dump()["counts"], [[big, small, StuckSlimes.CHECKS + 2]], "two more checks")
	assert_eq(sim.stuck_slimes.stuck_since(Vector2i(big, small), sim.tick - 1), STUCK_TICK, "stuck since tick 90")
	assert_eq(LoopStartQueue.due(sim)[0]["since"], STUCK_TICK)
	_run_to(sim, opens + 1)
	assert_eq(sim.stuck_slimes.stuck, [{"id": small, "other": big, "tick": opens, "reason": StuckSlimes.STUCK,
			"moved": true}] as Array[Dictionary], "moved at its turn")
	assert_eq(sim.stuck_slimes.dump()["counts"], [], "its counts go with the move")


# --- The landing spot ---------------------------------------------------------

func test_the_spot_is_random_on_the_first_240_px_free_and_inside_a_split_zone() -> void:
	# A sleeper 60 px along the loop: the spots near it are taken; the split
	# zone ends SPLIT_END px along: the spots past it too.
	var seen := {}
	for master_seed in range(1, 21):
		var sim := _sim(master_seed)
		var sleeper := sim.slimes.create(3, 1, LoopStart.landing_point(sim.train, 1, 60.0), SlimeBodies.SLEEPER)
		var slime := _wedged(sim, [3000.0])[0]
		_run_to(sim, STALL_TICKS + 1, false)
		# The spot is the first free draw of its stream.
		var draws := Rng.new(sim.rng.seed_value).derive("loop_start:spot:%d" % STALL_TICKS)
		var first_free := -1.0
		for k in LoopStart.DRAWS:
			var d := draws.randf_range(0.0, LoopStart.STRETCH)
			if d < SPLIT_END and absf(d - 60.0) >= ROOM:
				first_free = d
				break
		if first_free < 0.0:
			assert_eq(sim.train.stalled, [] as Array[Dictionary], "seed %d: no free draw, no move" % master_seed)
			continue
		assert_eq(sim.train.stalled.size(), 1, "seed %d: moved" % master_seed)
		var distance := sim.train.distance_of(slime)
		assert_almost_eq(distance, first_free, 0.01, "seed %d: the first free draw" % master_seed)
		assert_lt(distance, SPLIT_END, "seed %d: inside the split zone" % master_seed)
		assert_gte(absf(distance - 60.0), ROOM - 0.01, "seed %d: clear of the sleeper" % master_seed)
		_landed_free(sim, slime, "seed %d" % master_seed)
		assert_true(sim.slimes.has(sleeper))
		seen[snappedf(distance, 0.1)] = true
	assert_gt(seen.size(), 10, "random spots")


func test_with_all_8_draws_taken_nobody_moves_and_the_head_retries_on_the_next_multiple_of_30() -> void:
	var sim := _sim(5, 120.0)
	# Sleepers 10, 58 and 106 px along: every spot inside the zone is taken.
	# (The run isn't cleared: nothing moves until the retry.)
	var sleepers := []
	for distance in [10.0, 58.0, 106.0]:
		sleepers.append(sim.slimes.create(3, 1, LoopStart.landing_point(sim.train, 1, distance), SlimeBodies.SLEEPER))
	var slime := _wedged(sim, [3000.0])[0]
	var at := sim.slimes.centre_of(slime)
	_run_to(sim, STALL_TICKS + 5)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "all taken: nobody moves")
	assert_almost_eq(sim.slimes.centre_of(slime).x, at.x, 1.0, "it stays where it was")
	assert_eq(LoopStartQueue.due(sim).size(), 1, "still due")
	# The start clears on a tick that isn't a multiple of 30: the next try is
	# on the next one.
	for sleeper in sleepers:
		sim.slimes.remove(sleeper)
	var retry := (STALL_TICKS / 30 + 1) * 30
	_run_to(sim, retry)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "not before the retry")
	sim.run(1)
	assert_eq(sim.train.stalled, [{"id": slime, "tick": retry, "reason": Train.STALLED}] as Array[Dictionary])
	_landed_free(sim, slime)


# --- The kill tool --------------------------------------------------------------

func test_the_kill_tool_is_immediate_and_counts_as_a_move() -> void:
	var sim := _sim()
	var ids := _wedged(sim, [3000.0, 1000.0])
	var stalled := ids[0]
	var killed := ids[1]
	_run_to(sim, STALL_TICKS - 10)
	assert_true(DebugKill.send_to_start(sim, killed))
	assert_eq(sim.offscreen.lost, [{"id": killed, "tick": STALL_TICKS - 10, "reason": Offscreen.LOST}] as Array[Dictionary],
			"moved at once")
	assert_lt(sim.train.distance_of(killed), LoopStart.STRETCH)
	_landed_free(sim, killed)
	var turn := STALL_TICKS - 10 + _gap(sim, STALL_TICKS - 10)
	_run_to(sim, turn)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "due at 60 s, but the kill's wait runs")
	sim.run(1)
	assert_eq(sim.train.stalled, [{"id": stalled, "tick": turn, "reason": Train.STALLED}] as Array[Dictionary])


# --- Saves and determinism --------------------------------------------------------

func test_a_save_and_reload_mid_queue_carries_on_the_same() -> void:
	var sim := _sim(9)
	_wedged(sim, [3000.0, 3400.0, 3800.0, 4200.0])
	# A pair put on one centre at tick 3510: stuck at the check of tick 3600,
	# when the four wedged ones stall; it waits in line behind them.
	_run_to(sim, STALL_TICKS - 90)
	var big := sim.slimes.create(0, 2, OVERLAP, SlimeBodies.TRAIN)
	sim.train.track(big, 5000.0)
	var small := sim.slimes.create(1, 1, OVERLAP, SlimeBodies.TRAIN)
	sim.train.track(small, 5000.0)
	var second := STALL_TICKS + _gap(sim, STALL_TICKS)
	_run_to(sim, second - 1)
	assert_eq(sim.train.stalled.size(), 1, "one moved")
	assert_eq(LoopStartQueue.due(sim).size(), 4, "three wedged and the stuck one waiting")
	var text := SaveData.to_text(sim.to_save())
	var copy := Simulation.from_save(JSON.parse_string(text), _level(), _terrain())
	assert_not_null(copy)
	copy.slimes.auto_hops = false
	assert_eq(copy.state_hash(), sim.state_hash(), "the reloaded state")
	_run_to(sim, sim.tick + 600)
	_run_to(copy, copy.tick + 600)
	assert_eq(sim.train.stalled.size(), 4, "the four wedged ones moved")
	assert_eq(sim.stuck_slimes.stuck.size(), 1, "and the stuck one")
	assert_eq(sim.stuck_slimes.stuck.back()["id"], small)
	assert_eq(copy.train.stalled, sim.train.stalled, "the same moves on the same ticks")
	assert_eq(copy.stuck_slimes.stuck, sim.stuck_slimes.stuck)
	assert_eq(copy.state_hash(), sim.state_hash(), "and it carries on the same")


func test_same_seed_same_moves_and_spots() -> void:
	var runs := []
	for master_seed in [11, 11, 12]:
		var sim := _sim(master_seed)
		_wedged(sim, [3000.0, 3400.0, 3800.0])
		_run_to(sim, STALL_TICKS + 400)
		assert_eq(sim.train.stalled.size(), 3)
		runs.append(sim.state_hash())
	assert_eq(runs[0], runs[1])
	assert_ne(runs[0], runs[2])

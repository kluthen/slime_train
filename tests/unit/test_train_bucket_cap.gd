extends GutTest
## The bucket cap (chunk 22i, D151 points 2 to 5: TrainHold.holds, Train's
## bucket_cap switch, off by default; BucketLoads). With the switch on, a
## train slime whose due hop would land in another loop bucket holds while
## that bucket has no room for it (a "bucket full" hold, bucket_holds); in an
## overfilled bucket (at or over its cap) it hops only while the next bucket
## ahead has room for it, wherever its hop lands; under its cap a hop inside
## its bucket is never held by the cap. A bucket hold is a hold like any
## other: the same record, periods and re-checks, a holder for the holder
## rule, released by the hold guard with no check. A slime on a slide and an
## arrival (a join, a move to the loop start) are not hops: never held. The
## parked clamp is tests/unit/test_offscreen_bucket_cap.gd's.
##
## The world (as tests/unit/test_train_bucket_loads.gd's): a floor slab, its
## top at y = 0, the loop along it at a base slime's centre height from
## x = -1500 to 1500 (loop distance d is x = d - 1500), returning at y = 400;
## 6848 px long. The cap's density is 1 per 100 px, so every 300 px bucket's
## cap is 3 (bucket 1 holds d 300 to 600, bucket 2 d 600 to 900). A bucket is
## filled by parked train slimes (fillers: counted in the loads, invisible to
## the hop corridor, never moving in this harness). A walker far ahead (its
## hop 1000 s away) keeps the hold guard from firing, unless a test leaves it
## out. The harness (_step) rebuilds the loads, steers the train, ticks the
## bodies, fusion and the train's follow in Simulation.step's order.

const Crowd := preload("res://tests/unit/hold_crowd_support.gd")
const DT := Simulation.TICK_SECONDS
const STAND_Y := Crowd.STAND_Y
const LOOP_START_X := -1500.0
## Slimes per 100 px of loop: a 300 px bucket's cap is 3.
const DENSITY := 1.0
## A train slime 250 px along the loop (bucket 0): its 150 px hop lands at
## 400 px, in bucket 1.
const HOPPER_D := 250.0
const WALKER_D := 2500.0


# --- The harness ---------------------------------------------------------------

## The loop of the world (see the class doc).
func _level() -> LevelData:
	var data := LevelData.new("bucket-cap", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


## A simulation (seed 5) on the world, its first slime removed, the view on
## it, the bucket cap switched `on` at `density`, with a walker unless
## `walker` is false.
func _sim(on := true, density := DENSITY, walker := true) -> Simulation:
	var sim := Simulation.new(5)
	sim.slimes.terrain = Crowd.terrain([])
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-50, -50), 1.0, ScreenView.DEFAULT_SIZE)
	sim.train.bucket_cap = on
	sim.train.bucket_cap_density = density
	if walker:
		sim.slimes.set_hop_timer(_slime(sim, WALKER_D), 1000.0)
	return sim


## A train slime of `size` standing on the floor `d` px along the loop, its
## next hop 10 s away.
func _slime(sim: Simulation, d: float, size := 1) -> int:
	var lift := SlimeBodies.ring_radius_for(size) - SlimeBodies.ring_radius_for(1)
	var slime := sim.slimes.create(0, size, Vector2(d + LOOP_START_X, STAND_Y - lift), SlimeBodies.TRAIN)
	sim.slimes.set_hop_timer(slime, 10.0)
	sim.train.track(slime, d)
	return slime


## A filler: a parked train slime of `size`, `d` px along the loop.
func _filler(sim: Simulation, d: float, size: int) -> int:
	var slime := _slime(sim, d, size)
	sim.slimes.set_hop_timer(slime, 1000.0)
	sim.slimes.park(slime)
	return slime


## One tick in Simulation.step's order: the loads rebuilt, the train steers,
## the bodies tick, fusion counts, the train follows.
func _step(sim: Simulation) -> void:
	sim.train.rebuild_loads(sim.slimes)
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	sim.slimes.tick(DT)
	sim.fusion.step(sim)
	sim.train.follow(sim.slimes, sim.tick)
	sim.tick += 1


## Steps `ticks` times; returns the ticks `slime` took a train hop on.
func _hops(sim: Simulation, slime: int, ticks: int) -> Array:
	var out := []
	for i in ticks:
		var tick := sim.tick
		_step(sim)
		if sim.slimes.train_hopped.has(slime):
			out.append(tick)
	return out


## Steps 30 ticks: the slimes settle where they were put.
func _settle(sim: Simulation) -> void:
	for i in 30:
		_step(sim)


## Makes `slime`'s hop due, then steps once; true when it hopped.
func _due_step(sim: Simulation, slime: int) -> bool:
	sim.slimes.set_hop_timer(slime, 0.0)
	_step(sim)
	return sim.slimes.train_hopped.has(slime)


## The hold's debug counters that aren't 0.
func _nonzero(sim: Simulation) -> Dictionary:
	var out := {}
	var counters := sim.train.hold_counters()
	for name: String in counters:
		if counters[name] != 0:
			out[name] = counters[name]
	return out


## `sim`'s state as the state hash reads it, its identities aside (_sim()
## removes the level's first slime outside the game's paths).
func _state(sim: Simulation) -> String:
	var dump := sim.dump()
	dump.erase("identities")
	return StateHash.canonical_json(dump)


# --- A hop into a full bucket ----------------------------------------------------

# D151 (2): bucket 1 at its cap (a size 3), the hop landing there holds, a
# "bucket full" hold; with a size 2 there, a base slime still fits: it hops.
# @test-link [[req_hopping_behavior]]
func test_a_hop_into_a_full_bucket_holds_and_into_one_with_room_does_not() -> void:
	var sim := _sim()
	var hopper := _slime(sim, HOPPER_D)
	_filler(sim, 500.0, 3)
	_settle(sim)
	assert_false(_due_step(sim, hopper), "held")
	assert_true(sim.train.is_holding(hopper), "a bucket full hold")
	assert_eq(_nonzero(sim), {"bucket_holds": 1}, "filed as bucket full only")
	var roomy := _sim()
	var other := _slime(roomy, HOPPER_D)
	_filler(roomy, 500.0, 2)
	_settle(roomy)
	assert_true(_due_step(roomy, other), "room for it: it hops")
	assert_false(roomy.train.is_holding(other))
	assert_eq(roomy.train.hold_counters()["bucket_holds"], 0)


# D151 (1): room for one base slime left, two hops due on one tick both
# landing there: the first in the processing order (ascending id, here the
# one behind) takes it, the other holds.
# @test-link [[req_hopping_behavior]]
func test_the_last_room_goes_to_the_first_in_processing_order_only() -> void:
	var sim := _sim()
	var first := _slime(sim, 180.0)
	var second := _slime(sim, HOPPER_D)
	_filler(sim, 500.0, 2)
	_settle(sim)
	sim.slimes.set_hop_timer(first, 0.0)
	sim.slimes.set_hop_timer(second, 0.0)
	_step(sim)
	assert_true(sim.slimes.train_hopped.has(first), "the lower id took the last room")
	assert_false(sim.train.is_holding(first))
	assert_true(sim.train.is_holding(second), "no room left for the other")
	assert_eq(_nonzero(sim).get("bucket_holds", 0), 1)


# --- An overfilled bucket --------------------------------------------------------

# D151 (3): bucket 1 at its cap with the hopper in it (310 px, its hop lands
# at 460 px, inside): it hops while bucket 2 has room, holds once bucket 2 is
# full; a hop out of it (from 500 px to 650 px) goes while bucket 2 has room.
# @test-link [[req_hopping_behavior]]
func test_in_an_overfilled_bucket_a_hop_goes_only_while_the_next_bucket_has_room() -> void:
	for case in ["inside, room ahead", "inside, next full", "out, room ahead"]:
		var sim := _sim()
		var hopper := _slime(sim, 500.0 if case.begins_with("out") else 310.0)
		_filler(sim, 590.0, 2)
		if case.ends_with("full"):
			_filler(sim, 800.0, 3)
		_settle(sim)
		sim.train.rebuild_loads(sim.slimes)
		assert_true(sim.train.bucket_loads().overfilled(1), "%s: bucket 1 at its cap" % case)
		var hopped := _due_step(sim, hopper)
		assert_eq(hopped, not case.ends_with("full"), case)
		assert_eq(sim.train.is_holding(hopper), case.ends_with("full"), case)
		assert_eq(sim.train.hold_counters()["bucket_holds"], 1 if case.ends_with("full") else 0, case)


# D151 (3): under its cap, a hop inside the bucket is never held by the cap,
# even with the next bucket full.
# @test-link [[req_hopping_behavior]]
func test_under_its_cap_a_hop_inside_the_bucket_is_never_held_by_the_cap() -> void:
	var sim := _sim()
	var hopper := _slime(sim, 310.0)
	_filler(sim, 590.0, 1)
	_filler(sim, 800.0, 3)
	_settle(sim)
	assert_true(_due_step(sim, hopper), "it hops inside bucket 1")
	assert_eq(_nonzero(sim), {"front_hops": 1}, "no hold")


# --- A hold like any other ----------------------------------------------------------

# D151 (4): a bucket holder is a holder for the holder rule: the slime behind
# it (its hop inside bucket 0, under its cap) holds behind it.
# @test-link [[req_hopping_behavior]]
func test_a_bucket_holder_holds_the_slime_behind_it() -> void:
	var sim := _sim()
	var holder := _slime(sim, HOPPER_D)
	var behind := _slime(sim, 60.0)
	_filler(sim, 500.0, 3)
	_settle(sim)
	_due_step(sim, holder)
	assert_true(sim.train.is_holding(holder))
	assert_false(_due_step(sim, behind), "held behind the bucket holder")
	assert_true(sim.train.is_holding(behind))
	assert_eq(_nonzero(sim), {"bucket_holds": 1, "holder_holds": 1})


# D151 (4): the bucket holder holds on through its re-checks and a period's
# end while the bucket stays full, its hold filed once; once there is room
# it hops at its next check, a clear end.
# @test-link [[req_hopping_behavior]]
func test_a_bucket_hold_is_filed_once_and_ends_at_a_check_once_room_appears() -> void:
	var sim := _sim()
	var hopper := _slime(sim, HOPPER_D)
	var filler := _filler(sim, 500.0, 3)
	_settle(sim)
	_due_step(sim, hopper)
	var began := sim.train.hold_began_at(hopper)
	var hold := sim.train.hold()
	var period_end := hold.period_at(sim.slimes, hopper, sim.tick).y
	assert_eq(_hops(sim, hopper, period_end + 1 - sim.tick), [], "full: it holds through its checks")
	assert_eq(sim.train.hold_began_at(hopper), began, "the same hold, past its period's end")
	assert_eq(_nonzero(sim), {"bucket_holds": 1}, "filed once")
	sim.slimes.remove(filler)
	var hops := _hops(sim, hopper, TrainHold.HOLD_RECHECK_TICKS + 1)
	assert_eq(hops.size(), 1, "room: it hops at its next re-check")
	assert_eq(_nonzero(sim), {"bucket_holds": 1, "hold_ends_clear": 1, "front_hops": 1})


# D151 (4): with the whole train waiting (no walker), the hold guard
# releases the bucket holder: its hop ignores the cap, and carries bucket 1
# over it.
# @test-link [[req_hopping_behavior]]
# @test-link [[rule_loop_travelable_with_no_input]]
func test_the_guard_release_ignores_the_cap() -> void:
	var sim := _sim(true, DENSITY, false)
	var hopper := _slime(sim, HOPPER_D)
	_filler(sim, 500.0, 3)
	_settle(sim)
	_due_step(sim, hopper)
	var began := sim.train.hold_began_at(hopper)
	var hops := _hops(sim, hopper, began + TrainHold.HOLD_GUARD_TICKS + 1 - sim.tick)
	assert_eq(hops, [began + TrainHold.HOLD_GUARD_TICKS], "released by the guard, it hops into the full bucket")
	assert_eq(sim.train.hold_counters()["guard_releases"], 1)
	for i in 60:
		_step(sim)
	sim.train.rebuild_loads(sim.slimes)
	assert_gt(sim.train.bucket_loads().load(1), sim.train.bucket_loads().cap(1), "bucket 1 over its cap")


# --- Not hops ------------------------------------------------------------------------

# D151 (5): a slime on a slide is carried, not held, its bucket and the next
# full.
# @test-link [[req_hopping_behavior]]
func test_a_slime_on_a_slide_is_never_held_by_the_cap() -> void:
	var sim := _sim()
	var slider := _slime(sim, 2990.0)
	_filler(sim, 3200.0, 3)
	_filler(sim, 3400.0, 3)
	_settle(sim)
	var record := sim.train.record_of(slider)
	record["distance"] = 3005.0
	sim.train.restore_record(slider, record)
	sim.slimes.set_hop_timer(slider, 0.0)
	_step(sim)
	assert_true(sim.train.record_of(slider)["on_slide"], "on the slide")
	assert_false(sim.train.is_holding(slider), "carried, not held")
	assert_eq(_nonzero(sim), {})


# D151 (5): a join and a move to the loop start land in a full bucket 0
# anyway and hold nothing: they carry it over its cap.
# @test-link [[req_hopping_behavior]]
func test_a_join_and_a_move_to_the_loop_start_are_never_held() -> void:
	var sim := _sim()
	_filler(sim, 150.0, 3)
	var mover := _slime(sim, 1200.0)
	_settle(sim)
	var joiner := sim.slimes.create(0, 1, Vector2(-1440.0, STAND_Y), SlimeBodies.TRAIN)
	sim.slimes.set_hop_timer(joiner, 10.0)
	var at := LoopStart.move(sim.slimes, sim.train, mover)
	assert_lt(at, 300.0, "moved into bucket 0")
	_step(sim)
	assert_true(sim.train.tracks(joiner), "joined")
	for slime in [joiner, mover]:
		assert_false(sim.train.is_holding(slime), "an arrival holds nothing")
	sim.train.rebuild_loads(sim.slimes)
	assert_eq(sim.train.bucket_loads().load(0), 5, "bucket 0 over its cap")
	assert_eq(_nonzero(sim), {})


# --- The switch, saves -------------------------------------------------------------

## A run of `ticks` ticks over a full bucket 1 (a size 3) with five train
## slimes hopping on their own: the state hash at its end, and the
## bucket_holds count.
func _run(on: bool, density: float, ticks: int) -> Array:
	var sim := _sim(on, density)
	_filler(sim, 500.0, 3)
	var slimes := []
	for d in [40.0, 120.0, 200.0, HOPPER_D, 330.0]:
		slimes.append(_slime(sim, d))
	_settle(sim)
	for k in slimes.size():
		sim.slimes.set_hop_timer(slimes[k], 0.2 * k)
	for i in ticks:
		_step(sim)
	return [_state(sim), sim.train.hold_counters()["bucket_holds"]]


# The switch off changes nothing: over a full bucket, the run with the cap
# off ends in the state of a run with the cap on but never binding (the
# plain hold); the cap on and binding changes it.
# @test-link [[req_platform_and_performance_targets]]
# @test-link [[req_hopping_behavior]]
func test_the_switch_off_changes_nothing() -> void:
	var off := _run(false, DENSITY, 600)
	var plain := _run(true, 1000.0, 600)
	var capped := _run(true, DENSITY, 600)
	assert_eq(off[0], plain[0], "off: the plain hold's state")
	assert_eq(off[1], 0)
	assert_gt(capped[1], 0, "on: the cap holds")
	assert_ne(capped[0], off[0], "on: another run")


# A save mid bucket-hold reloads with no new save key (the switch is the
# game's mode, set again); both runs hold on, then hop once room appears,
# their state hashes equal throughout.
# @test-link [[req_hopping_behavior]]
# @test-link [[req_persistence_and_saves]]
func test_a_save_and_reload_mid_bucket_hold_gives_the_same_state_hash() -> void:
	var sim := _sim()
	var hopper := _slime(sim, HOPPER_D)
	var filler := _filler(sim, 500.0, 3)
	_settle(sim)
	_due_step(sim, hopper)
	for i in TrainHold.HOLD_RECHECK_TICKS * 2:
		_step(sim)
	assert_true(sim.train.is_holding(hopper), "mid bucket hold")
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(sim.to_save())), OK)
	var save: Dictionary = json.data
	assert_eq(SaveData.problems(save, _level()), PackedStringArray())
	var reloaded := Simulation.from_save(save, _level(), Crowd.terrain([]))
	assert_not_null(reloaded)
	if reloaded == null:
		return
	reloaded.train.bucket_cap = true
	reloaded.train.bucket_cap_density = DENSITY
	assert_eq(_state(reloaded), _state(sim), "equal after the load")
	var runs := [sim, reloaded]
	var hops := [[], []]
	for k in 2:
		hops[k].append_array(_hops(runs[k], hopper, TrainHold.HOLD_RECHECK_TICKS * 3))
		assert_true(runs[k].train.is_holding(hopper), "still full: it holds on")
		runs[k].slimes.remove(filler)
		hops[k].append_array(_hops(runs[k], hopper, TrainHold.HOLD_RECHECK_TICKS * 2))
	assert_eq(hops[1], hops[0], "the same hops after the load")
	assert_eq(hops[0].size(), 1, "it hops once there is room")
	assert_eq(_state(reloaded), _state(sim), "equal after the hop")

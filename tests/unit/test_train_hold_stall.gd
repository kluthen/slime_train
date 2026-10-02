extends GutTest
## A held slime isn't stalling (D152, amends D118 and D151, proposed: the
## user's, 2026-10-02): on every tick a train slime holds its hop (any
## reason: a crowd or a holder in its hop corridor, a full loop bucket) or
## rests by contact with a holder, its stall clock stands still (Train.follow
## moves its stall mark, "marked_at", on by one tick). The clock runs again
## once the hold ends; a slime blocked without holding still stalls at
## Train.STALL_SECONDS. Derived from saved state (the hold in the record, the
## slime's calm), so a save mid-hold reloads to the same run.
##
## The world (as tests/unit/test_train_bucket_cap.gd's): a floor slab, its
## top at y = 0, the loop along it at a base slime's centre height from
## x = -1500 to 1500 (loop distance d is x = d - 1500), returning at y = 400.
## The bucket cap's density is 1 per 100 px: a 300 px bucket's cap is 3
## (bucket 1 holds d 300 to 600). A bucket is filled by a parked train slime
## (a filler). A walker far ahead (its hop 1000 s away) keeps the hold guard
## from firing. Fillers and the walker never move: they would stall
## themselves, so their stall mark is put far ahead (never_stall()); they
## stand for a train that moves on. The harness (_step) runs the train,
## bodies and fusion in Simulation.step's order, Offscreen aside.

const Crowd := preload("res://tests/unit/hold_crowd_support.gd")
const DT := Simulation.TICK_SECONDS
const STAND_Y := Crowd.STAND_Y
const LOOP_START_X := -1500.0
const DENSITY := 1.0
## A train slime 250 px along the loop (bucket 0): its hop lands in bucket 1.
const HOPPER_D := 250.0
const WALKER_D := 2500.0
const CROWD_COLUMNS := 8
const CROWD_ABOVE_ROWS := 4
const STALL_TICKS := int(Train.STALL_SECONDS * Simulation.TICK_RATE)
## A stall mark this far ahead never comes due in a test.
const FAR_MARK := 1 << 30
## Another species than the hopper's: touching it, it doesn't fuse.
const OTHER_SPECIES := 1


# --- The harness ---------------------------------------------------------------

func _level() -> LevelData:
	var data := LevelData.new("hold-stall", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


## A simulation (seed 5) on the world, its first slime removed, the bucket
## cap switched `on`, a walker that never stalls, and with `crowd` a crowd
## (free slimes held still) whose first column is Crowd.NEAR px past the
## hopper's spot.
func _sim(on := true, crowd := false) -> Simulation:
	var spots: Array[Vector2] = []
	if crowd:
		spots = Crowd.spots(HOPPER_D + LOOP_START_X + Crowd.NEAR, 1.0, CROWD_COLUMNS, CROWD_ABOVE_ROWS)
	var sim := Simulation.new(5)
	sim.slimes.terrain = Crowd.terrain(spots)
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.view.set_to(Vector2(-50, -50), 1.0, ScreenView.DEFAULT_SIZE)
	Crowd.place(sim.slimes, spots)
	sim.train.bucket_cap = on
	sim.train.bucket_cap_density = DENSITY
	var walker := _slime(sim, WALKER_D)
	sim.slimes.set_hop_timer(walker, 1000.0)
	_never_stall(sim, walker)
	return sim


## A base train slime of `species` standing on the floor `d` px along the
## loop, its next hop 10 s away.
func _slime(sim: Simulation, d: float, species := 0) -> int:
	var slime := sim.slimes.create(species, 1, Vector2(d + LOOP_START_X, STAND_Y), SlimeBodies.TRAIN)
	sim.slimes.set_hop_timer(slime, 10.0)
	sim.train.track(slime, d)
	return slime


## A filler: a parked size-3 train slime `d` px along the loop that never
## stalls.
func _filler(sim: Simulation, d: float) -> int:
	var lift := SlimeBodies.ring_radius_for(3) - SlimeBodies.ring_radius_for(1)
	var slime := sim.slimes.create(0, 3, Vector2(d + LOOP_START_X, STAND_Y - lift), SlimeBodies.TRAIN)
	sim.slimes.set_hop_timer(slime, 1000.0)
	sim.train.track(slime, d)
	sim.slimes.park(slime)
	_never_stall(sim, slime)
	return slime


## Puts `slime`'s stall mark far ahead: it never stalls in a test.
func _never_stall(sim: Simulation, slime: int) -> void:
	var record := sim.train.record_of(slime)
	record["marked_at"] = FAR_MARK
	sim.train.restore_record(slime, record)


## One tick in Simulation.step's order.
func _step(sim: Simulation) -> void:
	sim.train.rebuild_loads(sim.slimes)
	sim.train.steer(sim.slimes, DT, sim.tick, sim.fusion)
	sim.slimes.tick(DT)
	sim.fusion.step(sim)
	sim.train.follow(sim.slimes, sim.tick)
	sim.tick += 1


func _steps(sim: Simulation, ticks: int) -> void:
	for i in ticks:
		_step(sim)


## Settles the slimes (30 ticks), then makes `slime`'s hop due and steps
## once: it starts holding. Returns the tick its hold began.
func _start_hold(sim: Simulation, slime: int) -> int:
	_steps(sim, 30)
	sim.slimes.set_hop_timer(slime, 0.0)
	_step(sim)
	assert_true(sim.train.is_holding(slime), "it holds")
	return sim.train.hold_began_at(slime)


func _entry(slime: int, tick: int) -> Dictionary:
	return {"id": slime, "tick": tick, "reason": Train.STALLED}


## `sim`'s state as the state hash reads it, its identities aside.
func _state(sim: Simulation) -> String:
	var dump := sim.dump()
	dump.erase("identities")
	return StateHash.canonical_json(dump)


# --- Holding pauses the clock -----------------------------------------------------

# A "bucket full" holder held past 60 s isn't stalled: its clock stood still
# from its hold's first tick (its first mark at tick 0).
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_hopping_behavior]]
func test_a_bucket_holder_held_past_60_s_is_not_stalled() -> void:
	var sim := _sim()
	var hopper := _slime(sim, HOPPER_D)
	_filler(sim, 500.0)
	var began := _start_hold(sim, hopper)
	_steps(sim, STALL_TICKS + 600)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "not stalled")
	assert_eq(sim.train.hold_began_at(hopper), began, "the same hold")
	assert_eq(sim.tick - sim.train.marked_at_of(hopper), began, "its clock ran only before the hold")


# A crowd holder held past 60 s isn't stalled either, the cap on or off.
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_hopping_behavior]]
func test_a_crowd_holder_held_past_60_s_is_not_stalled_the_cap_on_or_off() -> void:
	for on in [true, false]:
		var sim := _sim(on, true)
		var hopper := _slime(sim, HOPPER_D)
		var began := _start_hold(sim, hopper)
		assert_eq(sim.train.hold_counters()["crowd_holds"], 1, "a crowd hold (cap %s)" % on)
		_steps(sim, STALL_TICKS + 600)
		assert_eq(sim.train.stalled, [] as Array[Dictionary], "not stalled (cap %s)" % on)
		assert_eq(sim.train.hold_began_at(hopper), began, "the same hold (cap %s)" % on)
		assert_eq(sim.tick - sim.train.marked_at_of(hopper), began, "paused from the hold (cap %s)" % on)


# A slime resting by contact with a holder ahead (another species, so no
# fusion) isn't stalled: its clock stands still while it rests.
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_hopping_behavior]]
func test_a_slime_resting_by_contact_with_a_holder_is_not_stalled() -> void:
	var sim := _sim()
	var hopper := _slime(sim, HOPPER_D)
	var behind := _slime(sim, HOPPER_D - 2.0 * SlimeBodies.ring_radius_for(1) - 1.0, OTHER_SPECIES)
	_filler(sim, 500.0)
	_start_hold(sim, hopper)
	assert_true(sim.slimes.touching(hopper, behind), "they touch")
	_steps(sim, STALL_TICKS + 600)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "neither stalled")
	assert_false(sim.train.is_holding(behind), "it doesn't hold")
	assert_eq(sim.slimes.calm_of(behind), SlimeBodies.RESTING, "it rests by contact")
	assert_lt(sim.tick - sim.train.marked_at_of(behind), 120, "its clock ran only until it rested")


# --- The clock runs again ------------------------------------------------------------

# Once the bucket has room, the holder's hold ends at its next check; it
# can't hop (no auto hops), so it stands still and stalls 60 s of clock
# after its first mark: its tick count minus the paused ticks (the hold's).
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_hopping_behavior]]
func test_once_the_hold_ends_the_clock_runs_again() -> void:
	var sim := _sim()
	var hopper := _slime(sim, HOPPER_D)
	var filler := _filler(sim, 500.0)
	var began := _start_hold(sim, hopper)
	_steps(sim, 1200)
	sim.slimes.remove(filler)
	sim.slimes.auto_hops = false
	var ended := -1
	for i in 2 * TrainHold.HOLD_RECHECK_TICKS:
		var tick := sim.tick
		_step(sim)
		if not sim.train.is_holding(hopper):
			ended = tick
			break
	assert_gt(ended, 0, "room: its hold ended at a check")
	var due := ended - began + STALL_TICKS
	_steps(sim, due - sim.tick)
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "not before 60 s of clock")
	_step(sim)
	assert_eq(sim.train.stalled, [_entry(hopper, due)] as Array[Dictionary], "stalled after 60 s of clock")


# A slime blocked without holding (it can't hop, nothing in its way) still
# stalls at 60 s, the cap on or off.
# @test-link [[rule_stalled_train_slime_moved_to_start]]
func test_a_slime_blocked_without_holding_still_stalls_at_60_s() -> void:
	for on in [true, false]:
		var sim := _sim(on)
		sim.slimes.auto_hops = false
		var slime := _slime(sim, HOPPER_D)
		sim.slimes.set_hop_timer(slime, 0.0)
		var held := false
		for i in STALL_TICKS:
			_step(sim)
			held = held or sim.train.is_holding(slime)
		assert_false(held, "never held (cap %s)" % on)
		assert_eq(sim.train.stalled, [] as Array[Dictionary], "not yet (cap %s)" % on)
		_step(sim)
		assert_eq(sim.train.stalled, [_entry(slime, STALL_TICKS)] as Array[Dictionary], "stalled (cap %s)" % on)


# --- Saves ------------------------------------------------------------------------

# A save mid-hold (a bucket holder and a slime resting by contact behind it)
# reloads with no new save key; both runs pause the same, their state
# hashes equal throughout, neither stalls past 60 s.
# @test-link [[rule_stalled_train_slime_moved_to_start]]
# @test-link [[req_persistence_and_saves]]
func test_a_save_and_reload_mid_hold_gives_the_same_state_hash() -> void:
	var sim := _sim()
	var hopper := _slime(sim, HOPPER_D)
	_slime(sim, HOPPER_D - 2.0 * SlimeBodies.ring_radius_for(1) - 1.0, OTHER_SPECIES)
	_filler(sim, 500.0)
	_start_hold(sim, hopper)
	_steps(sim, 1200)
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
	for run in [sim, reloaded]:
		_steps(run, STALL_TICKS)
		assert_eq(run.train.stalled, [] as Array[Dictionary], "not stalled")
	assert_eq(_state(reloaded), _state(sim), "equal 60 s on")

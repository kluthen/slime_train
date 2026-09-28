extends GutTest
## Sleepers (src/sim/sleepers.gd) through the Simulation: a fresh level
## places every sleeper as a sleeping body with its stable ID; sleepers never
## hop or move, but other slimes rest on them and bump into them; only a free
## slime touching a sleeper, both on screen, wakes it (train slimes never do);
## the woken slime is free, unsure, then heads back and rejoins the train; a
## tap on a sleeper is a call centred on its body, wherever the body is.
##
## The synthetic world: a floor whose top is at y = 0 from x = -2000 to 2000;
## the loop runs along it at a base slime's centre height (y = -24) from
## x = -1500 to 1500 and returns under the floor. A ledge (top y = -150, x 300
## to 500) is in no branch. The first slime starts at x = -1000; one sleeper
## rests on the ledge, one on the floor past the loop's end (x = -1800).

# @test-link [[req_waking_sleepers]]
# @test-link [[req_slime_states]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const FIRST_ID := "t.first-slime"
const LEDGE_ID := "t.sleeper.01"
const FLOOR_ID := "t.sleeper.02"
const LEDGE_SPOT := Vector2(400, -174)
const FLOOR_SPOT := Vector2(-1800, -24)
const FIRST_SPOT := Vector2(-1000, -24)
## Centre to centre, two base slimes this far apart touch without pushing.
const TOUCH_GAP := 43.0


func _level() -> LevelData:
	var data := LevelData.new("sleepers", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": FIRST_ID, "species": "A", "position": FIRST_SPOT}
	# Out of stable ID order on purpose: they are placed sorted.
	data.add_sleeper(LEDGE_ID, "B", LEDGE_SPOT)
	data.add_sleeper(FLOOR_ID, "C", FLOOR_SPOT)
	for id in [LEDGE_ID, FLOOR_ID]:
		var spot: Vector2 = data.sleepers[id]["position"]
		data.add_tap_target(id, TapDispatcher.KIND_SLEEPER, Rect2(spot - Vector2(21, 21), Vector2(42, 42)))
	return data


func _sim(master_seed := 13) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = TerrainSegments.new([
		Support.floor_polygon(),
		PackedVector2Array([Vector2(300, -150), Vector2(500, -150), Vector2(500, -110), Vector2(300, -110)]),
	])
	sim.load_level(_level())
	_look_at(sim, LEDGE_SPOT)
	return sim


func _look_at(sim: Simulation, world: Vector2) -> void:
	sim.view.set_to(world, 1.0, ScreenView.DEFAULT_SIZE)


## The runtime id of the slime whose stable ID is `stable_id`, or -1.
func _slime(sim: Simulation, stable_id: String) -> int:
	for slime_id in sim.slimes.ids():
		if stable_id in sim.identities.members_of(slime_id):
			return slime_id
	return -1


func _tap(sim: Simulation, world: Vector2) -> void:
	var at := sim.view.world_to_screen(world)
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()


func test_a_fresh_level_places_every_sleeper_asleep_with_its_stable_id() -> void:
	var sim := _sim()
	assert_eq(sim.slimes.slime_count, 3, "the first slime and two sleepers")
	var first := _slime(sim, FIRST_ID)
	assert_eq(first, sim.slimes.ids()[0], "the first slime comes first")
	assert_eq(sim.slimes.state_of(first), SlimeBodies.TRAIN)
	var ledge := _slime(sim, LEDGE_ID)
	var floor_sleeper := _slime(sim, FLOOR_ID)
	assert_lt(ledge, floor_sleeper, "placed in stable ID order")
	for pair in [[ledge, LEDGE_SPOT, "B"], [floor_sleeper, FLOOR_SPOT, "C"]]:
		var slime: int = pair[0]
		assert_eq(sim.slimes.state_of(slime), SlimeBodies.SLEEPER)
		assert_eq(sim.slimes.size_of(slime), 1)
		assert_eq(sim.slimes.species_of(slime), Species.from_letter(pair[2]))
		assert_eq(sim.slimes.centre_of(slime), pair[1], "at its marker")
		assert_eq(sim.identities.members_of(slime).size(), 1)
		assert_false(sim.train.tracks(slime), "not on the train")
		assert_false(sim.free_slimes.tracks(slime), "not free")


func test_a_restored_save_keeps_its_sleepers_and_places_no_more() -> void:
	var sim := _sim()
	sim.run(30)
	var again := Simulation.from_save(sim.to_save(), _level(), sim.slimes.terrain)
	assert_eq(again.slimes.slime_count, 3)
	assert_eq(again.slimes.state_of(_slime(again, LEDGE_ID)), SlimeBodies.SLEEPER)
	assert_eq(again.state_hash(), sim.state_hash())


func test_a_sleeper_never_hops_or_moves() -> void:
	var sim := _sim()
	var sleepers := [_slime(sim, LEDGE_ID), _slime(sim, FLOOR_ID)]
	var points := {}
	var timers := {}
	for slime in sleepers:
		points[slime] = sim.slimes.points_of(slime)
		timers[slime] = sim.slimes.hop_timer_of(slime)
	var hops := 0
	for i in 600:
		sim.step()
		for slime in sleepers:
			if slime in sim.slimes.hopped:
				hops += 1
	assert_eq(hops, 0, "no hop")
	for slime in sleepers:
		assert_eq(sim.slimes.state_of(slime), SlimeBodies.SLEEPER)
		assert_eq(sim.slimes.points_of(slime), points[slime], "not a point moved")
		assert_eq(sim.slimes.hop_timer_of(slime), timers[slime], "its hop timer waits")
		assert_eq(sim.slimes.velocity_of(slime), Vector2.ZERO)
	assert_gt(sim.slimes.centre_of(sim.slimes.ids()[0]).x, FIRST_SPOT.x + 100.0,
			"meanwhile the first slime went on")


func test_a_slime_landing_on_a_sleeper_rests_on_it_and_leaves_it_in_place() -> void:
	var sim := _sim()
	_look_at(sim, Vector2(0, -1500))  # off screen: nothing wakes
	var sleeper := _slime(sim, FLOOR_ID)
	var falling := sim.slimes.create(0, 1, FLOOR_SPOT + Vector2(0, -120), SlimeBodies.BEDTIME_ASLEEP)
	var points := sim.slimes.points_of(sleeper)
	sim.run(120)
	var gap := sim.slimes.centre_of(falling).distance_to(FLOOR_SPOT)
	assert_gt(gap, 2.0 * SlimeBodies.RING_RADIUS_SIZE_1 - 4.0, "it didn't sink into the sleeper")
	assert_eq(sim.slimes.points_of(sleeper), points, "the sleeper didn't move")
	assert_eq(sim.slimes.state_of(sleeper), SlimeBodies.SLEEPER)


func test_a_train_slime_touching_a_sleeper_does_not_wake_it() -> void:
	var sim := _sim()
	_look_at(sim, FLOOR_SPOT)
	var sleeper := _slime(sim, FLOOR_ID)
	# Left of the sleeper: the train steers it right, into the sleeper.
	var slime := sim.slimes.create(0, 1, FLOOR_SPOT - Vector2(TOUCH_GAP, 0), SlimeBodies.TRAIN)
	var touches := 0
	for i in 240:
		sim.step()
		if sim.slimes.touching(slime, sleeper):
			touches += 1
	assert_gt(touches, 0, "they touched")
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN)
	assert_eq(sim.slimes.state_of(sleeper), SlimeBodies.SLEEPER, "still asleep")
	assert_eq(sim.slimes.centre_of(sleeper), FLOOR_SPOT, "and in place")


func test_a_free_slime_touching_a_sleeper_on_screen_wakes_it() -> void:
	var sim := _sim()
	var sleeper := _slime(sim, LEDGE_ID)
	var slime := sim.slimes.create(0, 1, LEDGE_SPOT - Vector2(TOUCH_GAP, 0), SlimeBodies.FREE)
	var tick := sim.tick
	sim.step()
	assert_true(sim.slimes.touching(slime, sleeper))
	assert_eq(sim.slimes.state_of(sleeper), SlimeBodies.FREE, "awake and free")
	assert_eq(sim.free_slimes.phase_of(sleeper), FreeSlimes.UNSURE)
	assert_eq(sim.free_slimes.phase_since(sleeper), tick)
	assert_lt(sim.free_slimes.point_of(sleeper).distance_to(LEDGE_SPOT), 1.0, "unsure where it woke")
	assert_eq(sim.identities.members_of(sleeper), PackedStringArray([LEDGE_ID]), "it keeps its stable ID")


func test_a_free_slime_touching_a_sleeper_off_screen_does_not_wake_it() -> void:
	var sim := _sim()
	_look_at(sim, Vector2(0, -1500))
	var sleeper := _slime(sim, LEDGE_ID)
	var slime := sim.slimes.create(0, 1, LEDGE_SPOT - Vector2(TOUCH_GAP, 0), SlimeBodies.FREE)
	var touches := 0
	for i in 60:
		sim.step()
		if sim.slimes.touching(slime, sleeper):
			touches += 1
	assert_gt(touches, 0, "they touched")
	assert_eq(sim.slimes.state_of(sleeper), SlimeBodies.SLEEPER, "still asleep")


func test_both_must_be_on_screen() -> void:
	var sim := _sim()
	# The view's right edge at x = 370: the free slime shows, the sleeper
	# (its ring from x = 379) doesn't.
	_look_at(sim, Vector2(370.0 - ScreenView.DEFAULT_SIZE.x * 0.5, LEDGE_SPOT.y))
	var sleeper := _slime(sim, LEDGE_ID)
	var slime := sim.slimes.create(0, 1, LEDGE_SPOT - Vector2(TOUCH_GAP, 0), SlimeBodies.FREE)
	sim.step()
	assert_true(sim.slimes.touching(slime, sleeper))
	assert_eq(sim.slimes.state_of(sleeper), SlimeBodies.SLEEPER, "the sleeper is off screen")


func test_the_woken_slime_is_unsure_then_heads_back_and_rejoins_the_train() -> void:
	var sim := _sim()
	var sleeper := _slime(sim, LEDGE_ID)
	sim.slimes.create(0, 1, LEDGE_SPOT - Vector2(TOUCH_GAP, 0), SlimeBodies.FREE)
	sim.step()
	var woke := sim.tick - 1
	assert_eq(sim.free_slimes.phase_of(sleeper), FreeSlimes.UNSURE)
	var unsure_ticks := int(FreeSlimes.UNSURE_SECONDS * Simulation.TICK_RATE)
	sim.run(unsure_ticks - 1)
	assert_eq(sim.free_slimes.phase_of(sleeper), FreeSlimes.UNSURE, "unsure for 15 s")
	assert_lt(absf(sim.slimes.centre_of(sleeper).x - LEDGE_SPOT.x), FreeSlimes.UNSURE_RANGE + 60.0,
			"near where it woke")
	sim.step()
	assert_eq(sim.free_slimes.phase_of(sleeper), FreeSlimes.HEADING_BACK)
	assert_eq(sim.free_slimes.phase_since(sleeper), woke + unsure_ticks)
	var rejoined := false
	for i in 40 * Simulation.TICK_RATE:
		sim.step()
		if sim.slimes.state_of(sleeper) == SlimeBodies.TRAIN:
			rejoined = true
			break
	assert_true(rejoined, "it rejoined the train")
	assert_true(sim.train.tracks(sleeper))


func test_a_tap_on_a_sleeper_calls_to_its_body_wherever_it_is() -> void:
	var sim := _sim()
	var sleeper := _slime(sim, LEDGE_ID)
	# Move the body 60 px up (as a save could have it): the tap box follows.
	var moved := LEDGE_SPOT + Vector2(0, -60)
	var body := sim.slimes.body_of(sleeper)
	var points: PackedVector2Array = body["points"]
	for k in points.size():
		points[k] += Vector2(0, -60)
	body["points"] = points
	body["previous"] = points
	body["centre"] = moved
	assert_true(sim.slimes.set_body(sleeper, body))
	_tap(sim, moved + Vector2(5, 3))
	var tap: Dictionary = sim.taps[-1]
	assert_eq(tap["object"], LEDGE_ID)
	assert_eq(tap["kind"], TapDispatcher.KIND_SLEEPER)
	assert_true(tap["call"])
	assert_eq(sim.free_slimes.call_point, moved, "the call is centred on its body")
	_tap(sim, LEDGE_SPOT + Vector2(0, 30))
	assert_eq(sim.taps[-1]["object"], "", "its marker's place is open ground now")


func test_a_woken_sleeper_is_no_longer_a_tap_target() -> void:
	var sim := _sim()
	var sleeper := _slime(sim, LEDGE_ID)
	sim.slimes.create(0, 1, LEDGE_SPOT - Vector2(TOUCH_GAP, 0), SlimeBodies.FREE)
	sim.step()
	assert_eq(sim.slimes.state_of(sleeper), SlimeBodies.FREE)
	_tap(sim, sim.slimes.centre_of(sleeper))
	assert_eq(sim.taps[-1]["object"], "", "a tap on it is a call on open ground")
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_GROUND)


func test_waking_is_deterministic() -> void:
	var hashes := []
	for run in 2:
		var sim := _sim(21)
		sim.slimes.create(0, 1, LEDGE_SPOT - Vector2(TOUCH_GAP, 0), SlimeBodies.FREE)
		sim.run(1200)
		hashes.append(sim.state_hash())
	assert_eq(hashes[0], hashes[1])

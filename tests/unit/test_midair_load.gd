extends GutTest
## The mid-air rule on load (src/sim/midair_landing.gd, called at the end of
## SaveData.restore; master spec §5.10, D12, DoD 28): a slime saved in the
## air is put straight down on the first surface below it, at rest and
## supported; with no surface below it, it is lost (to the loop start, in the
## lost log). Sleepers, slimes in a basket and parked slimes are left where
## they are, and slimes on the ground are untouched.
##
## The world: a floor whose top is at y = 0 from x -2000 to 2000, a loop along
## it starting at x -1500.

# @test-link [[req_persistence_and_saves]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const LEVEL_ID := "midair"
const LEVEL_VERSION := 1
## Well above the floor: a slime this high is really in the air.
const HIGH := 20.0


func _level() -> LevelData:
	var data := LevelData.new(LEVEL_ID, LEVEL_VERSION)
	var loop := LoopData.new("m.loop")
	loop.add_segment("m.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("m.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]))
	data.loop = loop
	data.first_slime = {"id": "start.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


func _terrain() -> TerrainSegments:
	return TerrainSegments.new([Support.floor_polygon()])


## A simulation with the first slime and a size-2 train slime, run until
## both have settled on the floor.
func _settled() -> Simulation:
	var sim := Simulation.new(7)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	sim.view.set_to(Vector2(0, -200), 1.0, ScreenView.DEFAULT_SIZE)
	sim.spawn_train_slime(2, 2, 600.0)
	sim.slimes.auto_hops = false
	sim.run(120)
	return sim


func _reloaded(save: Dictionary) -> Simulation:
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(save)), OK)
	assert_eq(SaveData.problems(json.data, _level()), PackedStringArray())
	return Simulation.from_save(json.data, _level(), _terrain())


static func _lowest(points: PackedVector2Array) -> float:
	var low := -INF
	for p in points:
		low = maxf(low, p.y)
	return low


## Steps `sim` until slime `slime_id` is in the air (unsupported, its lowest
## point HIGH above the floor), at most `ticks` ticks. True when it is.
func _until_airborne(sim: Simulation, slime_id: int, ticks: int) -> bool:
	for i in ticks:
		sim.step()
		var body := sim.slimes.body_of(slime_id)
		if not body["supported"] and _lowest(body["points"]) < -HIGH:
			return true
	return false


## Moves slime `slime_id` by `shift` and marks it in the air (unsupported).
func _lift(sim: Simulation, slime_id: int, shift: Vector2) -> void:
	var body := sim.slimes.body_of(slime_id)
	var points: PackedVector2Array = body["points"]
	for k in points.size():
		points[k] += shift
	body["points"] = points
	body["previous"] = points.duplicate()
	body["centre"] = body["centre"] + shift
	body["supported"] = false
	sim.slimes.set_body(slime_id, body)


## Slime `slime_id`'s points, previous points and support are the same in
## `reloaded` as in `sim`.
func _assert_same_body(reloaded: Simulation, sim: Simulation, slime_id: int, label: String) -> void:
	var body := reloaded.slimes.body_of(slime_id)
	var was := sim.slimes.body_of(slime_id)
	for key in ["points", "previous", "supported"]:
		assert_eq(body[key], was[key], "%s: %s" % [label, key])


# --- Grounded ------------------------------------------------------------------

func test_a_slime_saved_mid_hop_is_put_on_the_ground_at_rest() -> void:
	var sim := _settled()
	var hopper := 2
	assert_true(sim.slimes.hop(hopper, Vector2.UP, 1.0), "a settled slime can hop")
	assert_true(_until_airborne(sim, hopper, 30), "captured in the air")
	var saved := sim.slimes.body_of(hopper)
	var reloaded := _reloaded(sim.to_save())
	assert_not_null(reloaded)
	if reloaded == null:
		return
	var body := reloaded.slimes.body_of(hopper)
	assert_true(body["supported"], "on the ground")
	assert_eq(body["previous"], body["points"], "at rest: no velocity")
	assert_almost_eq(_lowest(body["points"]), -reloaded.slimes.terrain_skin, 0.001,
			"its lowest point rests on the floor")
	var shift: Vector2 = body["centre"] - saved["centre"]
	assert_almost_eq(shift.x, 0.0, 0.0001, "straight down")
	assert_gt(shift.y, HIGH - reloaded.slimes.terrain_skin, "moved down")
	assert_eq(reloaded.slimes.species_of(hopper), 2)
	assert_eq(reloaded.slimes.size_of(hopper), 2)
	assert_eq(reloaded.slimes.state_of(hopper), SlimeBodies.TRAIN)
	assert_eq(reloaded.offscreen.lost, [], "nobody lost")


func test_slimes_on_the_ground_are_untouched() -> void:
	var sim := _settled()
	var hopper := 2
	sim.slimes.hop(hopper, Vector2.UP, 1.0)
	assert_true(_until_airborne(sim, hopper, 30))
	assert_true(sim.slimes.body_of(1)["supported"], "the first slime is on the ground")
	var reloaded := _reloaded(sim.to_save())
	_assert_same_body(reloaded, sim, 1, "the first slime's body as saved")


func test_a_save_with_every_slime_on_the_ground_reloads_exactly() -> void:
	var sim := _settled()
	for slime_id in sim.slimes.ids():
		assert_true(sim.slimes.body_of(slime_id)["supported"])
	var reloaded := _reloaded(sim.to_save())
	assert_eq(reloaded.state_hash(), sim.state_hash())


func test_a_slime_in_the_air_above_another_lands_on_it() -> void:
	var sim := _settled()
	var below := sim.spawn_train_slime(3, 1, 1000.0)
	var above := sim.spawn_train_slime(3, 1, 1300.0)
	sim.run(90)
	var x := sim.slimes.centre_of(below).x
	_lift(sim, above, Vector2(x - sim.slimes.centre_of(above).x, -200.0))
	var reloaded := _reloaded(sim.to_save())
	var top := INF
	for p in reloaded.slimes.points_of(below):
		top = minf(top, p.y)
	var body := reloaded.slimes.body_of(above)
	assert_true(body["supported"])
	assert_lt(_lowest(body["points"]), top + 1.0, "on top of the slime below, not through it")
	assert_gt(_lowest(body["points"]), top - 2.0 * SlimeBodies.ring_radius_for(1), "resting on it")
	_assert_same_body(reloaded, sim, below, "the slime below untouched")


func test_sleepers_and_slimes_in_a_basket_stay_where_they_were() -> void:
	var sim := _settled()
	var sleeper := sim.spawn_train_slime(1, 1, 900.0)
	var basket := sim.spawn_train_slime(1, 1, 1200.0)
	sim.slimes.set_state(sleeper, SlimeBodies.SLEEPER)
	sim.slimes.set_state(basket, SlimeBodies.IN_BASKET)
	_lift(sim, sleeper, Vector2(0, -300))
	_lift(sim, basket, Vector2(0, -300))
	var reloaded := _reloaded(sim.to_save())
	assert_eq(reloaded.slimes.points_of(sleeper), sim.slimes.points_of(sleeper))
	assert_eq(reloaded.slimes.points_of(basket), sim.slimes.points_of(basket))


func test_a_parked_slime_stays_where_it_was() -> void:
	var sim := _settled()
	var parked := sim.spawn_train_slime(1, 1, 1200.0)
	sim.slimes.set_state(parked, SlimeBodies.FREE)
	_lift(sim, parked, Vector2(0, -300))
	sim.slimes.park(parked)
	var reloaded := _reloaded(sim.to_save())
	assert_true(reloaded.slimes.is_parked(parked), "still parked")
	assert_eq(reloaded.slimes.points_of(parked), sim.slimes.points_of(parked),
			"left where Offscreen put it: it falls once simulated again")


# --- Lost ------------------------------------------------------------------------

func test_a_slime_in_the_air_over_nothing_is_lost() -> void:
	var sim := _settled()
	var hopper := 2
	_lift(sim, hopper, Vector2(2600.0 - sim.slimes.centre_of(hopper).x, -200.0))
	var reloaded := _reloaded(sim.to_save())
	assert_not_null(reloaded)
	if reloaded == null:
		return
	assert_eq(reloaded.offscreen.lost.size(), 1, "logged as lost")
	if reloaded.offscreen.lost.size() == 1:
		assert_eq(reloaded.offscreen.lost[0]["id"], hopper)
		assert_eq(reloaded.offscreen.lost[0]["reason"], Offscreen.LOST)
	assert_eq(reloaded.slimes.state_of(hopper), SlimeBodies.TRAIN, "back on the train")
	var start := reloaded.train.position_at(reloaded.train.distance_of(hopper))
	assert_lt(reloaded.slimes.centre_of(hopper).distance_to(start), SlimeBodies.ring_radius_for(2) + 1.0,
			"at the loop start")
	assert_lt(reloaded.train.distance_of(hopper), LoopStart.SPOTS * 2.0 * (SlimeBodies.ring_radius_for(2) + SlimeBodies.EDGE))


# --- Deterministic -----------------------------------------------------------------

func test_restoring_a_mid_air_save_twice_gives_the_same_state() -> void:
	var sim := _settled()
	sim.slimes.hop(2, Vector2(0.3, -1.0), 1.0)
	assert_true(_until_airborne(sim, 2, 30))
	_lift(sim, 1, Vector2(4000.0, -100.0))
	var save := sim.to_save()
	var a := _reloaded(save)
	var b := _reloaded(save)
	assert_eq(a.state_hash(), b.state_hash())
	assert_eq(a.offscreen.lost.size(), 1, "the slime over nothing is lost")
	a.run(120)
	b.run(120)
	assert_eq(a.state_hash(), b.state_hash())


func test_a_reloaded_mid_air_save_reloads_exactly_after_that() -> void:
	var sim := _settled()
	sim.slimes.hop(2, Vector2.UP, 1.0)
	assert_true(_until_airborne(sim, 2, 30))
	var once := _reloaded(sim.to_save())
	var twice := _reloaded(once.to_save())
	assert_eq(twice.state_hash(), once.state_hash(), "nobody left in the air to put down")

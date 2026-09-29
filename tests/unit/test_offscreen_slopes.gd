extends GutTest
## Offscreen (src/sim/offscreen.gd): parked train slimes on sloped stretches
## of the loop. A parked size-2 or size-3 slime keeps the off-screen pace down
## a slope and up one (it used to stop on a downhill stretch, lifted straight
## up, and be lost as stalled after 60 s), rides lifted along the loop's
## normal like a slime resting on the slope, and laps the whole loop, every
## corner included, without being lost.
##
## The world: the loop runs at a base slime's centre height (24 px above the
## ground) from (-5000, -24), flat to x -2000, down a 1-in-5 slope to
## (0, 376), flat to x 2000, up a 1-in-5 slope to (4000, -24) and flat to
## x 5000; it returns down a chute to y 800, back under everything and up to
## the start (a slide). The ground follows the outgoing part.
# @test-link [[req_offscreen_simulation]]
# @test-link [[rule_left_alone_and_lost]]

const DOWN_FROM := Vector2(-2000, -24)
const DOWN_TO := Vector2(0, 376)
const UP_FROM := Vector2(2000, 376)
const UP_TO := Vector2(4000, -24)
## Far above the level: nothing comes near the view.
const AWAY := Vector2(0, -5000)
## One lap, with room: the outgoing part at the pace, the slide at its speed.
const LAP_TICKS := 60 * 200


func _level() -> LevelData:
	var data := LevelData.new("offscreen-slopes", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-5000, -24), DOWN_FROM, DOWN_TO, UP_FROM, UP_TO, Vector2(5000, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(5000, -24), Vector2(5000, 800), Vector2(-5000, 800), Vector2(-5000, -24)]))
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-4900, -24)}
	return data


func _terrain() -> TerrainSegments:
	return TerrainSegments.new([PackedVector2Array([
		Vector2(-6000, 0), Vector2(-2000, 0), Vector2(0, 400), Vector2(2000, 400), Vector2(4000, 0),
		Vector2(6000, 0), Vector2(6000, 600), Vector2(-6000, 600)])])


## A simulation on the level, off-screen simulation on, the view far away
## (the first slime is removed: tests place their own).
func _sim() -> Simulation:
	var sim := Simulation.new(5)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.offscreen.enabled = true
	sim.view.set_to(AWAY, 1.0, ScreenView.DEFAULT_SIZE)
	return sim


## The distance along the loop of `point`, on the outgoing part.
func _distance_at(sim: Simulation, point: Vector2) -> float:
	return sim.level.loop.closest(point, sim.train.open_gates)["distance"]


## Checks that parked slimes of sizes 2 and 3 placed 300 px along the
## stretch starting at `from` move 2 s at their pace along it.
func _check_pace_from(from: Vector2, label: String) -> void:
	var sim := _sim()
	var start := _distance_at(sim, from) + 300.0
	var slimes := {2: sim.spawn_train_slime(0, 2, start), 3: sim.spawn_train_slime(1, 3, start + 200.0)}
	sim.run(1)
	var before := {}
	for size in slimes:
		assert_true(sim.slimes.is_parked(slimes[size]), "%s: size %d parked" % [label, size])
		before[size] = sim.train.progress_of(slimes[size])
	sim.run(120)
	for size in slimes:
		var moved: float = sim.train.progress_of(slimes[size]) - before[size]
		assert_almost_eq(moved, Offscreen.pace(size) * 2.0, 1.0, "%s: size %d, 2 s at the pace" % [label, size])
	assert_eq(sim.train.lost, [] as Array[Dictionary], "%s: none lost" % label)


func test_a_parked_train_slime_keeps_the_pace_down_a_slope() -> void:
	_check_pace_from(DOWN_FROM, "down")


func test_a_parked_train_slime_keeps_the_pace_up_a_slope() -> void:
	_check_pace_from(UP_FROM, "up")


func test_on_a_slope_it_is_lifted_along_the_loops_normal() -> void:
	var sim := _sim()
	var slime := sim.spawn_train_slime(0, 3, _distance_at(sim, DOWN_FROM) + 300.0)
	sim.run(60)
	assert_true(sim.slimes.is_parked(slime))
	var distance := sim.train.distance_of(slime)
	var on := sim.train.position_at(distance)
	var lifted := sim.slimes.centre_of(slime) - on
	assert_almost_eq(lifted.length(), Offscreen.lift(3), 0.01, "its size's lift away from the loop")
	assert_almost_eq(lifted.dot(sim.train.direction_at(distance)), 0.0, 0.01, "square to the loop")
	assert_lt(lifted.y, 0.0, "on the upper side")


func test_parked_slimes_of_sizes_2_and_3_lap_the_loop_and_are_never_lost() -> void:
	var sim := _sim()
	var start := _distance_at(sim, DOWN_FROM) - 100.0
	var slimes := [sim.spawn_train_slime(0, 2, start), sim.spawn_train_slime(1, 3, start - 200.0)]
	sim.run(LAP_TICKS)
	for slime_id in slimes:
		assert_true(sim.slimes.is_parked(slime_id), "%d still parked" % slime_id)
		assert_eq(sim.train.laps_of(slime_id), 1, "%d went round the loop" % slime_id)
	assert_eq(sim.train.lost, [] as Array[Dictionary], "no stall at any corner")

extends GutTest
## Offscreen (src/sim/offscreen.gd): parked train slimes keep single file
## along the loop. A parked train slime never moves closer than the two
## slimes' widths (ring radius plus the drawn edge, each) behind the train
## slime ahead of it, parked or not: it waits there, as a slime on screen
## would bump into it. Without this, a parked slime going faster (the slide's
## speed, or a bigger slime's pace) ran through the slime ahead, and the two
## came back on screen on one spot; two rings on one spot never came apart
## and crawled, blocking the train behind them until a slime stalled (found
## by the whole-level DoD 1 test from `gate1-open`, chunk 16).
##
## The world: a floor whose top is at y = 0 from x = -6000 to 6000. The loop
## runs along it at a base slime's centre height (y = -24) from x = -5000 to
## 5000 and returns under the floor (y = 400) to its start, a slide.
# @test-link [[req_offscreen_simulation]]
# @test-link [[rule_loop_travelable_with_no_input]]

## Far above the level: nothing comes near the view.
const AWAY := Vector2(0, -5000)
## On the view's centre line, the loop's height.
const VIEW_Y := -200.0


func _level() -> LevelData:
	var data := LevelData.new("offscreen-single-file", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-5000, -24), Vector2(5000, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(5000, -24), Vector2(5000, 400), Vector2(-5000, 400), Vector2(-5000, -24)]))
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-4900, -24)}
	return data


func _terrain() -> TerrainSegments:
	return TerrainSegments.new([
		PackedVector2Array([Vector2(-6000, 0), Vector2(6000, 0), Vector2(6000, 300), Vector2(-6000, 300)])])


## A simulation on the level, off-screen simulation on, the view on `look`
## (the first slime is removed: tests place their own).
func _sim(look := AWAY) -> Simulation:
	var sim := Simulation.new(5)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.offscreen.enabled = true
	sim.view.set_to(look, 1.0, ScreenView.DEFAULT_SIZE)
	return sim


## The room two train slimes of sizes `a` and `b` keep along the loop, px.
static func _spacing(a: int, b: int) -> float:
	return SlimeBodies.ring_radius_for(a) + SlimeBodies.ring_radius_for(b) + 2.0 * SlimeBodies.EDGE


## How far `ahead` is in front of `behind` along the loop, px (0 to the
## loop's length).
static func _gap(sim: Simulation, behind: int, ahead: int) -> float:
	return fposmod(sim.train.distance_of(ahead) - sim.train.distance_of(behind), sim.train.length())


## Runs `ticks` ticks and checks after each that `behind` stays at least
## `room` behind `ahead` (it never catches up or passes it). Returns the
## smallest gap seen.
func _run_keeping_order(sim: Simulation, behind: int, ahead: int, room: float, ticks: int) -> float:
	var smallest := INF
	for t in ticks:
		sim.run(1)
		var gap := _gap(sim, behind, ahead)
		smallest = minf(smallest, gap)
		if gap < room - 0.01 or gap > sim.train.length() * 0.5:
			assert_true(false, "tick %d: slime %d is %.2f px behind slime %d (at least %.2f wanted)"
					% [sim.tick, behind, gap, ahead, room])
			return smallest
	return smallest


func test_a_parked_slime_on_the_slide_waits_behind_the_parked_slime_ahead() -> void:
	var sim := _sim()
	# The single file across the loop's end, the geyser off (EXPERIMENT,
	# exp/geyser): with it, the one behind, wrapping past the loop's end, is
	# put on a free spot 150 to 700 px along the loop on purpose, ahead of
	# the one ahead (tests/unit/test_geyser.gd covers that placement).
	sim.geyser.enabled = false
	var length := sim.train.length()
	# The one behind comes off the slide (at the slide's speed) 0.28 s later,
	# when the one ahead is only about 24 px into the outgoing part.
	var ahead := sim.spawn_train_slime(0, 1, 5.0)
	var behind := sim.spawn_train_slime(1, 1, length - 100.0)
	sim.run(1)
	assert_true(sim.slimes.is_parked(ahead) and sim.slimes.is_parked(behind), "both parked")
	var smallest := _run_keeping_order(sim, behind, ahead, _spacing(1, 1), 300)
	# From the start-of-tick distances: the gap is the widths plus the step the
	# one ahead makes in a tick.
	assert_almost_eq(smallest, _spacing(1, 1), 2.0, "it caught up at the slide's speed and waits a width behind")
	assert_eq(sim.train.stalled, [] as Array[Dictionary])


func test_a_bigger_parked_slime_waits_behind_a_smaller_one() -> void:
	var sim := _sim()
	var ahead := sim.spawn_train_slime(0, 1, 1200.0)
	var big := sim.spawn_train_slime(1, 3, 1200.0 - _spacing(1, 3) - 40.0)
	sim.run(1)
	var start := sim.train.progress_of(ahead)
	# pace(3) - pace(1) is about 5 px/s: 40 px closed in about 8 s.
	_run_keeping_order(sim, big, ahead, _spacing(1, 3), 20 * 60)
	assert_almost_eq(_gap(sim, big, ahead), _spacing(1, 3), 2.0, "it waits right behind")
	assert_almost_eq(sim.train.progress_of(ahead) - start, Offscreen.pace(1) * 20.0, 1.0,
			"the slime ahead keeps its own pace")


func test_two_parked_slimes_on_one_spot_come_apart_in_single_file() -> void:
	var sim := _sim()
	var first := sim.spawn_train_slime(0, 1, 2000.0)
	var second := sim.spawn_train_slime(1, 1, 2000.0)
	sim.run(120)
	assert_gte(_gap(sim, first, second), _spacing(1, 1) - 0.01,
			"the higher id goes on, the lower waits until there is room")
	assert_lt(_gap(sim, first, second), sim.train.length() * 0.5)


func test_a_parked_slime_waits_behind_a_simulated_slime_between_the_margins() -> void:
	# The view's left edge is 330 px right of the held slime: between the
	# margins, so it stays simulated (it was on screen first); the parked one
	# comes from 1000 px further left and never gets near enough to be
	# simulated again before it reaches it.
	var held_x := -2000.0
	var half := ScreenView.DEFAULT_SIZE.x * 0.5
	var sim := _sim(Vector2(held_x + half, VIEW_Y))
	var held := sim.spawn_train_slime(0, 1, held_x + 5000.0)
	sim.run(1)
	assert_false(sim.slimes.is_parked(held), "on screen, simulated")
	sim.slimes.set_hop_held(held, true)
	sim.view.set_to(Vector2(held_x + 330.0 + half, VIEW_Y), 1.0, ScreenView.DEFAULT_SIZE)
	var behind := sim.spawn_train_slime(1, 1, held_x + 5000.0 - 700.0)
	sim.run(1)
	assert_false(sim.slimes.is_parked(held), "between the margins, still simulated")
	assert_true(sim.slimes.is_parked(behind), "parked")
	# 700 px at pace(1) (about 67 px/s) is about 10.5 s.
	var smallest := _run_keeping_order(sim, behind, held, _spacing(1, 1), 15 * 60)
	assert_true(sim.slimes.is_parked(behind), "still parked, waiting")
	assert_lt(smallest, _spacing(1, 1) + 30.0, "it came up behind the held slime")

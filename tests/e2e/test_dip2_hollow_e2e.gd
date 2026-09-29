extends GutTest
## Chunk R22: the second dip's hollow (`Terrain/Dip2Hollow`, holding
## `s2.sleeper.15` and `.16`) moved off the loop's path to keep level rule
## 22 (b): it sits over the dip's far slope, and its sleepers must still be
## woken by a call. Its rule 22 result is in test_level_checker.gd (the
## test level passes every rule), its ways back in
## test_level_ways_back_e2e.gd (rule 7).
##
## Here, by behaviour: the level as the loop first reaches section 2
## (LevelChecker.start_state), every slime taken out but the sleeper and one
## base train slime on the far rim; the camera's view centred on the
## sleeper at zoom 1 (both on screen, so a touch wakes); a call centred on
## the sleeper (as a tap on it makes) at the view's call radius. The base
## slime hops up from the far rim and wakes the sleeper before its call and
## the unsure phase run out.

# @test-link [[rule_no_called_ledge_over_loop]]
# @test-link [[req_call_mechanic]]
# @test-link [[req_waking_sleepers]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
const SLEEPER := "s2.sleeper.16"
const SEED := 1
## The far rim's spots the caller starts from, x in screens (the rim is at
## y -20 from 10.5 on; the train carries the caller right a little first).
const RIM_SPOTS := [10.52, 10.6, 10.8]
## Ticks the train carries the caller before the call.
const SETTLE_TICKS := 60
## A call's answering, then the unsure phase (FreeSlimes).
const CALL_TICKS := int((FreeSlimes.CALL_SECONDS + FreeSlimes.UNSURE_SECONDS) * Simulation.TICK_RATE)

var level: Level
var checker: LevelChecker


func before_all() -> void:
	level = load(LEVEL_SCENE).instantiate()
	add_child(level)
	checker = LevelChecker.new(level)


func after_all() -> void:
	level.free()


## Section 2's start state with only sleeper `stable_id` and a base train
## slime `x_screens` along the loop left; returns [sim, sleeper, caller].
func _alone_with_a_caller(stable_id: String, x_screens: float) -> Array:
	var sim := checker.start_state(2, SEED)
	var sleeper := -1
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == stable_id:
			sleeper = slime_id
		else:
			sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var along := 0.0
	while level.data.loop.position_at(along, sim.train.open_gates).x < x_screens * LevelData.SCREEN:
		along += 4.0
	var caller := sim.spawn_train_slime(0, 1, along)
	return [sim, sleeper, caller]


func test_the_hollow_is_over_the_dips_far_slope() -> void:
	var at: Vector2 = level.data.sleepers[SLEEPER]["position"]
	assert_between(at.x / LevelData.SCREEN, 10.25, 10.45, "over the far slope (the dip is 10.0 to 10.5)")


func test_a_base_slime_called_from_the_far_rim_wakes_the_sleeper() -> void:
	for x in RIM_SPOTS:
		var run := _alone_with_a_caller(SLEEPER, x)
		var sim: Simulation = run[0]
		var sleeper: int = run[1]
		var caller: int = run[2]
		assert_gt(sleeper, -1, "%s is asleep in the level" % SLEEPER)
		sim.run(SETTLE_TICKS)
		var point := sim.slimes.centre_of(sleeper)
		sim.view.set_to(point, 1.0, ScreenView.DEFAULT_SIZE)
		var answered := sim.free_slimes.answer_call(point, sim.tick, sim.slimes, sim.call_radius())
		assert_eq(Array(answered), [caller], "from %.2f the base slime answers" % x)
		var woke := -1
		for tick in CALL_TICKS:
			sim.step()
			if sim.slimes.state_of(sleeper) != SlimeBodies.SLEEPER:
				woke = tick
				break
		assert_gt(woke, -1, "called from %.2f, a base slime wakes %s within %d s" % [x, SLEEPER,
				CALL_TICKS / Simulation.TICK_RATE])
		gut.p("from %.2f: woken after %.1f s" % [x, woke / float(Simulation.TICK_RATE)])

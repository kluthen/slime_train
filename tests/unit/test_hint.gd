extends GutTest
## The first-play hint (src/sim/hint.gd) through the Simulation: due on a
## fresh save, it shows 10 s after the world shows, next to the first sleeper
## (the one nearest the first slime); showing the world again restarts the
## count; the first call marks it done for good, and the done mark goes into
## the save; it never shows during bedtime.
##
## The synthetic world: a floor (top y = 0) and the loop along it; the first
## slime starts at x = -1000; two sleepers hang in the air (sleepers don't
## fall): t.sleeper.01 near the first slime, t.sleeper.02 far off.

# @test-link [[req_first_play_hint]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const NEAR_SPOT := Vector2(-1100, -124)
const FAR_SPOT := Vector2(600, -124)
const DUE_TICKS := 10 * Simulation.TICK_RATE


func _level(with_sleepers := true) -> LevelData:
	var data := LevelData.new("hint", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-1000, -24)}
	if with_sleepers:
		data.add_sleeper("t.sleeper.02", "B", FAR_SPOT)
		data.add_sleeper("t.sleeper.01", "C", NEAR_SPOT)
	return data


func _sim(with_sleepers := true) -> Simulation:
	var sim := Simulation.new(17)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.load_level(_level(with_sleepers))
	sim.view.set_to(Vector2(-1000, -200), 1.0, ScreenView.DEFAULT_SIZE)
	return sim


func _tap_screen(sim: Simulation, at: Vector2) -> void:
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.step()


## A call: a tap on open ground, in the middle of the screen.
func _call(sim: Simulation) -> void:
	_tap_screen(sim, sim.view.screen_size * 0.5)
	assert_true(sim.taps[-1]["call"])


func _round_trip(sim: Simulation) -> Simulation:
	var text := SaveData.to_text(sim.to_save())
	var again := Simulation.from_save(JSON.parse_string(text), _level(), sim.slimes.terrain)
	assert_not_null(again)
	return again


func test_the_hint_shows_10_s_after_the_world_shows_next_to_the_first_sleeper() -> void:
	var sim := _sim()
	assert_false(sim.hint.done)
	sim.run(DUE_TICKS - 1)
	assert_false(sim.hint.visible, "not yet at 9.98 s")
	sim.step()
	assert_true(sim.hint.visible, "at 10 s")
	assert_eq(sim.hint.position, NEAR_SPOT, "at the sleeper nearest the first slime")
	sim.run(300)
	assert_true(sim.hint.visible, "and it stays while it is due")


func test_showing_the_world_again_restarts_the_count() -> void:
	var sim := _sim()
	sim.run(300)
	sim.hint.world_shown(sim.tick)
	sim.run(DUE_TICKS - 1)
	assert_false(sim.hint.visible, "10 s from the new showing, not from the first")
	sim.step()
	assert_true(sim.hint.visible)
	sim.hint.world_shown(sim.tick)
	sim.step()
	assert_false(sim.hint.visible, "showing again while shown counts again")


func test_the_first_call_marks_it_done_for_good() -> void:
	var sim := _sim()
	sim.run(100)
	_call(sim)
	assert_true(sim.hint.done)
	sim.hint.world_shown(sim.tick)
	for i in 3 * DUE_TICKS:
		sim.step()
		if sim.hint.visible:
			break
	assert_false(sim.hint.visible, "never shown")


func test_a_call_hides_a_showing_hint() -> void:
	var sim := _sim()
	sim.run(DUE_TICKS)
	assert_true(sim.hint.visible)
	_call(sim)
	assert_false(sim.hint.visible)
	assert_true(sim.hint.done)


func test_a_tap_that_does_not_call_leaves_it_due() -> void:
	var sim := _sim()
	var edge := TapDispatcher.edge_button_rect(-1, sim.view).get_center()
	_tap_screen(sim, edge)
	assert_false(sim.taps[-1]["call"])
	_tap_screen(sim, Vector2(sim.view.screen_size.x * 0.5, 10.0))  # the parent zone
	assert_false(sim.taps[-1]["call"])
	assert_false(sim.hint.done)
	sim.run(DUE_TICKS)
	assert_true(sim.hint.visible)


func test_it_never_shows_during_bedtime() -> void:
	var sim := _sim()
	sim.hint.bedtime = true
	sim.run(2 * DUE_TICKS)
	assert_false(sim.hint.visible, "bedtime")
	sim.hint.bedtime = false
	sim.step()
	assert_true(sim.hint.visible, "due again once bedtime is over")


func test_a_level_without_sleepers_shows_none() -> void:
	var sim := _sim(false)
	sim.run(DUE_TICKS + 10)
	assert_false(sim.hint.visible)


func test_the_done_mark_survives_a_save_round_trip() -> void:
	var sim := _sim()
	sim.run(30)
	_call(sim)
	var save := sim.to_save()
	assert_eq(save["hint_done"], true)
	var again := _round_trip(sim)
	assert_true(again.hint.done)
	assert_eq(again.state_hash(), sim.state_hash())
	again.run(2 * DUE_TICKS)
	assert_false(again.hint.visible)
	assert_eq(SaveData.readable(save)["hint_done"], true, "hand-made saves keep it")


func test_a_save_without_the_done_mark_is_due_and_keeps_its_count() -> void:
	var sim := _sim()
	sim.run(300)
	var again := _round_trip(sim)
	assert_false(again.hint.done)
	assert_eq(again.hint.since, sim.hint.since, "the count restored exactly")
	assert_eq(again.state_hash(), sim.state_hash())
	var save := sim.to_save()
	save.erase("hint_done")
	save.erase("transient")
	var bare := Simulation.from_save(save, _level(), sim.slimes.terrain)
	assert_false(bare.hint.done, "no mark: the hint is due")


func test_a_done_mark_that_is_not_true_or_false_is_a_problem() -> void:
	var sim := _sim()
	var save := sim.to_save()
	save["hint_done"] = "yes"
	assert_eq(SaveData.problems(save, _level()).size(), 1)

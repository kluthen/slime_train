extends GutTest
## The celebration's lasting mark (item 23.11, ux D4; master spec §5.1)
## through the real game scene and test mode. From `stress-still` (basket 3,
## the test level's last, full and waiting; the fixture is at bedtime, so the
## world wakes first, item 23.5) the celebration plays: the camera doesn't
## move on its own through the burst, a tap during it calls as usual, the
## awake slimes on screen hop twice, and afterwards the mark stands at the
## start of the loop. It is still there after a save and reload, and absent
## on a level whose celebration hasn't played.

# @test-link [[req_level_completion_celebration]]
# @test-link [[req_persistence_and_saves]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 14
const TICK_RATE := Simulation.TICK_RATE
const BASKET_3 := "s3.basket"
## The camera on basket 3: its box's centre is at (16.01 screens, -10).
const BASKET_3_VIEW := Vector2(16.01 * 1152.0, -10.0)
const CELEBRATION_TICKS := int(FrontierSets.CELEBRATION_SECONDS * TICK_RATE)
const DIR := "user://test-celebration-e2e/"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))


func _boot(config := {}) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var run := {"seed": SEED, "time_scale": 0}
	run.merge(config, true)
	assert_eq(game.enable_test_mode(run), PackedStringArray())
	return game


## From stress-still: the camera put on basket 3 settles into its framing
## zone while the fixture's bedtime holds the reward (item 23.5); then
## sunrise, played as in a session (sessions are off in these runs, so the
## test sets the mode: no screensaver idle camera), with two train slimes
## put on the plateau by basket 3, on screen; then it runs, the camera left
## alone, until the celebration begins. Returns the game, or null when it
## never began.
func _celebrating() -> Node:
	var game := _boot({"fixture": "stress-still"})
	var sim: Simulation = game.simulation
	assert_false(sim.frontier.celebration_done)
	assert_null(game.frontier_view.mark_at(), "no mark before the celebration")
	sim.camera.place(BASKET_3_VIEW, 1.0)
	game.sync_view()
	var still := 0
	for i in 10 * TICK_RATE:
		var was := sim.camera.position
		game.test_mode.run_ticks(1)
		still = still + 1 if sim.camera.position == was else 0
		if still >= TICK_RATE:
			break
	assert_eq(still, TICK_RATE, "the camera settles on basket 3")
	sim.session.sunrise(sim)
	sim.screensaver = false
	# On the plateau over basket 3's shut trapdoor, 200 px before slide 3's
	# drop (where basket 3's outlet was before item 24.3 moved it over the
	# drop, where a slime falls and can't hop).
	var plateau := _s3_loop_end(sim) - Vector2(200.0, 0.0)
	for dx in [-120.0, -60.0]:
		sim.slimes.create(Species.from_letter("E"), 1, plateau + Vector2(dx, -30.0), SlimeBodies.TRAIN)
	for i in 10 * TICK_RATE:
		if sim.frontier.celebration_playing(sim.tick):
			return game
		game.test_mode.run_ticks(1)
	fail_test("the celebration never began")
	return null


## Where section 3's outgoing route ends: the top of slide 3's drop.
func _s3_loop_end(sim: Simulation) -> Vector2:
	for segment in sim.level.loop.segments:
		if segment["id"] == "s3.loop":
			var points: PackedVector2Array = segment["points"]
			return points[points.size() - 1]
	fail_test("the test level has no s3.loop")
	return Vector2.ZERO


func test_the_celebration_leaves_the_camera_and_the_mark_stands_at_the_start_of_the_loop() -> void:
	var game := _celebrating()
	if game == null:
		return
	var sim: Simulation = game.simulation
	assert_true(sim.frontier.celebration_showing(sim), "the burst plays")
	assert_null(game.frontier_view.mark_at(), "the mark comes after the burst")
	var hops_due: Array = sim.frontier.dump()["celebration_hops"]
	gut.p("double hops due at the burst's start: %s" % [hops_due])
	assert_false(hops_due.is_empty(), "the awake slimes on screen are to hop")
	var centre := sim.camera.position
	var hopped := {}
	for i in CELEBRATION_TICKS / 2:
		game.test_mode.run_ticks(1)
		for slime_id in sim.slimes.hopped:
			hopped[slime_id] = true
	assert_eq(sim.camera.position, centre, "the camera doesn't move on its own")
	for entry in hops_due:
		assert_true(hopped.has(int(entry[0])), "slime %d on screen hops" % entry[0])
	game.test_mode.run_ticks(CELEBRATION_TICKS)
	assert_false(sim.frontier.celebration_playing(sim.tick), "the burst is over")
	assert_eq(game.frontier_view.mark_at(), sim.level.loop.position_at(0.0), "the mark, at the start of the loop")


func test_a_tap_during_the_celebration_calls_as_usual() -> void:
	var game := _celebrating()
	if game == null:
		return
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(TICK_RATE)
	assert_true(sim.frontier.celebration_showing(sim))
	var at := Vector2(576, 420)
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	game.test_mode.run_ticks(1)
	assert_eq(sim.taps[-1]["zone"], TapDispatcher.ZONE_GROUND)
	assert_true(sim.taps[-1]["call"], "the tap calls")
	assert_true(sim.frontier.celebration_playing(sim.tick), "and the celebration plays on")


func test_the_mark_is_still_there_after_a_save_and_reload_and_absent_without_the_celebration() -> void:
	var game := _celebrating()
	if game == null:
		return
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(CELEBRATION_TICKS)
	assert_not_null(game.frontier_view.mark_at())
	var path := ProjectSettings.globalize_path(DIR + "celebrated.json")
	assert_eq(SaveStore.write_file(path, sim.to_save()), "")
	var reloaded := _boot({"load": path})
	assert_true(reloaded.simulation.frontier.celebration_done)
	assert_eq(reloaded.frontier_view.mark_at(), sim.level.loop.position_at(0.0), "the mark after a reload")
	for fixture in ["fresh", "gate2-open"]:
		var other := _boot({"fixture": fixture})
		assert_null(other.frontier_view.mark_at(), "no mark on %s: its celebration hasn't played" % fixture)

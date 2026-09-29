extends GutTest
## The parent's delete of the level save through the real game scene, in
## normal play (chunk 18, D43, D104) [DoD 29]: the level reloads fresh at
## once (the first-play hint due again, the celebration able to play again,
## the progress gone) while the running session goes on untouched (same
## phase, same time left, bedtime and sunrise on time), and the fresh save is
## written at once, so a kill right after resumes the same session. The
## parent store (code, wrong tries) is not a level save: it stays. Also the
## parent's wake early (D57) through the game root.
##
## Every game here gets its own SaveStore on a scratch directory and a fake
## session clock.

# @test-link [[req_persistence_and_saves]]
# @test-link [[req_session_lifecycle]]

const MAIN_SCENE := "res://src/main.tscn"
const DIR := "user://test-delete-save-e2e/"
const LEVEL := "test"
## Any wall clock: the tests count from here.
const WALL := 1_700_000_000_000


## Stands in for SessionClock in normal play.
class FakeClock:
	extends RefCounted
	var reading := {}

	func now() -> Dictionary:
		return reading


func before_each() -> void:
	_clear(DIR)


func after_all() -> void:
	_clear(DIR)


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## A game in normal play on `store` (or none), its session clock at WALL.
func _game(store: SaveStore) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = store
	add_child_autofree(game)
	assert_null(game.test_mode, "normal play")
	game.session_clock = FakeClock.new()
	_step_at(game, 0)
	return game


## One game step with the session clock `ms` after WALL.
func _step_at(game: Node, ms: int) -> void:
	game.session_clock.reading = Session.reading(WALL + ms, ms, "e2e")
	game.step_simulation()


## Taps the middle of the screen at clock `ms`: a call on open ground, which
## starts a session and does the first-play hint's first call.
func _start_session(game: Node, ms: int) -> void:
	var sim: Simulation = game.simulation
	var at: Vector2 = sim.view.screen_size * 0.5
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	_step_at(game, ms)
	assert_eq(sim.session.phase, Session.SESSION)
	assert_true(sim.taps[-1]["call"], "a call")
	assert_true(sim.hint.done, "the first call happened")


## The level save on disk (asserted readable).
func _on_disk(store: SaveStore) -> Dictionary:
	var written := SaveStore.read_file(store.path_for(LEVEL))
	assert_eq(written["status"], SaveStore.OK)
	return written["save"]


func test_deleting_mid_session_reloads_fresh_and_keeps_the_session() -> void:
	var store := SaveStore.new(DIR)
	var game := _game(store)
	_start_session(game, 1000)
	var old: Simulation = game.simulation
	old.frontier.celebration_done = true
	_step_at(game, 61_000)
	assert_eq(game.save_now(), "")
	assert_true(_on_disk(store).get("hint_done", false), "the progress is saved")
	assert_true(_on_disk(store).get("celebration_done", false))
	var session: Dictionary = old.session.dump()
	var left: int = old.session.time_left_ms()
	assert_eq(game.delete_level_save(), "")
	var sim: Simulation = game.simulation
	assert_ne(sim, old, "a fresh simulation")
	assert_false(sim.hint.done, "the hint is due again")
	assert_false(sim.frontier.celebration_done, "the celebration can play again")
	assert_eq(sim.session.phase, Session.SESSION)
	assert_eq(sim.session.time_left_ms(), left, "the same time left")
	assert_false(sim.screensaver)
	var save := _on_disk(store)
	assert_false(save.get("hint_done", false), "the file is a fresh save")
	assert_false(save.get("celebration_done", false))
	assert_eq(save["session"]["phase"], session["phase"])
	assert_eq(int(save["session"]["elapsed_ms"]), session["elapsed_ms"])
	# Killed right after: the same session resumes.
	var reopened := _game(SaveStore.new(DIR))
	assert_eq(reopened.simulation.session.phase, Session.SESSION)
	assert_false(reopened.simulation.hint.done)
	# The session ends on time: bedtime 15 minutes after the tap.
	_step_at(game, 1000 + Session.BEDTIME_MS - 1)
	assert_ne(sim.session.phase, Session.BEDTIME)
	_step_at(game, 1000 + Session.BEDTIME_MS)
	assert_eq(sim.session.phase, Session.BEDTIME, "bedtime on time")


func test_deleting_at_bedtime_stays_bedtime_and_sunrise_comes_on_time() -> void:
	var store := SaveStore.new(DIR)
	var game := _game(store)
	_start_session(game, 0)
	_step_at(game, Session.BEDTIME_MS)
	_step_at(game, Session.BEDTIME_MS + 120_000)
	assert_eq(game.simulation.session.phase, Session.BEDTIME)
	var left: int = game.simulation.session.time_left_ms()
	assert_eq(game.delete_level_save(), "")
	var sim: Simulation = game.simulation
	assert_eq(sim.session.phase, Session.BEDTIME, "still bedtime")
	assert_eq(sim.session.time_left_ms(), left)
	for slime_id in sim.slimes.ids():
		assert_ne(sim.slimes.state_of(slime_id), SlimeBodies.TRAIN, "the fresh world sleeps")
		assert_ne(sim.slimes.state_of(slime_id), SlimeBodies.FREE)
	assert_false(sim.camera.edge_buttons_visible)
	assert_eq(_on_disk(store)["session"]["phase"], Session.BEDTIME)
	_step_at(game, Session.SUNRISE_MS - 1)
	assert_eq(sim.session.phase, Session.BEDTIME)
	_step_at(game, Session.SUNRISE_MS)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "sunrise on time")
	assert_true(sim.screensaver)


func test_deleting_a_level_save_leaves_the_parent_store() -> void:
	var store := SaveStore.new(DIR)
	var game := _game(store)
	assert_eq(game.save_now(), "")
	var parent := ParentStore.new(DIR + "parent.json")
	parent.set_code("123456")
	assert_eq(parent.try_code("000000", WALL), ParentStore.Result.WRONG)
	var before := FileAccess.get_file_as_bytes(DIR + "parent.json")
	assert_eq(game.delete_level_save(), "")
	assert_eq(FileAccess.get_file_as_bytes(DIR + "parent.json"), before, "the file is as it was")
	var reread := ParentStore.new(DIR + "parent.json")
	assert_true(reread.has_code(), "the code stays")
	assert_eq(reread.wrong_tries(), 1, "the wrong tries stay")


func test_without_a_store_deleting_reloads_fresh_and_keeps_the_session() -> void:
	var game := _game(null)
	_start_session(game, 0)
	_step_at(game, 30_000)
	var session: Dictionary = game.simulation.session.dump()
	assert_eq(game.delete_level_save(), "")
	assert_false(game.simulation.hint.done)
	assert_eq(game.simulation.session.phase, session["phase"])
	assert_eq(game.simulation.session.elapsed_ms, session["elapsed_ms"])


func test_wake_early_through_the_game_ends_bedtime_on_the_next_step() -> void:
	var game := _game(SaveStore.new(DIR))
	_start_session(game, 0)
	_step_at(game, Session.BEDTIME_MS)
	assert_eq(game.simulation.session.phase, Session.BEDTIME)
	game.wake_early()
	assert_eq(game.simulation.session.phase, Session.BEDTIME, "queued")
	_step_at(game, Session.BEDTIME_MS + 1000)
	assert_eq(game.simulation.session.phase, Session.SCREENSAVER, "sunrise, then screensaver mode")
	assert_true(game.simulation.screensaver)


# --- In test mode: the session clock goes on through the delete ------------------

## A game in test mode (no store, time held) from the test level's
## `fixture`, with sessions and no scripted steps.
func _test_mode_game(fixture: String) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = null
	add_child_autofree(game)
	var config := {"seed": 4242, "time_scale": 0, "sessions": true, "fixture": fixture, "steps": []}
	assert_eq(game.enable_test_mode(config), PackedStringArray())
	return game


## Runs `game` up to (not including) `tick`.
func _run_to(game: Node, tick: int) -> void:
	game.test_mode.run_ticks(tick - game.simulation.tick)


func test_in_test_mode_deleting_mid_session_keeps_the_session_clock_running() -> void:
	# The wind-down fixture: bedtime comes at tick 601 when nothing is deleted.
	var game := _test_mode_game("wind-down")
	_run_to(game, 300)
	var left: int = game.simulation.session.time_left_ms()
	assert_eq(game.delete_level_save(), "")
	var sim: Simulation = game.simulation
	assert_eq(sim.tick, 0, "a fresh simulation")
	assert_eq(sim.session.time_left_ms(), left, "the same time left")
	_run_to(game, 60)
	var ran: int = left - sim.session.time_left_ms()
	assert_between(ran, 1000 - 17, 1000 + 17, "a second ran in 60 ticks (%d ms)" % ran)
	# Bedtime at the same moment: 601 - 300 ticks after the delete.
	_run_to(game, 300)
	assert_eq(sim.session.phase, Session.WIND_DOWN, "not yet bedtime")
	_run_to(game, 301)
	assert_eq(sim.session.phase, Session.BEDTIME, "bedtime on time")


func test_in_test_mode_deleting_at_bedtime_brings_sunrise_on_time() -> void:
	# The sunrise fixture: sunrise comes at tick 301 when nothing is deleted.
	var game := _test_mode_game("sunrise")
	_run_to(game, 100)
	assert_eq(game.simulation.session.phase, Session.BEDTIME)
	assert_eq(game.delete_level_save(), "")
	var sim: Simulation = game.simulation
	_run_to(game, 200)
	assert_eq(sim.session.phase, Session.BEDTIME, "not yet sunrise")
	_run_to(game, 201)
	assert_eq(sim.session.phase, Session.SCREENSAVER, "sunrise on time")

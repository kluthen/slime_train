extends GutTest
## End-to-end on the test level, through the real game scene and test mode:
## a parked size-3 train slime going down section 3's entry ramp (13.0 to
## 13.6 screens) with the camera far away keeps moving at the off-screen pace
## and is never lost. It used to stop on the ramp (lifted straight up, its
## projection on the loop never moved on) and be lost as stalled after 60 s.
## From `gate2-open` (the loop runs through section 3).
# @test-link [[req_offscreen_simulation]]
# @test-link [[rule_left_alone_and_lost]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 14
const TICK_RATE := Simulation.TICK_RATE
const S := 1152.0
## Far from section 3: the start basin.
const AWAY_VIEW := Vector2(0.4 * S, 400.0)
## The slime starts on the loop just before the ramp, at gate 2's ground.
const START := Vector2(12.9 * S, -44.0)
## The ramp's foot, x px.
const RAMP_FOOT := 13.6 * S
## Watched this long (seconds): long enough for the train's stall rule (60 s
## without moving on) to lose a slime that stops on the ramp.
const WATCH_FOR := 85
## Its progress is checked every this many seconds.
const WINDOW := 5
## Each window it moves at least this share of the pace.
const MIN_SHARE := 0.95


func _boot() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = null
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "fixture": "gate2-open"}), PackedStringArray())
	return game


## Runs `ticks` ticks with the camera held on AWAY_VIEW.
func _hold_away(game: Node, ticks: int) -> void:
	for i in ticks:
		game.simulation.camera.place(AWAY_VIEW, 1.0)
		game.sync_view()
		game.test_mode.run_ticks(1)


func test_a_size_3_slime_off_screen_goes_down_section_3s_ramp_and_is_never_lost() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var start: float = sim.level.loop.closest(START, sim.train.open_gates)["distance"]
	var slime := sim.spawn_train_slime(Species.from_letter("E"), 3, start)
	assert_gte(slime, 0, "spawned")
	_hold_away(game, 1)
	assert_true(sim.slimes.is_parked(slime), "off screen, parked")
	var least := Offscreen.pace(3) * WINDOW * MIN_SHARE
	var passed_ramp := false
	for window in WATCH_FOR / WINDOW:
		var before := sim.train.progress_of(slime)
		_hold_away(game, WINDOW * TICK_RATE)
		var moved := sim.train.progress_of(slime) - before
		gut.p("window %d: moved %.1f px, at %s" % [window, moved, sim.slimes.centre_of(slime)])
		assert_eq(sim.slimes.state_of(slime), SlimeBodies.TRAIN, "still on the train (window %d)" % window)
		assert_true(sim.slimes.is_parked(slime), "still parked (window %d)" % window)
		assert_gte(moved, least, "it keeps moving on (window %d)" % window)
		passed_ramp = passed_ramp or sim.slimes.centre_of(slime).x > RAMP_FOOT
	assert_true(passed_ramp, "down the ramp and on")
	for entry in sim.train.lost + sim.offscreen.lost:
		assert_ne(entry["id"], slime, "never lost: %s" % entry)

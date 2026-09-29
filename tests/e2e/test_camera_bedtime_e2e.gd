extends GutTest
## End-to-end on the test level: the idle camera at bedtime (master spec
## §5.6, §5.7, build plan item 23.12) through the real game scene, test mode
## and sessions. From `wind-down` (bedtime 10 s in) with no input: the camera
## is idle (following a train slime) when bedtime begins and doesn't travel
## through the whole cooldown (its position stays put; only the zoom may
## settle); the same with bedtime beginning during the idle cue; at sunrise
## the idle camera follows a train slime again.
##
## The cooldown is 10 minutes of real time: the run ticks through its first
## BEDTIME_TICKS, a scripted "skip" lets most of the rest pass between two
## ticks, and it ticks on to sunrise. The idle clock is set on the camera at
## the start, so the camera idles (or is in its cue) when bedtime begins: 10
## s of wind-down are too short to wait 45 s for it.

# @test-link [[req_idle_camera_and_screensaver_zoom]]
# @test-link [[req_session_lifecycle]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 4242
const TICK_RATE := Simulation.TICK_RATE
## The tick bedtime begins from `wind-down` (test_session_e2e: 15:00 at 601).
const BEDTIME_TICK := 601
## Ticked through at the start of the cooldown, then skipped, then ticked.
const BEDTIME_TICKS := 30 * TICK_RATE
const SKIP_SECONDS := 540
const IDLE_TICKS := int(Camera.IDLE_SECONDS * TICK_RATE)
const CUE_TICKS := int(Camera.CUE_SECONDS * TICK_RATE)


func _boot() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	var skip := {"tick": BEDTIME_TICK + BEDTIME_TICKS, "do": "skip", "seconds": SKIP_SECONDS}
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "sessions": true,
			"fixture": "wind-down", "steps": [skip]}), PackedStringArray())
	assert_eq(game.simulation.session.phase, Session.WIND_DOWN)
	return game


## Runs to bedtime, then through the whole cooldown to sunrise, checking at
## every tick of bedtime that the camera stays where it was when bedtime
## began and follows no one. Returns the tick sunrise came.
func _through_bedtime(game: Node) -> int:
	var sim: Simulation = game.simulation
	while sim.tick < BEDTIME_TICK - 1:
		game.test_mode.run_ticks(1)
	var before := sim.camera.position
	game.test_mode.run_ticks(1)
	assert_eq(sim.session.phase, Session.BEDTIME, "bedtime begins")
	assert_eq(sim.camera.position, before, "bedtime's first tick moves nothing")
	var limit := BEDTIME_TICK + BEDTIME_TICKS + int(Session.COOLDOWN_SECONDS * TICK_RATE)
	while sim.session.phase == Session.BEDTIME and sim.tick < limit:
		game.test_mode.run_ticks(1)
		if sim.session.phase != Session.BEDTIME:
			break
		if sim.camera.position != before or sim.camera.follow_id != -1:
			assert_eq(sim.camera.position, before, "the camera travels nowhere at bedtime (tick %d)" % sim.tick)
			assert_eq(sim.camera.follow_id, -1, "it follows no one")
			return -1
	assert_eq(sim.session.phase, Session.SCREENSAVER, "sunrise")
	return sim.tick


## After sunrise, a few seconds on: the idle camera follows a train slime.
func _assert_follows_a_train_slime(game: Node) -> void:
	var sim: Simulation = game.simulation
	game.test_mode.run_ticks(2 * TICK_RATE)
	assert_eq(sim.camera.mode, Camera.FOLLOW, "the idle camera, after sunrise")
	assert_gt(sim.camera.follow_id, -1)
	if sim.camera.follow_id >= 0:
		assert_eq(sim.slimes.state_of(sim.camera.follow_id), SlimeBodies.TRAIN, "a train slime")


func test_the_idle_camera_at_bedtime_stays_put_until_sunrise() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	# The last 5 s before the idle camera: it takes over before bedtime.
	sim.camera.quiet = IDLE_TICKS - 5 * TICK_RATE
	game.test_mode.run_ticks(BEDTIME_TICK - 1)
	assert_eq(sim.camera.mode, Camera.FOLLOW, "idle when bedtime begins")
	assert_gt(sim.camera.follow_id, -1, "following a train slime")
	var sunrise := _through_bedtime(game)
	assert_gt(sunrise, BEDTIME_TICK, "through the whole cooldown")
	_assert_follows_a_train_slime(game)


func test_bedtime_beginning_during_the_cue_starts_no_idle_camera() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	# Bedtime comes 5 s into the cue.
	sim.camera.quiet = IDLE_TICKS - CUE_TICKS + 5 * TICK_RATE - BEDTIME_TICK
	game.test_mode.run_ticks(BEDTIME_TICK - 1)
	assert_eq(sim.camera.mode, Camera.RAILS)
	assert_lt(sim.camera.zoom, 1.0, "the cue is on when bedtime begins")
	var sunrise := _through_bedtime(game)
	assert_gt(sunrise, BEDTIME_TICK, "through the whole cooldown")
	_assert_follows_a_train_slime(game)


func test_a_bedtime_run_is_repeatable() -> void:
	var hashes := []
	for run in 2:
		var game := _boot()
		game.simulation.camera.quiet = IDLE_TICKS - 5 * TICK_RATE
		game.test_mode.run_ticks(BEDTIME_TICK + 10 * TICK_RATE)
		hashes.append(game.simulation.state_hash())
	assert_eq(hashes[0], hashes[1], "same seed, same hash")

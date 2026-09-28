extends GutTest
## End-to-end on the test level (the Meadow): tilt injected by test mode's
## script, as on desktop (the real sensor is chunk 20). A scripted tap calls
## the first slime off the loop; a scripted 30° tilt then pushes that free
## slime toward screen-right while a train slime on the loop goes on exactly
## as without tilt (DoD 8). The same scripted tilts give the same hash twice.
## Tilt held at neutral (or inside the dead zone) changes nothing at all, so
## the test level's no-input session (tests/e2e/test_train_session_e2e.gd,
## 15 simulated minutes with no tilt) also stands for "tilt permanently at
## neutral": no level requires tilt.

# @test-link [[req_tilt_input]]
# @test-link [[req_slime_states]]
# @test-link [[rule_tilt_never_required]]

const MAIN_SCENE := "res://src/main.tscn"
const SEED := 77
const TICK_RATE := Simulation.TICK_RATE
## A tap on open ground by the start basin that calls the first slime
## (the same tap as tests/e2e/test_call_e2e.gd's determinism test).
const CALL := {"tick": 20, "do": "tap", "at": [760, 420]}
const TILT_TICK := 40
## How far along the loop, ahead of the first slime, the train slime starts:
## well out of the call's reach and of the free slime's way.
const TRAIN_SLIME_AHEAD := 1400.0


func _boot(steps: Array) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "steps": steps}), PackedStringArray())
	return game


## The dump without the input record (which logs every tilt event, even one
## that changes nothing).
func _world(sim: Simulation) -> Dictionary:
	var state := sim.dump()
	state.erase("input")
	return state


## Calls the first slime, puts a train slime ahead on the loop, then runs
## `seconds` with the scripted `steps`. Returns the free slime's x and the
## train slime's centre, sampled every tick after the tilt.
func _called_run(steps: Array, seconds: int) -> Dictionary:
	var game := _boot([CALL] + steps)
	var sim: Simulation = game.simulation
	var slime := sim.slimes.ids()[0]
	var start := sim.train.distance_of(slime)
	game.test_mode.run_until(CALL["tick"] + 1)
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.FREE, "the tap called the first slime off the loop")
	var train_slime := sim.spawn_train_slime(Species.from_letter("A"), 1, start + TRAIN_SLIME_AHEAD)
	assert_gt(train_slime, -1)
	game.test_mode.run_until(TILT_TICK + 1)
	var free_x := PackedFloat32Array()
	var train_at := PackedVector2Array()
	for i in seconds * TICK_RATE:
		game.test_mode.run_ticks(1)
		free_x.append(sim.slimes.centre_of(slime).x)
		train_at.append(sim.slimes.centre_of(train_slime))
	assert_eq(sim.slimes.state_of(train_slime), SlimeBodies.TRAIN, "the train slime stays on the train")
	return {"free_x": free_x, "train_at": train_at, "free_phase": sim.free_slimes.phase_of(slime)}


static func _mean(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


func test_scripted_tilt_moves_the_free_slime_and_not_the_train() -> void:
	var plain := _called_run([], 6)
	var right := _called_run([{"tick": TILT_TICK, "do": "tilt", "degrees": 30}], 6)
	var left := _called_run([{"tick": TILT_TICK, "do": "tilt", "degrees": -30}], 6)
	var shift_right := _mean(right["free_x"]) - _mean(plain["free_x"])
	var shift_left := _mean(left["free_x"]) - _mean(plain["free_x"])
	gut.p("free slime's mean x over 6 s: +30° %+.1f px, -30° %+.1f px (phase %s)" % [shift_right, shift_left, plain["free_phase"]])
	assert_gt(shift_right, 20.0, "tilted right, the free slime drifts right")
	assert_lt(shift_left, -20.0, "tilted left, it drifts left")
	assert_eq(right["train_at"], plain["train_at"], "the train slime moves exactly as without tilt")
	assert_eq(left["train_at"], plain["train_at"])


func test_scripted_tilt_is_deterministic() -> void:
	var tilts := [
		{"tick": TILT_TICK, "do": "tilt", "degrees": 30},
		{"tick": 200, "do": "tilt", "degrees": -40},
		{"tick": 400, "do": "tilt", "degrees": 25, "flat": true},
		{"tick": 500, "do": "tilt", "degrees": 60},
		{"tick": 700, "do": "tilt", "degrees": 0},
	]
	var hashes := []
	for steps in [[CALL] + tilts, [CALL] + tilts, [CALL]]:
		var game := _boot(steps)
		game.test_mode.run_ticks(15 * TICK_RATE)
		hashes.append(game.simulation.state_hash())
	assert_eq(hashes[0], hashes[1], "same seed, same scripted tilts: same hash")
	assert_ne(hashes[0], hashes[2], "the tilts change the run")


func test_tilt_at_neutral_changes_nothing() -> void:
	# No level requires tilt: the session test runs with no tilt at all, and a
	# tilt held at neutral, or inside the dead zone, is exactly the same run,
	# free slime included.
	var neutral := [CALL]
	var degrees := [0.0, 9.0, -9.0, 5.0, 0.0]
	for i in 20:
		neutral.append({"tick": 30 + i * 60, "do": "tilt", "degrees": degrees[i % degrees.size()]})
	var worlds := []
	for steps in [[CALL], neutral]:
		var game := _boot(steps)
		game.test_mode.run_ticks(20 * TICK_RATE)
		assert_eq(game.simulation.slimes.state_of(game.simulation.slimes.ids()[0]), SlimeBodies.FREE,
				"the called slime is still free")
		worlds.append(_world(game.simulation))
	assert_eq(StateHash.of(worlds[1]), StateHash.of(worlds[0]), "tilt at neutral: the same world as no tilt")

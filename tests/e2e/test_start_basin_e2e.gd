extends GutTest
## End-to-end, the test level's start basin (chunk 16e): the train leaves the
## basin at its normal pace (DoD 1, rules 1 and 2).
##
## - The slides come home behind the loop's start: no return route runs along
##   the loop's first stretch (against the train's way), so a slime coming
##   home never meets the train head on.
## - A slime coming home off the slide doesn't shove the train slimes on the
##   loop's first stretch back.
## - A fused slime coming home with others behind it is split at the start
##   and every part, and every slime behind it, leaves the basin (the pocket
##   behind the loop's start has room for them).
## - A lone slime of every size passes the first sleeper's ledge at a base
##   slime's normal pace: the ledge sits just above the loop, low enough for
##   a called base slime to hop onto (rules 17 and 18), so the split zone
##   reaches past it and only base slimes pass under it.
##
## Before chunk 16e the slides' tail ran back along the basin floor over the
## loop's first stretch: each slime coming home shoved the train slimes back
## 100 to 250 px, and a size-3 slime crawled under the first sleeper's ledge
## (37 px in 20 s), so a train slime could stall
## (docs/dev/README.md, chunk 16).
# @test-link [[rule_loop_travelable_with_no_input]]
# @test-link [[rule_all_sizes_travel_loop_v1]]
# @test-link [[rule_first_sleeper_near_first_awake_slime]]
# @test-link [[req_test_level_and_test_mode]]

const MAIN_SCENE := "res://src/main.tscn"
const LEVEL_SCENE := "res://levels/test/level.tscn"
const SEED := 2
const TICK_RATE := Simulation.TICK_RATE
## Where the train slimes wait on the loop's first stretch, px along it, one
## species each (so none fuses), and the slime coming home: px before the
## end of the loop (about 1.7 s of slide), species E.
const QUEUE := {150.0: "A", 230.0: "B", 310.0: "C"}
const COMING_HOME := 600.0
## How long the shove is watched, ticks.
const SHOVE_TICKS := 5 * TICK_RATE
## The most a queued slime may be pushed back behind its furthest point, px
## (a slime's own landing squish and bumps between neighbours stay under it).
const SHOVE_LIMIT := 40.0
## Slimes coming home one after the other, px before the end of the loop:
## [distance, species, size], the fused one first; and how long every one
## of them (and every part) has to be PACE_PAST right of the first sleeper.
const HOMECOMING := [[600.0, "C", 3], [700.0, "A", 1], [800.0, "B", 1]]
const HOMECOMING_TICKS := 30 * TICK_RATE
## The pace check: a slime starts PACE_LEAD (screens) left of the first
## sleeper and it, or every part it split into, must be PACE_PAST right of it
## within PACE_TICKS. A base slime on open ground makes about 600 px in 10 s;
## a split part may first wait out the hop timer it kept (up to 3.9 s for a
## size 3); a slime crawling under a low ledge made 37 px in 20 s.
const PACE_LEAD := 0.05
const PACE_PAST := 0.15
const PACE_TICKS := 10 * TICK_RATE


## The game on the fresh test level, no save, with its train slimes (the
## first slime) taken out; the sleepers stay.
func _boot() -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.save_store = null
	add_child_autofree(game)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0}), PackedStringArray())
	var sim: Simulation = game.simulation
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN:
			sim.slimes.remove(slime_id)
	return game


# @test-link [[rule_return_route_joins_start_behind_train]]
func test_the_slides_come_home_behind_the_loop_start_not_along_its_first_stretch() -> void:
	# Level rule 22's first part, by the level-rules checker (LevelChecker):
	# in every gate state, no point of the slide farther than 80 px from the
	# loop's start runs within two size-1 slime radii of the loop's first 1.5
	# screens (the basin and the way up out of it).
	var level: Level = load(LEVEL_SCENE).instantiate()
	add_child_autofree(level)
	var checker := LevelChecker.new(level)
	assert_eq(Array(checker.sections()), [1, 2, 3], "three gate states")
	assert_eq(LevelRulesStart.behind_the_train(checker), [])


func test_a_slime_coming_home_does_not_shove_the_train_back() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var queue := {}
	for distance in QUEUE:
		queue[sim.spawn_train_slime(Species.from_letter(QUEUE[distance]), 1, distance)] = 0.0
	var home := sim.spawn_train_slime(Species.from_letter("E"), 1, sim.train.length() - COMING_HOME)
	assert_true(sim.train.is_slide_at(sim.train.distance_of(home)), "it starts on the slide")
	var furthest := {}
	for slime_id in queue:
		furthest[slime_id] = sim.slimes.centre_of(slime_id).x
	while sim.tick < SHOVE_TICKS:
		game.test_mode.run_ticks(1)
		for slime_id in queue:
			var x := sim.slimes.centre_of(slime_id).x
			furthest[slime_id] = maxf(furthest[slime_id], x)
			queue[slime_id] = maxf(queue[slime_id], furthest[slime_id] - x)
	gut.p("shoved back, px: %s" % [queue.values()])
	assert_eq(sim.train.laps_of(home), 1, "the slime came home")
	for slime_id in queue:
		assert_lt(queue[slime_id], SHOVE_LIMIT, "train slime %d was shoved back %.0f px" % [slime_id, queue[slime_id]])
	assert_eq(sim.train.stalled, [] as Array[Dictionary])


## Whether every train slime's centre is right of level x `x`.
static func _all_past(sim: Simulation, x: float) -> bool:
	for slime_id in sim.train.tracked_ids():
		if sim.slimes.centre_of(slime_id).x < x:
			return false
	return true


func test_a_fused_slime_coming_home_with_others_splits_and_all_leave_the_basin() -> void:
	var game := _boot()
	var sim: Simulation = game.simulation
	var fused := -1
	for home in HOMECOMING:
		var slime := sim.spawn_train_slime(Species.from_letter(home[1]), home[2], sim.train.length() - home[0])
		fused = slime if fused < 0 else fused
	var sleeper: Vector2 = game.level.position_of(game.level.find("s1.sleeper.01"))
	var past := sleeper.x + PACE_PAST * LevelData.SCREEN
	var left_at := -1
	while sim.tick < HOMECOMING_TICKS and sim.train.stalled.is_empty():
		sim.camera.place(sim.slimes.centre_of(fused), 1.0)
		game.sync_view()
		game.test_mode.run_ticks(1)
		if sim.tick > TICK_RATE and _all_past(sim, past):
			left_at = sim.tick
			break
	gut.p("%d train slimes, all past the first sleeper at tick %d" % [sim.train.tracked_ids().size(), left_at])
	assert_eq(sim.train.stalled, [] as Array[Dictionary], "none lost")
	assert_eq(sim.train.tracked_ids().size(), 5, "the size 3 came home as three base slimes")
	assert_gt(left_at, 0, "every slime left the basin within %d s" % [HOMECOMING_TICKS / TICK_RATE])


## A lone train slime of `size` from PACE_LEAD left of the first sleeper,
## the camera on it: the tick when it and every part it split into are
## PACE_PAST right of the sleeper, or -1 if not within PACE_TICKS.
func _past_the_first_sleeper(size: int) -> int:
	var game := _boot()
	var sim: Simulation = game.simulation
	var sleeper: Vector2 = game.level.position_of(game.level.find("s1.sleeper.01"))
	var from_point := Vector2(sleeper.x - PACE_LEAD * LevelData.SCREEN, sleeper.y)
	var from: float = game.level.data.loop.closest(from_point, sim.train.open_gates)["distance"]
	var slime := sim.spawn_train_slime(Species.from_letter("A"), size, from)
	var past := sleeper.x + PACE_PAST * LevelData.SCREEN
	while sim.tick < PACE_TICKS:
		sim.camera.place(sim.slimes.centre_of(slime), 1.0)
		game.sync_view()
		game.test_mode.run_ticks(1)
		if _all_past(sim, past):
			return sim.tick
	return -1


func test_every_size_passes_the_first_sleeper_at_its_normal_pace() -> void:
	for size in [1, 2, 3]:
		var tick := _past_the_first_sleeper(size)
		gut.p("size %d: past the first sleeper at tick %d" % [size, tick])
		assert_gt(tick, 0, "the size-%d slime (whole or split) passes the first sleeper within %d s"
				% [size, PACE_TICKS / TICK_RATE])

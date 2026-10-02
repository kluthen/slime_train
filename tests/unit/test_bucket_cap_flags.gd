extends GutTest
## The bucket cap's user arguments (chunk 22i, D151 (7), experimental): the
## game root's use_loop_buckets() reads --bucket-cap (Train.bucket_cap on)
## and --bucket-cap-density=D (Train.bucket_cap_density, D > 0) beside
## 22g's --loop-buckets and --loop-bucket-length=PX, in a debug build only;
## both go to the running simulation's Train and every later one's. The cap
## is independent of the front-first order: --bucket-cap alone leaves
## Train.front_first off, and the bucket length stays --loop-bucket-length.
## Test mode leaves them to the game root.

# @test-link [[req_platform_and_performance_targets]]


## The main scene, its build a debug build or not (TestModeGuard).
func _game(is_debug_build: bool) -> Node:
	var game: Node = load("res://src/main.tscn").instantiate()
	game.test_mode_guard = TestModeGuard.new(is_debug_build)
	add_child_autofree(game)
	return game


# Off by default; --bucket-cap turns the cap on at the default density, on
# the running simulation's train and on every simulation the game takes
# after (a test-mode run, a fresh restart), the front-first order left off.
# @test-link [[req_platform_and_performance_targets]]
func test_the_flag_turns_the_cap_on_every_simulations_train() -> void:
	var game := _game(true)
	assert_false(game.simulation.train.bucket_cap, "off by default")
	assert_eq(game.use_loop_buckets(PackedStringArray(["--bucket-cap"])), PackedStringArray())
	var trains: Array[Train] = [game.simulation.train]
	assert_eq(game.enable_test_mode({"seed": 1}), PackedStringArray())
	trains.append(game.simulation.train)
	trains.append(game.restart_fresh().train)
	for train in trains:
		assert_true(train.bucket_cap)
		assert_eq(train.bucket_cap_density, BucketLoads.DEFAULT_DENSITY)
		assert_eq(train.bucket_cap_density, 4.0)
		assert_false(train.front_first, "the cap alone: front-first stays off")
		assert_eq(train.bucket_length, LoopBuckets.DEFAULT_BUCKET_LENGTH)


# --bucket-cap-density=D sets the density; the bucket length is still
# --loop-bucket-length's; with --loop-buckets too both switches are on.
# @test-link [[req_platform_and_performance_targets]]
func test_the_density_and_the_bucket_length_reach_the_train() -> void:
	var game := _game(true)
	assert_eq(game.use_loop_buckets(PackedStringArray(["--bucket-cap", "--bucket-cap-density=2.5",
			"--loop-bucket-length=150"])), PackedStringArray())
	var train: Train = game.simulation.train
	assert_true(train.bucket_cap)
	assert_eq(train.bucket_cap_density, 2.5)
	assert_eq(train.bucket_length, 150.0)
	assert_false(train.front_first)
	var both := _game(true)
	assert_eq(both.use_loop_buckets(PackedStringArray(["--loop-buckets", "--bucket-cap"])), PackedStringArray())
	assert_true(both.simulation.train.front_first)
	assert_true(both.simulation.train.bucket_cap)


# A density not > 0, a value on --bucket-cap or a flag given twice is an
# error, nothing set.
# @test-link [[req_platform_and_performance_targets]]
func test_the_flags_reject_a_bad_density_and_a_repeat() -> void:
	for args in [["--bucket-cap", "--bucket-cap-density=0"], ["--bucket-cap", "--bucket-cap-density=-1"],
			["--bucket-cap", "--bucket-cap-density=x"], ["--bucket-cap", "--bucket-cap-density"],
			["--bucket-cap=1"], ["--bucket-cap", "--bucket-cap"],
			["--bucket-cap", "--bucket-cap-density=3", "--bucket-cap-density=5"]]:
		var game := _game(true)
		assert_eq(game.use_loop_buckets(PackedStringArray(args)).size(), 1, "%s" % [args])
		var train: Train = game.simulation.train
		assert_false(train.bucket_cap, "%s: nothing set" % [args])
		assert_eq(train.bucket_cap_density, BucketLoads.DEFAULT_DENSITY, "%s: nothing set" % [args])


# A release build (no level, so no train) refuses the flags, whichever is
# given, and sets nothing.
# @test-link [[req_platform_and_performance_targets]]
func test_a_release_build_refuses_the_flags() -> void:
	for args in [["--bucket-cap"], ["--bucket-cap-density=2"]]:
		var release := _game(false)
		var errors: PackedStringArray = release.use_loop_buckets(PackedStringArray(args))
		assert_eq(errors.size(), 1, "%s: refused" % [args])
		assert_eq(errors[0], release.LOOP_BUCKETS_REFUSED)
		assert_false(release.bucket_cap, "%s: nothing set" % [args])


# Test mode leaves the flags to the game root: a scripted run takes them.
# @test-link [[req_platform_and_performance_targets]]
func test_test_mode_leaves_the_flags_to_the_game_root() -> void:
	var parsed: Dictionary = load("res://src/test_mode/test_mode.gd").config_from_args(PackedStringArray([
			"--test-mode", "--seed=1", "--bucket-cap", "--bucket-cap-density=2.5"]))
	assert_eq(parsed["errors"], PackedStringArray())

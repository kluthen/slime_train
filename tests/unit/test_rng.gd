extends GutTest
## The one seeded random generator (Rng): same seed, same numbers; derived
## streams depend only on the master seed and their name.


func _draw_ints(rng: Rng, count: int) -> Array:
	var out := []
	for i in count:
		out.append(rng.randi())
	return out


func test_same_seed_gives_same_sequence() -> void:
	assert_eq(_draw_ints(Rng.new(1234), 20), _draw_ints(Rng.new(1234), 20))


func test_different_seed_gives_different_sequence() -> void:
	assert_ne(_draw_ints(Rng.new(1234), 20), _draw_ints(Rng.new(1235), 20))


func test_seed_zero_is_a_valid_seed() -> void:
	assert_eq(_draw_ints(Rng.new(0), 5), _draw_ints(Rng.new(0), 5))
	assert_eq(Rng.new(0).seed_value, 0)


func test_ranges_stay_in_bounds_and_repeat() -> void:
	var a := Rng.new(7)
	var b := Rng.new(7)
	for i in 200:
		var fa := a.randf_range(-2.0, 3.0)
		var ia := a.randi_range(1, 6)
		var f := a.randf()
		assert_between(fa, -2.0, 3.0)
		assert_between(ia, 1, 6)
		assert_between(f, 0.0, 1.0)
		assert_eq(fa, b.randf_range(-2.0, 3.0))
		assert_eq(ia, b.randi_range(1, 6))
		assert_eq(f, b.randf())


func test_pick_is_seeded() -> void:
	var items := ["a", "b", "c", "d", "e"]
	var a := Rng.new(99)
	var b := Rng.new(99)
	for i in 30:
		assert_eq(a.pick(items), b.pick(items))


func test_state_round_trip_replays_the_sequence() -> void:
	var rng := Rng.new(555)
	_draw_ints(rng, 7)
	var saved := rng.state
	var expected := _draw_ints(rng, 10)
	var restored := Rng.new(555)
	restored.state = saved
	assert_eq(_draw_ints(restored, 10), expected)


func test_derived_stream_is_repeatable_and_named() -> void:
	var master := Rng.new(42)
	assert_eq(_draw_ints(master.derive("slime:3"), 10), _draw_ints(Rng.new(42).derive("slime:3"), 10))
	assert_ne(_draw_ints(master.derive("slime:3"), 10), _draw_ints(master.derive("slime:4"), 10))
	assert_ne(_draw_ints(master.derive("slime:3"), 10), _draw_ints(Rng.new(43).derive("slime:3"), 10))


func test_derive_ignores_and_keeps_the_master_position() -> void:
	# A stream depends on the master seed only, not on how many numbers the
	# master has drawn, and deriving it doesn't draw from the master.
	var fresh := Rng.new(42)
	var used := Rng.new(42)
	_draw_ints(used, 13)
	assert_eq(_draw_ints(used.derive("hops"), 5), _draw_ints(fresh.derive("hops"), 5))
	var before := used.state
	used.derive("anything")
	assert_eq(used.state, before)


func test_derived_seed_is_stable_across_runs() -> void:
	# Pinned value: the first 8 bytes, little-endian, of SHA-256("42/slime:3"),
	# computed outside Godot. derive_seed must not depend on the process or the
	# engine version. If this changes, saved streams stop repeating.
	assert_eq(Rng.derive_seed(42, "slime:3"), Rng.derive_seed(42, "slime:3"))
	assert_eq(Rng.derive_seed(42, "slime:3"), 5029776682049808317)


func test_random_seed_varies() -> void:
	# Normal play (not test mode) starts from a fresh seed.
	var seeds := {}
	for i in 5:
		seeds[Rng.random_seed()] = true
	assert_gt(seeds.size(), 1)

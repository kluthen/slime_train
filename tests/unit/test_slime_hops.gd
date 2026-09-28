extends GutTest
## Hopping: slimes move only by hopping. A train slime hops every ~1.5-3 s,
## with a random timing per slime drawn from its own seeded stream; bigger
## slimes hop a little less often, but further and higher. Sleepers,
## bedtime-asleep slimes, and slimes held still (covered by others, resting in
## a full basket) don't hop. Following the loop is chunk 6: here a slime hops
## in place or in a fixed heading.
# @test-link [[req_hopping_behavior]]
# @test-link [[req_slime_states]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0


## Runs `ticks` ticks and returns, for each slime id, the ticks it hopped on.
func _hop_ticks(bodies: SlimeBodies, ticks: int) -> Dictionary:
	var out := {}
	for slime_id in bodies.ids():
		out[slime_id] = []
	for t in ticks:
		bodies.tick(DT)
		for slime_id in bodies.hopped:
			out[slime_id].append(t)
	return out


func test_hop_interval_range_per_size() -> void:
	var one := SlimeBodies.hop_interval_range(1)
	assert_almost_eq(one.x, 1.5, 0.001)
	assert_almost_eq(one.y, 3.0, 0.001)
	var two := SlimeBodies.hop_interval_range(2)
	var three := SlimeBodies.hop_interval_range(3)
	assert_gt(two.x, one.x, "bigger slimes hop a little less often")
	assert_gt(three.x, two.x)
	assert_lt(three.y, one.y * 1.5, "a little, not much")


func test_first_timers_are_in_range_for_every_size() -> void:
	for master_seed in 20:
		var bodies := SlimeBodies.new(Rng.new(master_seed))
		for size in [1, 2, 3]:
			var slime := bodies.create(0, size, Vector2(100 * size, 0))
			var bounds := SlimeBodies.hop_interval_range(size)
			var timer := bodies.hop_timer_of(slime)
			assert_between(timer, bounds.x, bounds.y, "seed %d size %d" % [master_seed, size])


func test_a_train_slime_hops_every_one_and_a_half_to_three_seconds() -> void:
	var bodies := Support.bodies_on_floor(3)
	var slimes: Array[int] = []
	for i in 4:
		slimes.append(bodies.create(i, 1, Vector2(-300 + 200 * i, -30)))
	var hops := _hop_ticks(bodies, 60 * 20)
	for slime in slimes:
		var ticks: Array = hops[slime]
		assert_gt(ticks.size(), 5, "slime %d hopped %d times in 20 s" % [slime, ticks.size()])
		for k in range(1, ticks.size()):
			var seconds: float = (ticks[k] - ticks[k - 1]) * DT
			assert_between(seconds, 1.5 - DT, 3.0 + 0.2, "slime %d interval %d" % [slime, k])


func test_the_timing_differs_per_slime() -> void:
	var bodies := Support.bodies_on_floor(3)
	for i in 4:
		bodies.create(0, 1, Vector2(-300 + 200 * i, -30))
	var timers := {}
	for slime in bodies.ids():
		timers[snappedf(bodies.hop_timer_of(slime), 0.001)] = true
	assert_eq(timers.size(), 4, "every slime draws its own timing")


func test_the_cadence_repeats_with_the_seed() -> void:
	var runs := []
	for master_seed in [11, 11, 12]:
		var bodies := Support.bodies_on_floor(master_seed)
		for i in 3:
			bodies.create(i, i + 1, Vector2(-300 + 250 * i, -50))
		runs.append(_hop_ticks(bodies, 600))
	assert_eq(runs[0], runs[1], "same seed, same hops")
	assert_ne(runs[0], runs[2], "another seed, other hops")


func test_a_slime_stream_does_not_depend_on_other_slimes() -> void:
	# Streams are per slime (Rng.derive by slime id): a slime draws the same
	# timing whatever other slimes draw.
	var alone := SlimeBodies.new(Rng.new(5))
	var crowded := SlimeBodies.new(Rng.new(5))
	var a := alone.create(0, 1, Vector2.ZERO)
	var b := crowded.create(0, 1, Vector2.ZERO)
	for i in 10:
		crowded.create(1, 2, Vector2(100 + 100 * i, 0))
	assert_eq(alone.hop_timer_of(a), crowded.hop_timer_of(b))


func test_sleepers_bedtime_asleep_and_held_slimes_do_not_hop() -> void:
	var bodies := Support.bodies_on_floor(4)
	var sleeper := bodies.create(0, 1, Vector2(-400, -30), SlimeBodies.SLEEPER)
	var asleep := bodies.create(1, 1, Vector2(-200, -30), SlimeBodies.BEDTIME_ASLEEP)
	var held := bodies.create(2, 1, Vector2(0, -30))
	bodies.set_hop_held(held, true)
	var train := bodies.create(3, 1, Vector2(200, -30))
	var free := bodies.create(4, 1, Vector2(400, -30), SlimeBodies.FREE)
	assert_false(bodies.can_hop(sleeper))
	assert_false(bodies.can_hop(asleep))
	assert_false(bodies.can_hop(held))
	assert_true(bodies.can_hop(train))
	var hops := _hop_ticks(bodies, 600)
	assert_eq(hops[sleeper], [], "sleeper")
	assert_eq(hops[asleep], [], "bedtime-asleep")
	assert_eq(hops[held], [], "held (covered or in a full basket)")
	assert_gt(hops[train].size(), 0, "a train slime hops")
	assert_gt(hops[free].size(), 0, "a free slime hops")
	# Released, the held slime hops again.
	bodies.set_hop_held(held, false)
	assert_gt(_hop_ticks(bodies, 300)[held].size(), 0)


func test_a_slime_in_the_air_waits_to_land_before_hopping() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	var slime := bodies.create(0, 1, Vector2.ZERO)
	assert_eq(_hop_ticks(bodies, 300)[slime], [], "never supported, never hops")


func test_bigger_slimes_hop_higher_and_further() -> void:
	var rise := {}
	var run := {}
	for size in [1, 3]:
		var bodies := Support.bodies_on_floor(1)
		bodies.auto_hops = false
		var slime := bodies.create(0, size, Vector2(0, -60))
		for i in 90:
			bodies.tick(DT)
		var start := bodies.centre_of(slime)
		assert_true(bodies.hop(slime, Vector2(0.4, -1.0), 1.0))
		var top := start.y
		for i in 90:
			bodies.tick(DT)
			top = minf(top, bodies.centre_of(slime).y)
		rise[size] = start.y - top
		run[size] = bodies.centre_of(slime).x - start.x
		gut.p("size %d: rise %.1f px, run %.1f px" % [size, rise[size], run[size]])
	assert_gt(rise[1], 40.0, "a hop leaves the ground")
	assert_gt(rise[3], rise[1] * 1.15, "higher")
	assert_gt(run[3], run[1] * 1.1, "further")


func test_hop_impulse_scales_with_size_and_strength() -> void:
	var direction := Vector2(0.3, -1.0)
	var one := SlimeBodies.hop_velocity(1, direction, 1.0)
	assert_almost_eq(one.normalized(), direction.normalized(), Vector2(0.001, 0.001))
	assert_gt(SlimeBodies.hop_velocity(3, direction, 1.0).length(), one.length())
	assert_almost_eq(SlimeBodies.hop_velocity(1, direction, 0.5).length(), one.length() * 0.5, 0.01)


func test_hop_refused_for_a_missing_slime() -> void:
	var bodies := SlimeBodies.new(Rng.new(1))
	assert_false(bodies.hop(42, Vector2.UP, 1.0))


func test_heading_sets_the_hop_direction() -> void:
	var bodies := Support.bodies_on_floor(2)
	var right := bodies.create(0, 1, Vector2(400, -30))
	var left := bodies.create(1, 1, Vector2(-400, -30))
	var still := bodies.create(2, 1, Vector2(0, -30))
	bodies.set_heading(right, 1.0)
	bodies.set_heading(left, -1.0)
	var starts := {right: bodies.centre_of(right).x, left: bodies.centre_of(left).x, still: bodies.centre_of(still).x}
	_hop_ticks(bodies, 60 * 8)
	assert_gt(bodies.centre_of(right).x - starts[right], 100.0, "heading right")
	assert_lt(bodies.centre_of(left).x - starts[left], -100.0, "heading left")
	assert_almost_eq(bodies.centre_of(still).x, starts[still], 20.0, "hops in place")

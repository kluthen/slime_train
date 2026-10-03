extends GutTest
## Train (src/sim/train.gd): a train slime's progress along the loop is
## re-derived each tick by projecting its centre onto the loop, but only onto
## a window just ahead of its last progress, so it never snaps backward or
## across the level to a part of the loop that happens to be close; it wraps
## at the end of the loop. Hops are aimed ballistically at the route ahead.
##
## The synthetic loop: outgoing (0,0) -> (400,0) -> (400,-100) -> (800,-100),
## then a return route (800,-100) -> (800,60) -> (0,60) -> (0,0), which runs
## back 60 px under the outgoing part. Length 400+100+400 + 160+800+60 = 1920.

# @test-link [[req_loop_and_world]]
# @test-link [[req_hopping_behavior]]
# @test-link [[req_platform_and_performance_targets]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const LENGTH := 1920.0
const GRAVITY := 1400.0


func _loop() -> LoopData:
	var loop := LoopData.new("start.loop")
	loop.add_segment("s1.loop", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(0, 0), Vector2(400, 0), Vector2(400, -100), Vector2(800, -100)]))
	loop.add_segment("s1.slide", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(800, -100), Vector2(800, 60), Vector2(0, 60), Vector2(0, 0)]), "s1.gate")
	return loop


func _train() -> Train:
	return Train.new(_loop())


func test_the_train_reads_the_current_loop() -> void:
	var train := _train()
	assert_almost_eq(train.length(), LENGTH, 0.01)
	assert_eq(train.position_at(200.0), Vector2(200, 0))
	assert_eq(train.position_at(LENGTH + 200.0), Vector2(200, 0), "distances wrap")
	assert_false(train.is_slide_at(200.0))
	assert_true(train.is_slide_at(1000.0))


func test_progress_follows_the_slime_forward() -> void:
	var train := _train()
	assert_almost_eq(train.project(100.0, Vector2(150, -20)), 150.0, 0.01)
	assert_almost_eq(train.project(100.0, Vector2(300, 5)), 300.0, 0.01)


func test_progress_never_snaps_backward() -> void:
	var train := _train()
	# The slime was bumped back behind its progress: progress stays put.
	assert_almost_eq(train.project(300.0, Vector2(200, 0)), 300.0, 0.01)
	assert_almost_eq(train.project(300.0, Vector2(-50, 0)), 300.0, 0.01)


func test_progress_does_not_snap_across_the_level() -> void:
	var train := _train()
	# At (200, 55) the slime is 5 px from the return route, which runs under
	# the outgoing part, but 55 px from the outgoing part. Its progress is on
	# the outgoing part, so it stays there: the return route is far ahead.
	var progress := train.project(150.0, Vector2(200, 55))
	assert_almost_eq(progress, 200.0, 0.01)
	# And far ahead along the loop, even when right on it, is out of reach.
	assert_almost_eq(train.project(150.0, Vector2(600, -100)), 150.0 + Train.PROGRESS_WINDOW, 0.01,
			"capped at the end of the window")


func test_progress_wraps_at_the_end_of_the_loop() -> void:
	var train := _train()
	# On the return route's last stretch, the slime moves past the start.
	var near_end := LENGTH - 30.0
	assert_eq(train.position_at(near_end), Vector2(0, 30))
	var progress := train.project(near_end, Vector2(20, -5))
	assert_almost_eq(progress, LENGTH + 20.0, 0.01, "unwrapped: one lap plus 20 px")


func test_a_tracked_slime_counts_its_laps() -> void:
	var train := _train()
	train.track(7, LENGTH - 30.0)
	train.advance(7, Vector2(20, -5), 0)
	assert_eq(train.laps_of(7), 1)
	assert_almost_eq(train.distance_of(7), 20.0, 0.01)
	assert_almost_eq(train.progress_of(7), LENGTH + 20.0, 0.01)


# The move to the start of the loop and the log: tests/unit/test_train_stalled.gd.
# @test-link [[rule_stalled_train_slime_moved_to_start]]
func test_a_slime_whose_progress_stalls_for_a_minute_is_stalled() -> void:
	var train := _train()
	train.track(3, 100.0)
	var stall := int(Train.STALL_SECONDS * Simulation.TICK_RATE)
	for tick in stall - 1:
		train.advance(3, Vector2(100, 0), tick)
		assert_eq(train.stall_of(3, Vector2(100, 0), tick), "")
	train.advance(3, Vector2(100, 0), stall)
	assert_eq(train.stall_of(3, Vector2(100, 0), stall), Train.STALLED)
	train.advance(3, Vector2(100 + Train.STALL_ADVANCE, 0), stall + 1)
	assert_eq(train.stall_of(3, Vector2(100 + Train.STALL_ADVANCE, 0), stall + 1), "", "an advance restarts the count")


# @test-link [[rule_stalled_train_slime_moved_to_start]]
func test_a_slime_that_leaves_the_level_bounds_is_out_of_bounds() -> void:
	var train := _train()
	train.bounds = Rect2(-100, -500, 1000, 700)
	train.track(4, 100.0)
	train.advance(4, Vector2(100, 150), 1)
	assert_eq(train.stall_of(4, Vector2(100, 150), 1), "")
	train.advance(4, Vector2(100, 250), 2)
	assert_eq(train.stall_of(4, Vector2(100, 250), 2), Train.OUT_OF_BOUNDS)


# --- Hop aim -----------------------------------------------------------------

## Where a projectile launched from `from` at `velocity` comes down through
## the height `land_y` (no drag).
func _landing_x(from: Vector2, velocity: Vector2, land_y: float) -> float:
	# y(t) = from.y + vy t + g t^2 / 2 = land_y, the later root.
	var a := GRAVITY * 0.5
	var b := velocity.y
	var c := from.y - land_y
	var t := (-b + sqrt(b * b - 4.0 * a * c)) / (2.0 * a)
	return from.x + velocity.x * t


func test_an_aimed_hop_lands_on_its_target() -> void:
	for case in [[Vector2(0, 0), Vector2(150, 0)], [Vector2(0, 0), Vector2(120, -60)],
			[Vector2(0, 0), Vector2(160, 80)], [Vector2(0, 0), Vector2(-140, -20)]]:
		var from: Vector2 = case[0]
		var to: Vector2 = case[1]
		var velocity := Train.aim(from, to, 30.0, GRAVITY, 1000.0)
		assert_lt(velocity.y, 0.0, "a hop goes up first")
		assert_almost_eq(_landing_x(from, velocity, to.y), to.x, 0.5, "lands on %s" % to)
		# The top of the arc clears the higher end by the apex height.
		var apex_y := from.y - velocity.y * velocity.y / (2.0 * GRAVITY)
		assert_almost_eq(apex_y, minf(from.y, to.y) - 30.0, 0.5)


func test_an_aimed_hop_is_capped() -> void:
	var velocity := Train.aim(Vector2.ZERO, Vector2(900, -50), 30.0, GRAVITY, 600.0)
	assert_lte(velocity.length(), 600.01)
	assert_gt(velocity.x, 0.0, "still forward")


func test_bigger_slimes_hop_further_and_higher() -> void:
	assert_gt(Train.hop_reach(2), Train.hop_reach(1))
	assert_gt(Train.hop_reach(3), Train.hop_reach(2))
	assert_gt(Train.hop_apex(3), Train.hop_apex(1))


func test_the_hop_target_is_on_the_route_ahead() -> void:
	var train := _train()
	var reach := Train.hop_reach(1)
	assert_eq(train.hop_target(100.0, reach), Vector2(100.0 + reach, 0))


func test_the_hop_target_goes_just_past_the_top_of_a_drop() -> void:
	# From 750, the route drops at x = 800 (into the return route, which runs
	# back under it): aim just past the top of the drop, going on to the right.
	var train := _train()
	assert_eq(train.hop_target(750.0, Train.hop_reach(1)), Vector2(800.0 + Train.DROP_OVER, -100))


func test_the_hop_target_stops_at_the_foot_of_a_step() -> void:
	# From 250, the route ahead climbs straight up at x = 400 (a step the
	# route crosses in the air): first hop to the foot of the step.
	var train := _train()
	var target := train.hop_target(250.0, 200.0)
	assert_eq(target, Vector2(400.0 - Train.STEP_FOOT, 0))


func test_the_hop_target_skips_a_steep_rise_from_its_foot() -> void:
	# From the foot, the target moves on to the top of the step.
	var train := _train()
	var target := train.hop_target(400.0 - Train.STEP_FOOT, 100.0)
	assert_eq(target.y, -100.0, "on top of the step, not on its face")
	assert_gt(target.x, 400.0)
	var reach := Train.hop_reach(1)
	assert_eq(train.hop_target(390.0, reach),
			Vector2(400.0 + minf(Train.STEP_LANDING, reach * Train.MAX_REACH_FACTOR - 110.0), -100))


func test_a_slime_knocked_off_the_route_steers_from_the_route_near_it() -> void:
	var train := _train()
	# On the route: it steers from its progress.
	assert_eq(train.steering_distance(700.0, Vector2(700, -110)), 700.0)
	# Knocked back down the step, far from the route point at its progress:
	# it steers from the route point nearest it, behind, without going back.
	assert_almost_eq(train.steering_distance(700.0, Vector2(300, -10)), 300.0, 0.01)
	assert_almost_eq(train.project(700.0, Vector2(300, -10)), 700.0, 0.01, "progress stays put")


# --- Hop counters (the PERF line's hops and short_hops) ----------------------

## A floor whose top is at y = 0 (x -2000 to 2000), and a train on a loop
## along it at a base slime's centre height, x -1500 to 1500, returning
## under the floor. Loop distance d is x = d - 1500 on the outgoing part.
func _flat_train() -> Train:
	var loop := LoopData.new("flat.loop")
	loop.add_segment("flat.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("flat.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]))
	return Train.new(loop)


## One tick as Simulation.step orders it: the train steers (aims the hops)
## when `steered`, the bodies tick, the train follows.
func _hop_step(bodies: SlimeBodies, train: Train, tick: int, steered := true) -> void:
	if steered:
		train.steer(bodies, 1.0 / 60.0)
	bodies.tick(1.0 / 60.0)
	train.follow(bodies, tick)


## A base slime of `state` standing on the floor at x = -1000 (500 px along
## the loop), settled, its next automatic hop `hop_in` s away. Returns [bodies,
## train, its id].
func _settled_slime(state: int, hop_in: float) -> Array:
	var bodies := Support.bodies_on_floor()
	var train := _flat_train()
	var slime := bodies.create(0, 1, Vector2(-1000, -24), state)
	bodies.set_hop_timer(slime, 10.0)
	for tick in 30:
		_hop_step(bodies, train, tick)
	bodies.set_hop_timer(slime, hop_in)
	return [bodies, train, slime]


## Runs ticks from 30 until the train counts a hop (at most 2 s), then
## `after` more. Returns the progress the slime had at take-off.
func _until_a_hop_and(bodies: SlimeBodies, train: Train, slime: int, after: int, steered := true) -> float:
	var tick := 30
	var before := train.progress_of(slime)
	while train.hops_taken == 0 and tick < 150:
		before = train.progress_of(slime)
		_hop_step(bodies, train, tick, steered)
		tick += 1
	for k in after:
		_hop_step(bodies, train, tick + k, steered)
	return before


# @test-link [[req_platform_and_performance_targets]]
func test_a_train_slimes_automatic_hop_counts_one_hop_and_a_full_one_no_short_hop() -> void:
	var setup := _settled_slime(SlimeBodies.TRAIN, 0.2)
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	assert_eq(train.hops_taken, 0)
	var before := _until_a_hop_and(bodies, train, slime, 60)
	assert_eq(train.hops_taken, 1, "one automatic hop")
	assert_gt(train.progress_of(slime) - before, Train.hop_reach(1) * 0.5, "a full hop")
	assert_eq(train.short_hops_taken, 0, "a full hop is no short hop")


# @test-link [[req_platform_and_performance_targets]]
func test_a_hop_landing_less_than_half_its_reach_ahead_counts_a_short_hop() -> void:
	# Unsteered, the slime hops straight up (heading 0): it lands where it was.
	var setup := _settled_slime(SlimeBodies.TRAIN, 0.2)
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	var before := _until_a_hop_and(bodies, train, slime, 1, false)
	assert_eq(train.hops_taken, 1)
	assert_eq(train.short_hops_taken, 0, "counted at its landing, not at take-off")
	for tick in range(200, 260):
		_hop_step(bodies, train, tick, false)
	assert_lt(train.progress_of(slime) - before, Train.hop_reach(1) * 0.5)
	assert_eq(train.short_hops_taken, 1, "landed short")
	assert_eq(train.hops_taken, 1)


# @test-link [[req_platform_and_performance_targets]]
func test_a_celebration_hop_is_no_train_hop() -> void:
	var setup := _settled_slime(SlimeBodies.TRAIN, 10.0)
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	assert_true(bodies.hop(slime, Vector2.UP, 0.5), "the celebration's hop")
	for tick in range(30, 90):
		_hop_step(bodies, train, tick)
	assert_eq(train.hops_taken, 0)
	assert_eq(train.short_hops_taken, 0)


# @test-link [[req_platform_and_performance_targets]]
func test_a_free_slimes_hop_is_no_train_hop() -> void:
	var setup := _settled_slime(SlimeBodies.FREE, 0.0)
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var hopped := false
	for tick in range(30, 90):
		_hop_step(bodies, train, tick)
		hopped = hopped or not bodies.hopped.is_empty()
	assert_true(hopped, "the free slime hopped")
	assert_eq(train.hops_taken, 0)
	assert_eq(train.short_hops_taken, 0)


# @test-link [[req_platform_and_performance_targets]]
func test_a_hop_that_never_lands_as_a_train_slime_is_no_short_hop() -> void:
	var setup := _settled_slime(SlimeBodies.TRAIN, 0.2)
	var bodies: SlimeBodies = setup[0]
	var train: Train = setup[1]
	var slime: int = setup[2]
	_until_a_hop_and(bodies, train, slime, 1, false)
	assert_eq(train.hops_taken, 1)
	bodies.set_state(slime, SlimeBodies.FREE)
	bodies.set_hop_timer(slime, 10.0)
	for tick in range(200, 260):
		_hop_step(bodies, train, tick, false)
	assert_eq(train.hops_taken, 1)
	assert_eq(train.short_hops_taken, 0, "it landed as a free slime")

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

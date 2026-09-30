extends GutTest
## FixedStep: turns frame time into whole simulation ticks, so the number of
## ticks depends on elapsed time only, not on the frame rate.


func _ticks_for_frames(frame_seconds: float, frames: int, max_ticks := 1000) -> int:
	var clock := FixedStep.new()
	var total := 0
	for i in frames:
		total += clock.advance(frame_seconds, max_ticks)
	return total


func test_one_tick_per_sixtieth_of_a_second() -> void:
	assert_eq(Simulation.TICK_RATE, 60)
	var clock := FixedStep.new()
	assert_eq(clock.advance(1.0 / 60.0, 8), 1)


func test_small_frames_accumulate() -> void:
	var clock := FixedStep.new()
	assert_eq(clock.advance(1.0 / 120.0, 8), 0)
	assert_eq(clock.advance(1.0 / 120.0, 8), 1)


func test_tick_count_does_not_depend_on_frame_rate() -> void:
	# Two seconds of play at 30, 60, 144 and 240 frames per second.
	assert_eq(_ticks_for_frames(1.0 / 30.0, 60), 120)
	assert_eq(_ticks_for_frames(1.0 / 60.0, 120), 120)
	assert_eq(_ticks_for_frames(1.0 / 144.0, 288), 120)
	assert_eq(_ticks_for_frames(1.0 / 240.0, 480), 120)


func test_long_frame_is_capped_and_the_excess_dropped() -> void:
	var clock := FixedStep.new()
	assert_eq(clock.advance(1.0, 8), 8)
	# The excess is dropped, not carried: the game slows down instead of
	# spiralling after a hitch.
	assert_eq(clock.advance(0.0, 8), 0)


func test_zero_and_negative_time_do_nothing() -> void:
	var clock := FixedStep.new()
	assert_eq(clock.advance(0.0, 8), 0)
	assert_eq(clock.advance(-1.0, 8), 0)
	assert_eq(clock.advance(1.0 / 60.0, 8), 1)


func test_reset_clears_the_remainder() -> void:
	var clock := FixedStep.new()
	clock.advance(1.0 / 120.0, 8)
	clock.reset()
	assert_eq(clock.advance(1.0 / 120.0, 8), 0)


# The frame loop's cap policy (chunk 22, proposed): the game root runs at
# most FixedStep.max_ticks_for(speed, MAX_TICKS_PER_FRAME) ticks a frame.
# @test-link [[req_platform_and_performance_targets]]
func test_the_cap_is_the_1x_cap_times_the_speed_rounded_up() -> void:
	assert_eq(FixedStep.max_ticks_for(1.0, 2), 2)
	assert_eq(FixedStep.max_ticks_for(0.5, 2), 2, "slower than 1x keeps the 1x cap")
	assert_eq(FixedStep.max_ticks_for(0.0, 2), 2, "paused")
	assert_eq(FixedStep.max_ticks_for(1.5, 2), 4)
	assert_eq(FixedStep.max_ticks_for(4.0, 2), 8, "a debug speed keeps its pace")
	assert_eq(FixedStep.max_ticks_for(10.0, 3), 30)


# @test-link [[req_platform_and_performance_targets]]
func test_the_game_caps_at_two_ticks_a_frame_at_1x() -> void:
	assert_eq(load("res://src/main.gd").MAX_TICKS_PER_FRAME, 2)


## An overloaded frame (20 fps: 3 ticks' worth) plays in slow motion at 1x
## (2 ticks a frame, 40 ticks/s) instead of running more ticks per frame,
## which would make the next frame longer still.
# @test-link [[req_platform_and_performance_targets]]
func test_an_overloaded_frame_plays_in_slow_motion() -> void:
	var cap := FixedStep.max_ticks_for(1.0, load("res://src/main.gd").MAX_TICKS_PER_FRAME)
	assert_eq(_ticks_for_frames(1.0 / 20.0, 20, cap), 40)
	assert_eq(_ticks_for_frames(1.0 / 30.0, 60, cap), 120, "30 fps still runs at full speed")

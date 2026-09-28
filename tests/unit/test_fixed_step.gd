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

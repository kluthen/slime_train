extends GutTest
## The load meter (src/platform/load_meter.gd, D141, chunk 22c), driven by an
## injected clock and frame feed: each window of about 1 s of real time is
## pressed (busy share above 85 %, or 3 missed beats or more), calm (below
## 60 % and at most 1 missed beat) or in the band; a pressed window raises
## the detail ceiling one step, 3 calm windows in a row lower it one step, the
## band holds it; at most one step a window. A window holding a frame over
## 250 ms, or a frame at a speed other than 1x, gives no verdict.
# @test-link [[req_offscreen_simulation]]

## A 60 Hz frame, real microseconds: 60 of them make a window.
const FRAME := 16_667

var _now := [0]


func _meter() -> LoadMeter:
	var meter := LoadMeter.new()
	autofree(meter)
	_now = [0]
	var now := _now
	meter.clock = func() -> int: return now[0]
	# The first frame only starts the window.
	assert_eq(meter.feed(0, 1, 1.0), "")
	return meter


## One frame of `length` us ending now (the clock moved on), `busy` us of it
## working, `ticks` run at `speed`. Returns feed()'s verdict.
func _frame(meter: LoadMeter, length: int, busy: int, ticks := 1, speed := 1.0) -> String:
	_now[0] += length
	return meter.feed(busy, ticks, speed)


## One window of 60 frames at a busy share `share`, its first `missed`
## frames running 2 ticks, at `speed`. Returns its verdict (the last
## frame's: the one that closes it), checking that no frame before closed one.
func _window(meter: LoadMeter, share: float, missed := 0, speed := 1.0) -> String:
	for k in 59:
		assert_eq(_frame(meter, FRAME, int(share * FRAME), 2 if k < missed else 1, speed), "",
				"the window is still open at frame %d" % k)
	return _frame(meter, FRAME, int(share * FRAME), 1, speed)


func _windows(meter: LoadMeter, share: float, count: int, missed := 0) -> Array:
	var ceilings := []
	for k in count:
		_window(meter, share, missed)
		ceilings.append(meter.ceiling)
	return ceilings


# --- Verdicts ------------------------------------------------------------------------------------

func test_the_verdict_of_a_window() -> void:
	assert_eq(LoadMeter.verdict_for(0.86, 0), LoadMeter.PRESSED, "busy above 85 %")
	assert_eq(LoadMeter.verdict_for(0.85, 2), LoadMeter.BAND, "85 % with 2 missed beats is neither")
	assert_eq(LoadMeter.verdict_for(0.10, 3), LoadMeter.PRESSED, "3 missed beats")
	assert_eq(LoadMeter.verdict_for(0.59, 1), LoadMeter.CALM, "a stray hitch is tolerated")
	assert_eq(LoadMeter.verdict_for(0.59, 2), LoadMeter.BAND)
	assert_eq(LoadMeter.verdict_for(0.60, 0), LoadMeter.BAND, "60 % is not calm")
	assert_eq(LoadMeter.verdict_for(0.70, 0), LoadMeter.BAND)


func test_a_window_lasts_about_a_second_and_measures_its_share() -> void:
	var meter := _meter()
	assert_eq(_window(meter, 0.9, 1), LoadMeter.PRESSED)
	assert_almost_eq(float(meter.last_window["busy"]), 0.9, 0.001)
	assert_eq(meter.last_window["missed"], 1)
	assert_eq(_window(meter, 0.3, 3), LoadMeter.PRESSED, "missed beats alone press it")
	assert_eq(meter.last_window["missed"], 3, "the count starts again each window")


# --- The ceiling ---------------------------------------------------------------------------------

func test_it_starts_at_0_and_a_pressed_window_steps_up() -> void:
	var meter := _meter()
	assert_eq(meter.ceiling, 0)
	watch_signals(meter)
	assert_eq(_window(meter, 0.95), LoadMeter.PRESSED)
	assert_eq(meter.ceiling, 1)
	assert_signal_emit_count(meter, "stepped", 1)
	var step: Dictionary = get_signal_parameters(meter, "stepped")[0]
	assert_eq(step["from"], 0)
	assert_eq(step["to"], 1)
	assert_eq(step["reason"], LoadMeter.PRESSED)
	assert_almost_eq(float(step["busy"]), 0.95, 0.001)


func test_at_most_one_step_per_window() -> void:
	var meter := _meter()
	assert_eq(_windows(meter, 1.0, 4, 60), [1, 2, 3, 3], "fully pressed: one step a window, up to 3")
	assert_eq(_windows(meter, 0.1, 9), [3, 3, 2, 2, 2, 1, 1, 1, 0], "calm: one step every 3 windows")


func test_the_band_holds_the_ceiling_and_restarts_the_calm_count() -> void:
	var meter := _meter()
	_windows(meter, 0.95, 2)
	assert_eq(meter.ceiling, 2)
	assert_eq(_windows(meter, 0.7, 5), [2, 2, 2, 2, 2], "in the band it holds")
	_windows(meter, 0.1, 2)
	assert_eq(_window(meter, 0.7), LoadMeter.BAND)
	assert_eq(meter.calm_run, 0, "the band restarts the calm count")
	assert_eq(_windows(meter, 0.1, 3), [2, 2, 1], "3 calm windows in a row after it")


func test_3_calm_windows_step_down_and_the_count_starts_again() -> void:
	var meter := _meter()
	_windows(meter, 0.95, 2)
	watch_signals(meter)
	assert_eq(_windows(meter, 0.2, 6, 1), [2, 2, 1, 1, 1, 0])
	assert_signal_emit_count(meter, "stepped", 2)
	var step: Dictionary = get_signal_parameters(meter, "stepped", 1)[0]
	assert_eq([step["from"], step["to"], step["reason"]], [1, 0, LoadMeter.CALM])
	assert_eq(_windows(meter, 0.2, 3), [0, 0, 0], "never below 0")


func test_a_pressed_window_breaks_a_calm_run() -> void:
	var meter := _meter()
	_windows(meter, 0.95, 2)
	_windows(meter, 0.1, 2)
	assert_eq(_windows(meter, 0.95, 1), [3])
	assert_eq(_windows(meter, 0.1, 3), [3, 3, 2])


# --- Dropped windows -----------------------------------------------------------------------------

func test_a_window_with_a_frame_over_250_ms_is_dropped() -> void:
	var meter := _meter()
	watch_signals(meter)
	for k in 30:
		_frame(meter, FRAME, FRAME, 2)
	assert_eq(_frame(meter, 260_000, 260_000), "", "the long frame doesn't end the window")
	var verdict := ""
	while verdict == "":
		verdict = _frame(meter, FRAME, FRAME, 2)
	assert_eq(verdict, LoadMeter.DROPPED, "fully busy, missed beats, yet no verdict")
	assert_eq(meter.ceiling, 0)
	assert_signal_not_emitted(meter, "stepped")
	assert_eq(_window(meter, 0.95), LoadMeter.PRESSED, "the next window judges again")
	assert_eq(meter.ceiling, 1)


func test_a_frame_of_250_ms_exactly_is_kept() -> void:
	var meter := _meter()
	_frame(meter, 250_000, 250_000)
	var verdict := ""
	while verdict == "":
		verdict = _frame(meter, FRAME, FRAME)
	assert_eq(verdict, LoadMeter.PRESSED)


func test_a_long_pause_drops_its_window_at_once() -> void:
	var meter := _meter()
	_windows(meter, 0.95, 1)
	assert_eq(_frame(meter, 5_000_000, 1000), LoadMeter.DROPPED, "back from the background")
	assert_eq(meter.ceiling, 1, "held")


func test_a_debug_speed_other_than_1x_gives_no_verdict() -> void:
	for speed in [2.0, 0.5, 0.0, 8.0]:
		var meter := _meter()
		assert_eq(_window(meter, 1.0, 60, speed), LoadMeter.DROPPED, "at %sx" % speed)
		assert_eq(meter.ceiling, 0)
	var meter := _meter()
	for k in 59:
		_frame(meter, FRAME, FRAME, 2)
	assert_eq(_frame(meter, FRAME, FRAME, 2, 2.0), LoadMeter.DROPPED, "one frame at 2x drops the window")


func test_a_dropped_window_keeps_the_calm_run() -> void:
	var meter := _meter()
	_windows(meter, 0.95, 1)
	_windows(meter, 0.1, 2)
	assert_eq(_window(meter, 0.1, 0, 2.0), LoadMeter.DROPPED)
	assert_eq(meter.calm_run, 2, "no verdict: nothing changes")
	assert_eq(_windows(meter, 0.1, 1), [0])


# --- Reset, modes, the flag ----------------------------------------------------------------------

func test_reset_starts_again_at_0() -> void:
	var meter := _meter()
	_windows(meter, 0.95, 2)
	_windows(meter, 0.1, 1)
	meter.reset()
	assert_eq(meter.ceiling, 0)
	assert_eq(meter.calm_run, 0)
	assert_eq(meter.last_window["verdict"], "")
	_now[0] += 10_000_000
	assert_eq(meter.feed(1000, 1, 1.0), "", "the first frame after it only starts a window")
	assert_eq(_window(meter, 0.95), LoadMeter.PRESSED)
	assert_eq(meter.ceiling, 1)


func test_the_ceiling_each_mode_hands_over() -> void:
	var meter := _meter()
	_windows(meter, 0.95, 1)
	assert_eq(meter.ceiling_for(LoadMeter.AUTO), 1, "auto: the meter's")
	assert_eq(meter.ceiling_for(LoadMeter.ALWAYS), SlimeBodies.MAX_DETAIL, "always: D140's behaviour")
	assert_eq(meter.ceiling_for(LoadMeter.OFF), 0, "off: only the zoom's detail")


# @test-link [[req_test_level_and_test_mode]]
func test_the_flag() -> void:
	assert_eq(LoadMeter.parse_args(PackedStringArray(["--seed=1"])),
			{"mode": "", "errors": PackedStringArray()}, "not given")
	for mode in LoadMeter.MODES:
		var parsed := LoadMeter.parse_args(PackedStringArray(["--test-mode", "--crowd-detail=" + mode]))
		assert_eq(parsed["mode"], mode)
		assert_eq(parsed["errors"], PackedStringArray())
	for bad in ["--crowd-detail", "--crowd-detail=", "--crowd-detail=fast"]:
		var parsed := LoadMeter.parse_args(PackedStringArray([bad]))
		assert_eq(parsed["errors"].size(), 1, bad)
		assert_string_contains(parsed["errors"][0], "auto|always|off")
	var twice := LoadMeter.parse_args(PackedStringArray(["--crowd-detail=auto", "--crowd-detail=off"]))
	assert_string_contains(twice["errors"][0], "more than once")

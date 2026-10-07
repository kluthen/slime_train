class_name LoadMeter
extends Node
## The load meter (D141, chunk 22c): whether the device keeps up, measured on
## the real clock in the scene layer, in every build (release included: the
## debug-only perf log reports it, it can't be it). It moves the crowd
## detail's ceiling (Offscreen.detail_ceiling), which the game root hands to
## the simulation before every tick in `auto` (src/main.gd). `src/sim/`
## never reads a clock (CODING_RULE §2): this node does, through `clock`.
##
## Each frame (feed()) brings the real time of the frame's work, the busy
## time (from the tree's process_frame to this node's _process, which runs
## after the game root's and the drawing nodes': the ticks plus the rest of
## the game's _process, the perf log's process time), the ticks the fixed
## step ran and the speed it ran at. A window of WINDOW_USEC (about 1 s) of
## real time gives one verdict:
##   pressed    the busy share (the window's busy time over its length)
##              above PRESSED_SHARE (85 %), or PRESSED_MISSED (3) missed
##              beats or more: frames that ran 2 ticks or more (the fixed
##              step catching up: the game's 60 Hz pace slipped there);
##   calm       a busy share below CALM_SHARE (60 %) and at most
##              CALM_MISSED (1) missed beat (a stray hitch is tolerated);
##   band       neither;
##   dropped    no verdict: the window holds a frame over LONG_FRAME_USEC
##              (250 ms: a pause, a load, the app back from the
##              background), or a frame at a speed other than 1x (a debug
##              speed, test mode's time scale).
## The ceiling (0 to SlimeBodies.MAX_DETAIL) starts at 0, and at 0 again
## after reset() (the game root's: a new simulation, a load). A pressed
## window raises it one step; CALM_WINDOWS (3) calm windows in a row lower
## it one step, and the count starts again; a window in the band holds it and
## restarts the count; a dropped window changes nothing. So at most one step
## a window. Each step emits `stepped` with its reason.
##
## Modes (the game root's --crowd-detail, debug builds only; a release build
## is always AUTO): AUTO (this ceiling), ALWAYS (MAX_DETAIL, D140's
## behaviour, the simulation's own default) and OFF (0). The meter measures
## in every mode (the perf log reports it); only AUTO hands its ceiling over.
# @spec-link [[req_offscreen_simulation]]

## A window's length, real microseconds (about 1 s).
const WINDOW_USEC := 1_000_000
## A frame longer than this drops its window, microseconds.
const LONG_FRAME_USEC := 250_000
## Pressed: a busy share above this, or this many missed beats or more.
const PRESSED_SHARE := 0.85
const PRESSED_MISSED := 3
## Calm: a busy share below this and at most this many missed beats.
const CALM_SHARE := 0.60
const CALM_MISSED := 1
## Calm windows in a row that lower the ceiling one step.
const CALM_WINDOWS := 3
## A frame that ran this many ticks or more missed a beat.
const MISSED_TICKS := 2
## Its process priority: after the game root and the drawing nodes, just
## before the debug perf log (which runs last, at 1 << 30, and so reads
## this frame's window).
const PRIORITY := (1 << 30) - 1

## The verdicts (see the class doc).
const PRESSED := "pressed"
const CALM := "calm"
const BAND := "band"
const DROPPED := "dropped"

## The --crowd-detail modes, and the flag (debug builds only).
const AUTO := "auto"
const ALWAYS := "always"
const OFF := "off"
const MODES: PackedStringArray = [AUTO, ALWAYS, OFF]
const FLAG := "--crowd-detail"

## Emitted at each ceiling step: {"from", "to" (the ceilings), "reason"
## (PRESSED, or CALM after CALM_WINDOWS calm windows), "busy" (the share),
## "missed" (the beats) of the window that made it}.
signal stepped(step: Dictionary)

## The real clock, microseconds: Time.get_ticks_usec(). Tests put their own.
var clock := Callable(Time, "get_ticks_usec")
## The game root it measures (its parent when in the tree): its frame_ticks
## and frame_speed are read every frame. Null: no frame is fed.
var game: Node = null
## The detail ceiling, 0 to SlimeBodies.MAX_DETAIL.
var ceiling := 0
## Calm windows in a row since the last step or non-calm window.
var calm_run := 0
## The last window that ended: {"verdict" ("" before the first), "busy"
## (the share), "missed" (the beats)}.
var last_window := {"verdict": "", "busy": 0.0, "missed": 0}

## The clock at the window's start and at the last frame, or -1 before the
## first frame (which only starts the window).
var _window_start := -1
var _last_frame := -1
## The window's busy time (microseconds) and missed beats so far, and
## whether it is dropped.
var _busy_usec := 0
var _missed := 0
var _dropped := false
## The clock at this frame's process_frame, or -1 before the first.
var _process_start := -1


## Takes the game root (its parent), runs its _process after the game's, and
## starts timing each frame's work at the tree's process_frame.
func _ready() -> void:
	name = "LoadMeter"
	if game == null:
		game = get_parent()
	process_priority = PRIORITY
	get_tree().process_frame.connect(_on_process_frame)


## The frame's work starts: every _process of the tree comes after this.
func _on_process_frame() -> void:
	_process_start = clock.call()


## Feeds this frame: its busy time so far, the game root's ticks and speed.
func _process(_delta: float) -> void:
	if _process_start < 0 or game == null:
		return
	feed(clock.call() - _process_start, int(game.get("frame_ticks")), float(game.get("frame_speed")))


## One frame, ending now (clock): `busy_usec` of work, `ticks` run at
## `speed`. Returns the verdict of the window it closes (see the class doc),
## or "" while the window runs; the first frame only starts it.
# @spec-link [[req_offscreen_simulation]]
func feed(busy_usec: int, ticks: int, speed: float) -> String:
	assert(busy_usec >= 0 and ticks >= 0, "LoadMeter.feed: busy %d us, %d ticks" % [busy_usec, ticks])
	var now: int = clock.call()
	if _last_frame < 0:
		_last_frame = now
		_start_window(now)
		return ""
	if now - _last_frame > LONG_FRAME_USEC or speed != 1.0:
		_dropped = true
	_last_frame = now
	_busy_usec += busy_usec
	if ticks >= MISSED_TICKS:
		_missed += 1
	var length := now - _window_start
	if length < WINDOW_USEC:
		return ""
	var busy := float(_busy_usec) / length
	var verdict := DROPPED if _dropped else verdict_for(busy, _missed)
	last_window = {"verdict": verdict, "busy": busy, "missed": _missed}
	_start_window(now)
	_judge(verdict)
	return verdict


## The verdict of a window with busy share `busy` and `missed` beats.
# @spec-link [[req_offscreen_simulation]]
static func verdict_for(busy: float, missed: int) -> String:
	if busy > PRESSED_SHARE or missed >= PRESSED_MISSED:
		return PRESSED
	if busy < CALM_SHARE and missed <= CALM_MISSED:
		return CALM
	return BAND


## Back to the start: ceiling 0, no calm run, the window restarted at the
## next frame (the game root's, for a new simulation or a load).
# @spec-link [[req_offscreen_simulation]]
func reset() -> void:
	ceiling = 0
	calm_run = 0
	last_window = {"verdict": "", "busy": 0.0, "missed": 0}
	_last_frame = -1
	_start_window(-1)


## The ceiling the simulation takes in `mode` (MODES): this meter's in AUTO,
## SlimeBodies.MAX_DETAIL in ALWAYS, 0 in OFF.
# @spec-link [[req_offscreen_simulation]]
func ceiling_for(mode: String) -> int:
	match mode:
		AUTO:
			return ceiling
		ALWAYS:
			return SlimeBodies.MAX_DETAIL
		OFF:
			return 0
	assert(false, "LoadMeter: unknown crowd detail mode '%s'" % mode)
	return SlimeBodies.MAX_DETAIL


## Reads --crowd-detail=auto|always|off from the user arguments (after
## "--"); every other argument is left alone. Returns {"mode" ("" when not
## given), "errors"}: another value, or the flag given twice, is an error.
# @spec-link [[req_test_level_and_test_mode]]
static func parse_args(user_args: PackedStringArray) -> Dictionary:
	var result := {"mode": "", "errors": PackedStringArray()}
	for arg in user_args:
		if arg.get_slice("=", 0) != FLAG:
			continue
		var value := arg.substr(FLAG.length() + 1) if "=" in arg else ""
		if result["mode"] != "":
			result["errors"].append("%s is given more than once" % FLAG)
		elif not value in MODES:
			result["errors"].append("%s expects %s, got '%s'" % [FLAG, "|".join(MODES), value])
		else:
			result["mode"] = value
	return result


## A new window from `now` (-1: from the next frame).
func _start_window(now: int) -> void:
	_window_start = now
	_busy_usec = 0
	_missed = 0
	_dropped = false


## Moves the ceiling on `verdict` (see the class doc), emitting `stepped` at
## a step.
func _judge(verdict: String) -> void:
	var before := ceiling
	match verdict:
		PRESSED:
			calm_run = 0
			ceiling = mini(ceiling + 1, SlimeBodies.MAX_DETAIL)
		CALM:
			calm_run += 1
			if calm_run >= CALM_WINDOWS:
				calm_run = 0
				ceiling = maxi(ceiling - 1, 0)
		BAND:
			calm_run = 0
	if ceiling != before:
		stepped.emit({"from": before, "to": ceiling, "reason": verdict,
				"busy": last_window["busy"], "missed": last_window["missed"]})

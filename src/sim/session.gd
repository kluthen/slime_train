class_name Session
extends RefCounted
## Sessions, wind-down, bedtime and sunrise (master spec §5.7, D95): pure
## state, advanced by the Simulation once a tick. It never reads a clock: the
## scene layer hands it a reading before every tick (read_clock(); the game
## root reads the real clocks with SessionClock, test mode feeds TestClock).
##
##   screensaver mode --a tap that reaches the world--> session (15 min)
##   session --last minute--> wind-down --15 min reached--> bedtime
##   bedtime --10 min (or the parent's wake early, chunk 18)--> sunrise → screensaver mode
##
## `phase` is SCREENSAVER, SESSION, WIND_DOWN or BEDTIME; sunrise is the step
## from bedtime back to screensaver mode (sunrise()), not a phase that lasts.
## One timer, `elapsed_ms`, runs from the session's start: wind-down at
## 14:00, bedtime at 15:00, sunrise at 25:00 (the cooldown counts from when
## bedtime began). It is real time: time in the background, a killed app, a
## phone restart all count.
##
## The clocks. A reading is {"wall_ms", "mono_ms", "epoch"}: the wall clock
## (Unix time) and a monotonic clock, in whole milliseconds, and the epoch
## the monotonic clock counts in (it restarts with the process). The timer
## is stored with both: `anchor` (both clocks, and the timer, when counting
## last started over) and `clock` (the last reading, with its tick).
##   - Same epoch (the app kept running, maybe in the background): the timer
##     is the anchor's plus the larger of the two clocks' progress since the
##     anchor. The monotonic clock covers the wall clock being set back; the
##     wall clock covers the time a phone's monotonic clock doesn't count
##     (deep sleep, on Android).
##   - New epoch (the app was killed or the phone restarted): the monotonic
##     clock means nothing across it, so the gap is the wall clock's since
##     the last reading; the anchor starts over from this reading.
##   - The timer never goes back (a wall clock set back across a restart
##     loses the gap, never time already counted). Changing the phone's clock
##     can defeat the timers, which the spec accepts.
## The spec asks for both clocks without saying how they combine; this rule
## is the implementation's (docs/dev/README.md, "Chunk 17").
##
## Effects. Bedtime: every awake slime (train or free) falls asleep where it
## is (bedtime-asleep; sleepers stay sleepers), the edge buttons hide, the
## hint stops showing, and `save_due` asks the game to save. At bedtime taps
## still ripple but no longer call, operate objects or press edge buttons
## (Simulation._tap). Sunrise: the slimes wake (on the train when near the
## loop, else free and heading back), the edge buttons show, screensaver mode
## begins. Wind-down: dusk() drifts to 1 and slimes hop more slowly
## (hop_rate()). A session's start and a resumed session take the tilt's
## neutral (D95).
##
## `enabled`: whether the game has sessions, a mode set from outside (the
## game root's open() in normal play; test mode's "sessions"), not state.
## Without it the simulation plays untimed, as in an endless session: a tap
## starts nothing and screensaver mode (Simulation.screensaver) is left to
## whoever sets it. A running session or bedtime (from a save) counts down
## either way, and sunrise still lands in screensaver mode.
##
## Catching up: after a long gap the timer may pass several limits at once;
## each transition's effects apply in order. Sunrise then shows no cue when
## it came more than SUNRISE_CUE_LATE_MS late: a cooldown that ran out while
## the app was closed lands in screensaver mode without replaying sunrise.
# @spec-link [[req_session_lifecycle]]
# @spec-link [[req_actor_roles_and_permissions]]

const SCREENSAVER := "screensaver"
const SESSION := "session"
const WIND_DOWN := "wind_down"
const BEDTIME := "bedtime"
const PHASES := [SCREENSAVER, SESSION, WIND_DOWN, BEDTIME]

## A session's length, real seconds (specs/tuning.md: 15 min, fixed in v1).
const SESSION_SECONDS := 900
## The wind-down: the session's last minute, seconds.
const WIND_DOWN_SECONDS := 60
## The cooldown after bedtime, before sunrise, real seconds (10 min).
const COOLDOWN_SECONDS := 600
## When wind-down begins, bedtime begins and sunrise comes, as the timer's
## milliseconds.
const WIND_DOWN_MS := (SESSION_SECONDS - WIND_DOWN_SECONDS) * 1000
const BEDTIME_MS := SESSION_SECONDS * 1000
const SUNRISE_MS := (SESSION_SECONDS + COOLDOWN_SECONDS) * 1000
## How fast hop timers run at the end of the wind-down (1 is normal speed):
## slimes hop half as often by bedtime. Placeholder (specs/tuning.md: "slower
## in the last minute").
const WIND_DOWN_HOP_RATE := 0.5
## How long the light takes to come back after sunrise, seconds. Placeholder.
const SUNRISE_SECONDS := 3.0
## A sunrise later than this (the app was closed when it came) shows no cue.
const SUNRISE_CUE_LATE_MS := 1000

## Whether the game has sessions (see the class doc). Not in dump().
var enabled := false
## SCREENSAVER, SESSION, WIND_DOWN or BEDTIME.
var phase := SCREENSAVER
## The timer: milliseconds since the session started (0 in screensaver mode).
var elapsed_ms := 0
## When counting last started over: {"wall_ms", "mono_ms", "elapsed_ms"}, or
## {} in screensaver mode.
var anchor := {}
## The last reading counted: {"wall_ms", "mono_ms", "epoch", "tick"}, or {}.
var clock := {}
## The tick sunrise came on, for its cue, or -1 (none, or no cue).
var sunrise_tick := -1
## Set when bedtime begins: the game should save now. The game root clears
## it. Not in dump().
var save_due := false

## The reading for the next step (read_clock()). Like input: not in dump().
var _now := {}
## The app came back to the foreground (reopened()). Like input.
var _reopened := false


## A clock reading: the wall clock and the monotonic clock in whole
## milliseconds, and the monotonic clock's epoch.
static func reading(wall_ms: int, mono_ms: int, epoch: String) -> Dictionary:
	return {"wall_ms": wall_ms, "mono_ms": mono_ms, "epoch": epoch}


## The clocks now (a reading()), for the next step. The scene layer calls it
## before every tick; without readings time stands still.
func read_clock(now: Dictionary) -> void:
	_now = now.duplicate()


## The app came back to the foreground (the game root calls it): a session
## still running takes the tilt's neutral again on the next step (D95).
func reopened() -> void:
	_reopened = true


## Whether a session or bedtime is running (the timer counts).
func is_timed() -> bool:
	return phase != SCREENSAVER


## Whether a tap that reaches the world starts a session now.
func can_start() -> bool:
	return enabled and phase == SCREENSAVER


## The game has sessions from now on (normal play, or test mode's
## "sessions"): it lands in screensaver mode, or where its session or
## bedtime was (the next step catches up with the clocks).
func open(sim: Simulation) -> void:
	enabled = true
	sim.screensaver = phase == SCREENSAVER


## Starts a session now (the first tap that reaches the world): the timer
## starts from the current reading, and the tilt's neutral is taken.
func start(sim: Simulation) -> void:
	phase = SESSION
	elapsed_ms = 0
	anchor = {}
	clock = {}
	sunrise_tick = -1
	if not _now.is_empty():
		_count(_now, sim.tick)
	sim.phone_tilt.take_neutral_now()
	sim.screensaver = false


## Once a tick, after the input (a tap may have started a session) and
## before the slimes move: counts the clocks' progress, moves through the
## phases the timer has reached, and sets screensaver mode and the hop rate.
func advance(sim: Simulation) -> void:
	var was_timed := is_timed()
	if was_timed and not _now.is_empty():
		_count(_now, sim.tick)
	if phase == SESSION and elapsed_ms >= WIND_DOWN_MS:
		phase = WIND_DOWN
	if phase == WIND_DOWN and elapsed_ms >= BEDTIME_MS:
		phase = BEDTIME
		_bedtime(sim)
	if phase == BEDTIME and elapsed_ms >= SUNRISE_MS:
		sunrise(sim, elapsed_ms - SUNRISE_MS <= SUNRISE_CUE_LATE_MS)
	if _reopened and phase in [SESSION, WIND_DOWN]:
		sim.phone_tilt.take_neutral_now()
	_reopened = false
	if enabled or was_timed:
		sim.screensaver = phase == SCREENSAVER
	sim.slimes.hop_rate = hop_rate(sim.tick)


## Jumps the timer to `to_ms` (never back) as if that much time had passed,
## and moves through the phases it reaches. For tools and tests (fixtures).
func jump(sim: Simulation, to_ms: int) -> void:
	if not is_timed():
		return
	elapsed_ms = maxi(elapsed_ms, to_ms)
	if not clock.is_empty():
		anchor = {"wall_ms": clock["wall_ms"], "mono_ms": clock["mono_ms"], "elapsed_ms": elapsed_ms}
	var reopened_before := _reopened
	var now := _now
	_now = {}
	advance(sim)
	_now = now
	_reopened = reopened_before


## How long until the running timer's next limit, ms, for the parent (shown
## behind the code only, D114): in a session or its wind-down, until bedtime;
## at bedtime, until sunrise. -1 in screensaver mode, which has no timer. It
## reads `elapsed_ms` as the last step counted it, the session clock the
## phases follow, and is never below 0 (a restored timer past its limit
## before the next step catches up). A pure query.
# @spec-link [[rule_time_left_shown_only_behind_code]]
func time_left_ms() -> int:
	match phase:
		SESSION, WIND_DOWN:
			return maxi(0, BEDTIME_MS - elapsed_ms)
		BEDTIME:
			return maxi(0, SUNRISE_MS - elapsed_ms)
	return -1


## Sunrise (after the cooldown, or the parent's wake early, chunk 18: see
## Simulation.wake_early()): the slimes wake, the edge buttons show, and
## screensaver mode begins. `cue`: whether the light comes back gently
## (dusk()) or is simply day.
func sunrise(sim: Simulation, cue := true) -> void:
	_wake(sim)
	phase = SCREENSAVER
	elapsed_ms = 0
	anchor = {}
	clock = {}
	sunrise_tick = sim.tick if cue else -1
	sim.camera.edge_buttons_visible = true
	sim.hint.bedtime = false
	sim.screensaver = true


## How far the light has drifted toward dusk on `tick`: 0 (day) to 1 (dusk).
## It drifts over the wind-down, stays at 1 through bedtime, and comes back
## over SUNRISE_SECONDS after a sunrise with a cue.
func dusk(tick: int) -> float:
	match phase:
		WIND_DOWN:
			return clampf(float(elapsed_ms - WIND_DOWN_MS) / (WIND_DOWN_SECONDS * 1000.0), 0.0, 1.0)
		BEDTIME:
			return 1.0
		SCREENSAVER:
			if sunrise_tick >= 0:
				var t := float(tick - sunrise_tick) / (SUNRISE_SECONDS * Simulation.TICK_RATE)
				return clampf(1.0 - t, 0.0, 1.0)
	return 0.0


## How fast the slimes' hop timers run on `tick` (SlimeBodies.hop_rate): 1,
## slowing to WIND_DOWN_HOP_RATE over the wind-down.
func hop_rate(tick: int) -> float:
	if phase != WIND_DOWN:
		return 1.0
	return lerpf(1.0, WIND_DOWN_HOP_RATE, dusk(tick))


## The session's state as plain data, for Simulation.dump() and saves (all
## whole numbers and strings).
func dump() -> Dictionary:
	return {"phase": phase, "elapsed_ms": elapsed_ms, "anchor": anchor.duplicate(),
			"clock": clock.duplicate(), "sunrise_tick": sunrise_tick}


## Puts back dump()'s state (whole numbers already ints), then what it
## implies: at bedtime the edge buttons are hidden and the hint doesn't show.
func restore(sim: Simulation, data: Dictionary) -> void:
	phase = data.get("phase", SCREENSAVER)
	elapsed_ms = data.get("elapsed_ms", 0)
	anchor = data.get("anchor", {}).duplicate()
	clock = data.get("clock", {}).duplicate()
	sunrise_tick = data.get("sunrise_tick", -1)
	sim.camera.edge_buttons_visible = phase != BEDTIME
	sim.hint.bedtime = phase == BEDTIME
	if phase == BEDTIME:
		sim.camera.release(sim.camera.hold_finger)


## Takes over a session in `sim`, a fresh simulation of the same level: the
## parent deleted the level save and the session goes on untouched (D104;
## Simulation.carry_session() gives `data`, dump()'s shape in `sim`'s ticks,
## and `was_enabled`, whether the game had sessions). As restore(), plus what
## the fresh world needs: at bedtime its awake slimes fall asleep where they
## are (the game root saves the fresh level itself, so no save is asked), and
## screensaver mode and the hop rate follow the phase at once.
# @spec-link [[req_session_lifecycle]]
func take_over(sim: Simulation, data: Dictionary, was_enabled: bool) -> void:
	restore(sim, data)
	enabled = was_enabled
	if phase == BEDTIME:
		_bedtime(sim)
		save_due = false
	if enabled or is_timed():
		sim.screensaver = phase == SCREENSAVER
	sim.slimes.hop_rate = hop_rate(sim.tick)


## Counts the clocks' progress up to `now` (see the class doc).
func _count(now: Dictionary, tick: int) -> void:
	if clock.is_empty() or anchor.is_empty():
		anchor = {"wall_ms": now["wall_ms"], "mono_ms": now["mono_ms"], "elapsed_ms": elapsed_ms}
	elif now["epoch"] != clock["epoch"]:
		var gap := maxi(0, int(now["wall_ms"]) - int(clock["wall_ms"]))
		anchor = {"wall_ms": now["wall_ms"], "mono_ms": now["mono_ms"], "elapsed_ms": elapsed_ms + gap}
		_reopened = true
	var since := maxi(int(now["mono_ms"]) - int(anchor["mono_ms"]), int(now["wall_ms"]) - int(anchor["wall_ms"]))
	elapsed_ms = maxi(elapsed_ms, int(anchor["elapsed_ms"]) + since)
	clock = {"wall_ms": now["wall_ms"], "mono_ms": now["mono_ms"], "epoch": now["epoch"], "tick": tick}


## Bedtime: the awake slimes fall asleep where they are, the edge buttons
## hide (a held one lets go), the hint stops showing, and the game saves.
# @spec-link [[req_slime_states]]
func _bedtime(sim: Simulation) -> void:
	for slime_id in sim.slimes.ids():
		var state := sim.slimes.state_of(slime_id)
		if state == SlimeBodies.TRAIN or state == SlimeBodies.FREE:
			sim.slimes.set_state(slime_id, SlimeBodies.BEDTIME_ASLEEP)
			sim.slimes.set_hop_held(slime_id, false)
	sim.camera.edge_buttons_visible = false
	sim.camera.release(sim.camera.hold_finger)
	sim.hint.bedtime = true
	save_due = true


## Sunrise wakes the bedtime-asleep slimes: those near the loop (as near as
## a heading-back slime rejoins it) are the train again, the others are free
## and head back (FreeSlimes.follow adopts them).
func _wake(sim: Simulation) -> void:
	var loop: LoopData = sim.level.loop if sim.level != null else null
	var gates: Array = sim.train.open_gates if sim.train != null else []
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) != SlimeBodies.BEDTIME_ASLEEP:
			continue
		var near := false
		if loop != null and sim.train != null:
			var extra := sim.slimes.radius_of(slime_id) - SlimeBodies.RING_RADIUS_SIZE_1
			near = loop.closest(sim.slimes.centre_of(slime_id), gates)["gap"] <= FreeSlimes.REJOIN_DISTANCE + extra
		sim.slimes.set_state(slime_id, SlimeBodies.TRAIN if near else SlimeBodies.FREE)

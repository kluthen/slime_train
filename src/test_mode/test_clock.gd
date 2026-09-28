class_name TestClock
extends RefCounted
## Test mode's clocks for sessions (Session): a pure function of the tick,
## so that a scripted run is repeatable and a reloaded run reads the same
## clocks as the run that never stopped. Test mode feeds reading_at(tick)
## to the session before every tick, in place of the real clocks
## (SessionClock).
##
## Both clocks run with the simulation, 1000 / 60 ms a tick (floored), from
## a base: the save's last reading ("session.clock") and its tick, or
## DEFAULT_WALL_MS / DEFAULT_MONO_MS / EPOCH at tick 0 for a run without one.
## On top of that:
##   - the script's "skip" steps (TestModeScript): {"tick": T, "do": "skip",
##     "seconds": S} lets S seconds pass before tick T, as if the app sat in
##     the background meanwhile; both clocks jump, the simulation doesn't run.
##     Only skips on the run's start tick or later count (a reloaded run
##     doesn't count again the ones before its save).
##   - the run's "clock" setting (TestMode): "away" seconds passed before the
##     run starts (both clocks, as for a skip), and "restarted": true, the
##     app was killed or the phone restarted meanwhile: a new epoch, the
##     monotonic clock from 0.
# @spec-link [[req_session_lifecycle]]

const DEFAULT_WALL_MS := 1_800_000_000_000
const DEFAULT_MONO_MS := 0
const EPOCH := "test"

var base_wall_ms := DEFAULT_WALL_MS
var base_mono_ms := DEFAULT_MONO_MS
var base_tick := 0
var epoch := EPOCH
## The first tick of the run: skips before it don't count.
var start_tick := 0
## tick -> milliseconds skipped before it.
var skips := {}


## A clock for a run starting on `run_start_tick`, from a save's "session"
## (or null), with the run's "clock" setting ({"away", "restarted"}; {} for
## none) and the script's skips (tick -> ms).
static func for_run(session: Variant, run_start_tick: int, setting: Dictionary, script_skips: Dictionary) -> TestClock:
	var out := TestClock.new()
	out.start_tick = run_start_tick
	out.skips = script_skips.duplicate()
	if session is Dictionary and session.get("clock") is Dictionary and not session["clock"].is_empty():
		var saved: Dictionary = session["clock"]
		out.base_wall_ms = int(saved.get("wall_ms", DEFAULT_WALL_MS))
		out.base_mono_ms = int(saved.get("mono_ms", DEFAULT_MONO_MS))
		out.base_tick = int(saved.get("tick", 0))
		out.epoch = str(saved.get("epoch", EPOCH))
	var away_ms := roundi(float(setting.get("away", 0)) * 1000.0)
	out.base_wall_ms += away_ms
	out.base_mono_ms += away_ms
	if setting.get("restarted", false):
		out.epoch += "/restarted"
		out.base_mono_ms = 0
	return out


## The default reading at tick 0 (a fresh run's clocks), for fixtures.
static func default_reading() -> Dictionary:
	return Session.reading(DEFAULT_WALL_MS, DEFAULT_MONO_MS, EPOCH)


## Milliseconds from tick 0 to `tick`.
static func ms_at(tick: int) -> int:
	return floori(tick * 1000.0 / Simulation.TICK_RATE)


## The clocks before `tick`'s step (a Session.reading()).
func reading_at(tick: int) -> Dictionary:
	var ran := ms_at(tick) - ms_at(base_tick)
	var skipped := 0
	for at in skips:
		if at >= start_tick and at <= tick:
			skipped += skips[at]
	return Session.reading(base_wall_ms + ran + skipped, base_mono_ms + ran + skipped, epoch)

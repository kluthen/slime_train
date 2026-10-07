class_name PhaseTimers
extends RefCounted
## Per-phase timers of the simulation tick (chunk 5N, unit U0a): where a
## tick's time goes, phase by phase, so the solver's share (what 5N ports to
## native code) and the behaviour code's (what stays GDScript) can be told
## apart. Debug only.
##
## attach() hands a simulation and its slime bodies a timer each, their
## `phases` (null otherwise: off, the timers cost one null check per phase
## and read no clock). Simulation.step times its subsystem calls
## (Simulation.StepPhase) and SlimeBodies.tick its passes
## (SlimeBodies.TickPhase): each start() reads the monotonic clock
## (Time.get_ticks_usec()), each lap(phase) reads it again and adds the time
## since the previous read to that phase. Laps chain, so a tick's phases add
## up to the whole tick, however short each one. Nothing in the simulation
## reads a timer: the state, and so the state hash, are the same with them
## on or off (src/sim never reads a clock itself; only this file does).
##
## Read with means() (mean µs per tick, in tick order, the slime bodies'
## passes in place of the BODIES phase), take() (means() then clear(), the
## perf log's window), field() (the perf log's compact `phases=` value) and
## split() (solver against behaviour, SOLVER_PHASES).
##
## Who turns it on: tools/bench_level.gd --phases (the timed ticks of each
## case), and the game root's --phase-timers (main.gd, debug builds only,
## named by path there like the perf log, so the release preset can leave
## src/debug/ out; every simulation the game runs gets it, and the perf
## log's PERF line carries the means of its window).

## The phases that are the slime solver, as means() names them: what 5N
## moves to native code (integrate, the pair grid, contacts, rings, terrain
## and door passes, the touching list and the rest pass), and the native
## solver's step() that runs them all in one call (native). Everything else
## is behaviour (or tick glue), which stays GDScript.
const SOLVER_PHASES: PackedStringArray = ["integrate", "pairs", "contacts", "rings", "terrain", "doors", "rest",
		"native"]
## The step phase the slime bodies' own phases replace in means().
const BODIES_PHASE := "bodies"

## The phase names, in order (lower case: an enum's keys).
var names := PackedStringArray()
## Microseconds summed per phase since the last clear().
var usec := PackedInt64Array()
## start() calls since the last clear(): ticks timed.
var ticks := 0
## The clock at the last start() or lap(), microseconds.
var _mark := 0


## A timer for the phases `phase_names` (an enum's keys, in order).
func _init(phase_names: Array) -> void:
	for each in phase_names:
		names.append(String(each).to_lower())
	usec.resize(names.size())


## A tick starts: counts it and reads the clock.
func start() -> void:
	ticks += 1
	_mark = Time.get_ticks_usec()


## Phase `phase` (an index into names) just ended: the time since the last
## start() or lap() goes to it.
func lap(phase: int) -> void:
	var now := Time.get_ticks_usec()
	usec[phase] += now - _mark
	_mark = now


## Forgets every sum and tick.
func clear() -> void:
	usec.fill(0)
	ticks = 0


## Gives `sim` and its slime bodies a timer each (their `phases`).
# @spec-link [[req_platform_and_performance_targets]]
static func attach(sim: Simulation) -> void:
	sim.phases = PhaseTimers.new(Simulation.StepPhase.keys())
	sim.slimes.phases = PhaseTimers.new(SlimeBodies.TickPhase.keys())


## Takes `sim`'s timers away (off again).
static func detach(sim: Simulation) -> void:
	sim.phases = null
	sim.slimes.phases = null


## Whether `sim` has timers.
static func attached(sim: Simulation) -> bool:
	return sim.phases != null and sim.slimes.phases != null


## `sim`'s mean µs per tick by phase since the last clear(), in tick order,
## the slime bodies' passes in place of BODIES_PHASE: {name: µs}. Empty
## without timers or a timed tick. The means add up to the whole step.
# @spec-link [[req_platform_and_performance_targets]]
static func means(sim: Simulation) -> Dictionary:
	if not attached(sim) or sim.phases.ticks == 0:
		return {}
	var step: PhaseTimers = sim.phases
	var bodies: PhaseTimers = sim.slimes.phases
	var out := {}
	for i in step.names.size():
		if step.names[i] != BODIES_PHASE:
			out[step.names[i]] = float(step.usec[i]) / step.ticks
			continue
		for k in bodies.names.size():
			out[bodies.names[k]] = float(bodies.usec[k]) / step.ticks
	return out


## means(), then clears `sim`'s timers (a window's worth: the perf log's).
static func take(sim: Simulation) -> Dictionary:
	var out := means(sim)
	if attached(sim):
		sim.phases.clear()
		sim.slimes.phases.clear()
	return out


## The perf log's compact field value for `phase_means` (means()):
## "name:µs,name:µs,..." in order, whole µs; "" when empty.
static func field(phase_means: Dictionary) -> String:
	var parts := PackedStringArray()
	for name in phase_means:
		parts.append("%s:%.0f" % [name, phase_means[name]])
	return ",".join(parts)


## `phase_means` (means()) as a Markdown table (lines): one row per phase in
## order (its kind, solver or behaviour, its mean µs per tick and its share
## of the whole step), then the solver's, the behaviour's and the whole
## step's totals.
static func table(phase_means: Dictionary) -> PackedStringArray:
	var split_us := split(phase_means)
	var total := split_us.x + split_us.y
	var out := PackedStringArray(["| Phase | Kind | Mean µs/tick | Share |", "|---|---|---|---|"])
	for name in phase_means:
		out.append(_row(name, "solver" if name in SOLVER_PHASES else "behaviour", phase_means[name], total))
	out.append(_row("**solver**", "", split_us.x, total))
	out.append(_row("**behaviour**", "", split_us.y, total))
	out.append(_row("**whole step**", "", total, total))
	return out


## One row of table(): `name`, `kind`, `us` µs and its share of `total`.
static func _row(name: String, kind: String, us: float, total: float) -> String:
	return "| %s | %s | %.1f | %.1f %% |" % [name, kind, us, 100.0 * us / total if total > 0.0 else 0.0]


## `phase_means` (means()) split: Vector2(solver µs, behaviour µs), the
## solver being SOLVER_PHASES, the behaviour everything else.
static func split(phase_means: Dictionary) -> Vector2:
	var solver := 0.0
	var behaviour := 0.0
	for name in phase_means:
		if name in SOLVER_PHASES:
			solver += phase_means[name]
		else:
			behaviour += phase_means[name]
	return Vector2(solver, behaviour)

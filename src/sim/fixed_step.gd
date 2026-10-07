class_name FixedStep
extends RefCounted
## Turns frame time into whole simulation ticks (Simulation.TICK_RATE per
## second), so the simulation advances by elapsed time, never by frame count.
## The scene layer calls advance() every frame and runs one Simulation.step()
## per tick it returns.

## Time left over from earlier frames, in ticks (0 <= remainder < 1).
var _remainder := 0.0

# Absorbs float rounding: 1/60 s of frame time must give exactly one tick.
const _EPSILON := 1e-6


## Adds `delta_seconds` of frame time and returns how many ticks to run now,
## at most `max_ticks`. Past the cap the excess is dropped rather than carried
## over, so after a long hitch the game slows down instead of spiralling.
func advance(delta_seconds: float, max_ticks: int) -> int:
	if delta_seconds > 0.0:
		_remainder += delta_seconds * Simulation.TICK_RATE
	var ticks := floori(_remainder + _EPSILON)
	_remainder = maxf(_remainder - ticks, 0.0)
	if ticks > max_ticks:
		ticks = max_ticks
		_remainder = 0.0
	return ticks


## The most ticks one frame may run at speed `scale` (a time scale: test
## mode's times the debug overlay's): `cap_at_1x` (> 0) at 1x or below,
## times the speed rounded up above it, so a debug speed keeps its pace.
# @spec-link [[req_platform_and_performance_targets]]
static func max_ticks_for(scale: float, cap_at_1x: int) -> int:
	assert(cap_at_1x > 0, "FixedStep.max_ticks_for: the cap must be > 0")
	return cap_at_1x * maxi(1, ceili(scale))


## Forgets any leftover time (when a new simulation starts).
func reset() -> void:
	_remainder = 0.0

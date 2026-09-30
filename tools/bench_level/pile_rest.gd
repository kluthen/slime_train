extends RefCounted
## When a loaded bedtime pile comes to rest (chunk 22, D131): the lead-in of
## tools/bench_level.gd's stress-still case, and the criterion
## tests/e2e/test_fixtures_e2e.gd checks stress-still's pile against.
##   the pile:  the slimes asleep for the night (SlimeBodies.BEDTIME_ASLEEP)
##              when the fixture is loaded;
##   it rests:  every one of them RESTING (SlimeBodies.calm_of): not ACTIVE,
##              and not PARKED either (on screen, the pile rests, it isn't
##              parked away).
## The ticks are stepped by the caller's own step (the bench's, or the game's
## through test mode), so the tick counted is the one the caller runs.
# @spec-link [[req_platform_and_performance_targets]]

## ticks_to_rest()'s answer when the pile didn't rest within its bound.
const NEVER := -1


## The pile of `sim`: its slimes asleep for the night, by slime ID.
static func pile_of(sim: Simulation) -> Array[int]:
	var pile: Array[int] = []
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.BEDTIME_ASLEEP:
			pile.append(slime_id)
	return pile


## Whether every slime of `pile` rests in `sim` (see the class doc).
static func rests(sim: Simulation, pile: Array[int]) -> bool:
	return pile.all(func(slime_id: int) -> bool: return sim.slimes.calm_of(slime_id) == SlimeBodies.RESTING)


## Calls `step` (one tick of `sim`) until `pile` rests, at most `within`
## times. Returns how many ticks it took, or NEVER when the pile still
## doesn't rest after `within`. An empty pile is a caller bug (there would be
## nothing to wait for): said with push_error, and NEVER, without a tick.
static func ticks_to_rest(sim: Simulation, pile: Array[int], within: int, step: Callable) -> int:
	if pile.is_empty():
		push_error("pile_rest: no pile (no slime asleep for the night) to wait for")
		return NEVER
	for i in within:
		step.call()
		if rests(sim, pile):
			return i + 1
	return NEVER

class_name DebugKill
extends RefCounted
## The debug overlay's kill tool (DebugOverlay), as pure logic: which slime a
## tap lands on, and sending it to the loop start the way a lost slime goes:
## Offscreen.lose() (moved to the loop start by LoopStart.move, back on the
## train, logged in `offscreen.lost`). Immediate, outside the loop-start
## queue, and it counts as a move for the queue's next turn (D150). Debug
## builds only.

## How far outside a slime's drawn body a tap still picks it, screen pixels
## (the same as a sleeper's, TapDispatcher.SLEEPER_HIT_MARGIN).
const TAP_MARGIN := 24.0


## The slime under screen point `at` in `sim`'s view: the one whose centre is
## nearest the tap, among those whose drawn body grown by `margin` screen
## pixels holds it (the lower id on a tie). -1 when none.
static func slime_at(sim: Simulation, at: Vector2, margin := TAP_MARGIN) -> int:
	var world := sim.view.screen_to_world(at)
	var bodies := sim.slimes
	var best := -1
	var best_distance := INF
	for slime_id in bodies.ids():
		var distance := bodies.centre_of(slime_id).distance_to(world)
		var reach := bodies.radius_of(slime_id) + SlimeBodies.EDGE + margin / sim.view.zoom
		if distance <= reach and distance < best_distance:
			best = slime_id
			best_distance = distance
	return best


## Sends slime `slime_id` to the start of the loop, as a lost slime. Returns
## false when there is no such slime or no train.
static func send_to_start(sim: Simulation, slime_id: int) -> bool:
	if sim.train == null or not sim.slimes.has(slime_id):
		return false
	sim.offscreen.lose(sim, slime_id)
	return true

class_name DebugKill
extends RefCounted
## The debug overlay's kill tool (DebugOverlay), as pure logic: which slime a
## tap lands on, and sending it to the start of the loop the way a lost slime
## goes (chunk 15, Offscreen: moved to distance 0 lifted by its size, back on
## the train, logged in `offscreen.lost`). Debug builds only.
##
## The move is Offscreen's own, reused rather than copied: its public
## `lose(sim, id)` when there is one, else its internal `_lose(sim, id)`
## (chunk 15 keeps it private for now). Called by name so a rename shows as
## "unavailable" in the overlay instead of breaking the debug build.

## How far outside a slime's drawn body a tap still picks it, screen pixels
## (the tap zones' OBJECT_HIT_MARGIN).
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


## Whether the move to the start of the loop is there to call.
static func available(sim: Simulation) -> bool:
	return sim.offscreen.has_method("lose") or sim.offscreen.has_method("_lose")


## Sends slime `slime_id` to the start of the loop, as a lost slime. Returns
## false when there is no such slime, no train, or no move to call.
static func send_to_start(sim: Simulation, slime_id: int) -> bool:
	if sim.train == null or not sim.slimes.has(slime_id) or not available(sim):
		return false
	var method := "lose" if sim.offscreen.has_method("lose") else "_lose"
	sim.offscreen.call(method, sim, slime_id)
	return true

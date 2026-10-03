class_name LoopStart
extends RefCounted
## The move to the loop start, back on the train: the one move the three
## safety nets share (master spec §5.2, §5.3). A lost free slime (D10), a
## stuck slime (D100) and a stalled train slime (D121, out of bounds
## included) all take it, one at a time, through the loop-start queue
## (LoopStartQueue, D150); each net logs its own case. Pure logic over the
## Simulation's pieces, no scene nodes; its only randomness is the landing
## spot's, from a derived stream.
##
## The slime is put at rest on the loop near its start, its centre lifted by
## its size above the loop point (Offscreen.lift(), as spawn_train_slime()
## does), in state train with its hops no longer held, and the Train follows
## it from there with a fresh record (track()): its laps and its stall count
## start again. A parked slime is only translated (Offscreen moves it on); a
## simulated one gets a new body there, at rest and unsupported.
##
## A random free spot (D150 (3)). The spot is a distance along the loop drawn
## uniformly between 0 and STRETCH px from its start, up to DRAWS draws from
## the derived stream "loop_start:spot:<tick>" (Rng.derive: no draw from any
## other stream, so a run with no move keeps its hash). A spot is free when
## the slime's centre there lies inside a split zone (on a level that has
## any) and no other slime's ring, parked ones included, would overlap its
## own: two rings put on one centre never come apart (O91, the very case the
## stuck net is for). free_spot() gives the first free draw, or NO_SPOT when
## every draw is taken: the queue then moves nobody and tries again later.
# @spec-link [[rule_left_alone_and_lost]]
# @spec-link [[rule_stuck_slimes_moved_to_start]]
# @spec-link [[rule_stalled_train_slime_moved_to_start]]

## How far along the loop from its start a landing spot may be, px (D150).
const STRETCH := 240.0
## How many spots are drawn per try (D150).
const DRAWS := 8
## free_spot()'s answer when every draw is taken.
const NO_SPOT := -1.0


## The derived stream the landing spots of a try at `tick` are drawn from.
static func spot_stream(sim: Simulation, tick: int) -> Rng:
	return sim.rng.derive("loop_start:spot:%d" % tick)


## The distance along the loop of the first free spot for `slime_id` among
## the DRAWS draws of a try at `tick` (see the class doc), or NO_SPOT.
static func free_spot(sim: Simulation, slime_id: int, tick: int) -> float:
	assert(sim.train != null, "LoopStart.free_spot: no train")
	assert(sim.slimes.has(slime_id), "LoopStart.free_spot: no slime %d" % slime_id)
	var draws := spot_stream(sim, tick)
	for k in DRAWS:
		var distance := draws.randf_range(0.0, STRETCH)
		if is_free(sim, slime_id, distance):
			return distance
	return NO_SPOT


## The spot for a move that can't wait (outside the queue: the debug kill
## tool, a slime lost on load): the first free draw, or with every draw
## taken the first draw anyway (the stuck net sorts it out).
static func spot_now(sim: Simulation, slime_id: int, tick: int) -> float:
	var distance := free_spot(sim, slime_id, tick)
	if distance == NO_SPOT:
		distance = spot_stream(sim, tick).randf_range(0.0, STRETCH)
	return distance


## Whether `slime_id` would land free `distance` px along the loop (see the
## class doc).
static func is_free(sim: Simulation, slime_id: int, distance: float) -> bool:
	var bodies := sim.slimes
	var size := bodies.size_of(slime_id)
	var at := landing_point(sim.train, size, distance)
	if not sim.split_zones.zones.is_empty() and not sim.split_zones.covers(at):
		return false
	var reach := SlimeBodies.ring_radius_for(size) + SlimeBodies.EDGE
	for other in bodies.ids():
		if other == slime_id:
			continue
		var room := reach + bodies.radius_of(other) + SlimeBodies.EDGE
		if bodies.centre_of(other).distance_squared_to(at) < room * room:
			return false
	return true


## Where a slime of `size` put `distance` px along the loop has its centre.
static func landing_point(train: Train, size: int, distance: float) -> Vector2:
	return train.position_at(distance) + Vector2(0.0, -Offscreen.lift(size))


## Moves slime `slime_id` to `distance` px along the loop of `train`, back
## on the train (see the class doc).
static func move(bodies: SlimeBodies, train: Train, slime_id: int, distance: float) -> void:
	assert(bodies.has(slime_id), "LoopStart.move: no slime %d" % slime_id)
	var at := landing_point(train, bodies.size_of(slime_id), distance)
	var shift: Vector2 = at - bodies.centre_of(slime_id)
	if bodies.is_parked(slime_id):
		bodies.translate(slime_id, shift)
	else:
		var body := bodies.body_of(slime_id)
		var points: PackedVector2Array = body["points"]
		for k in points.size():
			points[k] += shift
		body["points"] = points
		body["previous"] = points.duplicate()
		body["centre"] = body["centre"] + shift
		body["supported"] = false
		bodies.set_body(slime_id, body)
	bodies.set_state(slime_id, SlimeBodies.TRAIN)
	bodies.set_hop_held(slime_id, false)
	train.track(slime_id, distance)

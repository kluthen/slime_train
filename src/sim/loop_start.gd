class_name LoopStart
extends RefCounted
## The move to the start of the loop, back on the train: the one move the
## three safety nets share (master spec §5.2, §5.3). A lost free slime (D10,
## Offscreen.lose), a stuck slime (D100, StuckSlimes) and a stalled train
## slime (D121, Train.follow) all take it; each logs its own case. Pure
## logic over SlimeBodies and the Train, no scene nodes, no randomness.
##
## The slime is put at rest on the loop near its start, its centre lifted by
## its size above the loop point (Offscreen.lift(), as spawn_train_slime()
## does), in state train with its hops no longer held, and the Train follows
## it from there with a fresh record (track()): its laps and its stall count
## start again. A parked slime is only translated (Offscreen moves it on); a
## simulated one gets a new body there, at rest and unsupported.
##
## A free spot. Two rings put on one centre never come apart (O91: the very
## case the stuck net is for), so the slime doesn't land on a slime already
## there: it goes to the first of SPOTS spots, one width of it apart along the
## loop from the start (distance 0, then its width, twice its width, ...),
## where no other slime's ring would overlap its own; with every spot taken,
## to the start itself.
# @spec-link [[rule_left_alone_and_lost]]
# @spec-link [[rule_stuck_slimes_moved_to_start]]
# @spec-link [[rule_stalled_train_slime_moved_to_start]]

## How many spots along the loop from its start are tried (see the class doc).
const SPOTS := 8


## Moves slime `slime_id` to the start of the loop of `train`, back on the
## train (see the class doc). Returns the distance along the loop it is put at.
# @spec-link [[req_offscreen_simulation]]
static func move(bodies: SlimeBodies, train: Train, slime_id: int) -> float:
	assert(bodies.has(slime_id), "LoopStart.move: no slime %d" % slime_id)
	var size := bodies.size_of(slime_id)
	var distance := _free_spot(bodies, train, slime_id)
	var at := train.position_at(distance) + Vector2(0.0, -Offscreen.lift(size))
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
		# A resting holder (D145) keeps its calm through set_body and is no
		# state change: woken here, or it would hang at the start as a wall
		# once track() below ends its hold.
		bodies.wake(slime_id)
	bodies.set_state(slime_id, SlimeBodies.TRAIN)
	bodies.set_hop_held(slime_id, false)
	train.track(slime_id, distance)
	return distance


## The distance along the loop of the first free spot for `slime_id` (see the
## class doc), or 0 when every spot is taken.
static func _free_spot(bodies: SlimeBodies, train: Train, slime_id: int) -> float:
	var size := bodies.size_of(slime_id)
	var reach := SlimeBodies.ring_radius_for(size) + SlimeBodies.EDGE
	var lift := Vector2(0.0, -Offscreen.lift(size))
	for spot in SPOTS:
		var distance := spot * 2.0 * reach
		var at := train.position_at(distance) + lift
		var free := true
		for other in bodies.ids():
			if other == slime_id:
				continue
			var room := reach + bodies.radius_of(other) + SlimeBodies.EDGE
			if bodies.centre_of(other).distance_squared_to(at) < room * room:
				free = false
				break
		if free:
			return distance
	return 0.0

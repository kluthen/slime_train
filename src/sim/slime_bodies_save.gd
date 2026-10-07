class_name SlimeBodiesSave
extends RefCounted
## The bodies' save: the parts of SlimeBodies that write a slime's body out
## and put it back exactly (a save, a basket's release, the loop start, the
## midair landing), and the whole state as plain data (dump(), the state
## hash), as static functions over a SlimeBodies' packed arrays. SlimeBodies
## owns every array and keeps its interface: its create_with_id, body_of,
## set_body and dump call these. The save format itself (which keys a save
## file holds, how they are checked) is SaveData's.
##
## The same operations in the same order as when they were SlimeBodies' own:
## a body put back is bit for bit the one written out, and the dump (so the
## state hash) is unchanged.
##
## As in SlimeSolverGD and SlimeDetail: each function reads the arrays it
## needs into locals, and a packed array read into a local shares the
## member's buffer, so the writes reach the bodies. set_body reads the point
## arrays after its ring rebuild (SlimeBodies._resample replaces their
## buffers). `b`, the bodies, is untyped: the native schema test compiles a
## renamed copy of slime_bodies.gd (tests/unit/test_native_solver.gd). So
## every local is typed by hand.


## create() with a given id, for loading a save: `slime_id` must be at least
## the bodies' next_id (slimes are created in ascending id order). Returns
## the id, or -1 (next_id then unchanged).
static func create_with_id(b, slime_id: int, slime_species: int, slime_size: int, at: Vector2,
		slime_state: int) -> int:
	var kept: int = b.next_id
	if slime_id < kept:
		push_error("SlimeBodies: id %d is taken or out of order (next is %d)" % [slime_id, kept])
		return -1
	b.next_id = slime_id
	var made: int = b.create(slime_species, slime_size, at, slime_state)
	if made < 0:
		b.next_id = kept
	return made


## Everything a save needs to put the slime's body back exactly: the points
## and their previous positions (so the velocities), the solver's centre, the
## hop timer, the heading, held and supported, its stream's state, its calm,
## rest count, rest anchor and pile, and its detail level. Empty for a
## missing slime.
static func body_of(b, slime_id: int) -> Dictionary:
	var s: int = b.index_of(slime_id)
	if s < 0:
		return {}
	var pos: PackedVector2Array = b.pos
	var prev: PackedVector2Array = b.prev
	var first: PackedInt32Array = b.first
	var npts: PackedInt32Array = b.npts
	var centre: PackedVector2Array = b.centre
	var hop_timer: PackedFloat64Array = b.hop_timer
	var heading: PackedFloat32Array = b.heading
	var held: PackedInt32Array = b.held
	var supported: PackedInt32Array = b.supported
	var stream: Rng = b._streams[s]
	var calm: PackedByteArray = b.calm
	var still_ticks: PackedInt32Array = b.still_ticks
	var rest_anchor: PackedVector2Array = b.rest_anchor
	var pile: PackedInt32Array = b.pile
	var detail: PackedByteArray = b.detail
	var f := first[s]
	var n := npts[s]
	return {"points": pos.slice(f, f + n), "previous": prev.slice(f, f + n), "centre": centre[s],
			"hop_timer": hop_timer[s], "heading": heading[s], "held": held[s] != 0,
			"supported": supported[s] != 0, "rng_state": stream.state,
			"calm": calm[s], "still": still_ticks[s], "anchor": rest_anchor[s], "pile": pile[s],
			"detail": detail[s]}


## Puts back a body from body_of(). False (and nothing changes) when the
## slime is missing or the point counts don't match its size (at the body's
## detail level, "detail", 0 when absent). The body's "calm" and "still" are
## put back too; a body without them leaves the slime ACTIVE. A body that
## moves the slime by more than a pixel wakes the resting slimes touching
## where it was (a slime taken out from under a pile, a basket's release),
## not the rest of their pile (D156).
# @spec-link [[req_offscreen_simulation]]
static func set_body(b, slime_id: int, body: Dictionary) -> bool:
	var s: int = b.index_of(slime_id)
	if s < 0:
		return false
	var points: PackedVector2Array = body["points"]
	var previous: PackedVector2Array = body["previous"]
	var level: int = body.get("detail", 0)
	if level < 0 or level > SlimeBodies.MAX_DETAIL:
		push_error("SlimeBodies: invalid detail level %d" % level)
		return false
	var size: PackedInt32Array = b.size
	var n := SlimeBodies.detail_points_for(size[s], level)
	if points.size() != n or previous.size() != n:
		return false
	var detail: PackedByteArray = b.detail
	if detail[s] != level:
		detail[s] = level
		b._resample(s, n)
	var centre: PackedVector2Array = b.centre
	var was: Vector2 = centre[s]
	# Read after the resample: it replaces the point arrays' buffers.
	var pos: PackedVector2Array = b.pos
	var prev: PackedVector2Array = b.prev
	var first: PackedInt32Array = b.first
	var f := first[s]
	for k in n:
		pos[f + k] = points[k]
		prev[f + k] = previous[k]
	var centre_ok: PackedByteArray = b._centre_ok
	centre_ok[s] = 0
	centre[s] = body["centre"]
	var hop_timer: PackedFloat64Array = b.hop_timer
	hop_timer[s] = body["hop_timer"]
	var heading: PackedFloat32Array = b.heading
	heading[s] = body["heading"]
	var held: PackedInt32Array = b.held
	held[s] = 1 if body["held"] else 0
	var supported: PackedInt32Array = b.supported
	supported[s] = 1 if body["supported"] else 0
	var stream: Rng = b._streams[s]
	stream.state = body["rng_state"]
	var calm: PackedByteArray = b.calm
	if body.has("calm"):
		calm[s] = int(body["calm"])
		var still_ticks: PackedInt32Array = b.still_ticks
		still_ticks[s] = int(body.get("still", 0))
		var rest_anchor: PackedVector2Array = b.rest_anchor
		rest_anchor[s] = body.get("anchor", centre[s])
		var pile: PackedInt32Array = b.pile
		pile[s] = int(body.get("pile", 0))
	else:
		b._wake_at(s)
	if centre[s].distance_squared_to(was) > 1.0 and calm[s] != SlimeBodies.PARKED:
		var bound_r: PackedFloat32Array = b.bound_r
		b._wake_around(was, bound_r[s], s)
	return true


## The whole state of the slimes, as plain data in id order, for
## Simulation.dump(). Centres are rounded to 0.01 px and timers to 0.1 ms, so
## the dump is stable to print; the rng states are strings (64-bit).
static func dump(b) -> Array:
	var slime_count: int = b.slime_count
	var id: PackedInt32Array = b.id
	var species: PackedInt32Array = b.species
	var size: PackedInt32Array = b.size
	var state: PackedInt32Array = b.state
	var hop_timer: PackedFloat64Array = b.hop_timer
	var heading: PackedFloat32Array = b.heading
	var held: PackedInt32Array = b.held
	var supported: PackedInt32Array = b.supported
	var streams: Array[Rng] = b._streams
	var calm: PackedByteArray = b.calm
	var still_ticks: PackedInt32Array = b.still_ticks
	var pile: PackedInt32Array = b.pile
	var detail: PackedByteArray = b.detail
	var out := []
	for s in slime_count:
		var stream: Rng = streams[s]
		var at: Vector2 = b._centre_at(s)
		var velocity: Vector2 = b._velocity_at(s)
		out.append({
			"id": id[s],
			"species": species[s],
			"size": size[s],
			"state": SlimeBodies.STATE_NAMES[state[s]],
			"centre": at.snapped(Vector2(0.01, 0.01)),
			"velocity": velocity.snapped(Vector2(0.01, 0.01)),
			"hop_timer": snappedf(hop_timer[s], 0.0001),
			"heading": heading[s],
			"held": held[s] != 0,
			"supported": supported[s] != 0,
			"rng_state": str(stream.state),
			"calm": SlimeBodies.CALM_NAMES[calm[s]],
			"still": still_ticks[s],
			"pile": pile[s],
			"detail": detail[s],
		})
	return out

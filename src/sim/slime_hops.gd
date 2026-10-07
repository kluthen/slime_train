class_name SlimeHops
extends RefCounted
## The hops: the parts of SlimeBodies that make a slime hop (the automatic
## hops on each slime's own timer, a hop's take-off, which slimes may hop,
## their hop intervals) and that hold a train slime standing on a climb, as
## static functions over a SlimeBodies' packed arrays. SlimeBodies owns every
## array and keeps its interface: its tick (_auto_hops), hop, can_hop,
## hold_on_slope and hop_interval_range call these, and its HOP_* constants
## are the hops' tuning.
##
## The same float operations, and the same draws from each slime's stream,
## in the same order as when they were SlimeBodies' own.
##
## As in SlimeSolverGD and SlimeDetail: each function reads the arrays it
## needs into locals, and a packed array read into a local shares the
## member's buffer, so the writes reach the bodies. `b`, the bodies, is
## untyped: the native schema test compiles a renamed copy of
## slime_bodies.gd (tests/unit/test_native_solver.gd). So every local is
## typed by hand.


## Whether a slime in `slime_state`, held (`is_held` 1) or not, of calm
## `slime_calm`, hops on its own: train and free slimes not held still, and
## simulated (ACTIVE).
static func can_hop(slime_state: int, is_held: int, slime_calm: int) -> bool:
	return ((slime_state == SlimeBodies.STATE_TRAIN or slime_state == SlimeBodies.STATE_FREE)
			and is_held == 0 and slime_calm == SlimeBodies.ACTIVE)


## (shortest, longest) seconds between two automatic hops of a slime of
## `slime_size`: bigger slimes hop a little less often.
# @spec-link [[req_hopping_behavior]]
static func interval_range(slime_size: int) -> Vector2:
	var scale := 1.0 + SlimeBodies.HOP_INTERVAL_PER_SIZE * (slime_size - 1)
	return Vector2(SlimeBodies.HOP_INTERVAL_MIN, SlimeBodies.HOP_INTERVAL_MAX) * scale


## Slime index `s` takes off at `velocity` (px/s): every point gets it, the
## slime leaves the ground (supported 0) and its id goes in `hopped`.
static func hop_at(b, s: int, velocity: Vector2) -> void:
	var h: float = b._h
	var step := velocity * h
	var prev: PackedVector2Array = b.prev
	var first: PackedInt32Array = b.first
	var npts: PackedInt32Array = b.npts
	for i in range(first[s], first[s] + npts[s]):
		prev[i] -= step
	var supported: PackedInt32Array = b.supported
	supported[s] = 0
	var hopped: PackedInt32Array = b.hopped
	var id: PackedInt32Array = b.id
	hopped.append(id[s])


## Automatic hops, `dt` seconds of them: each able slime counts its timer
## down (at the bodies' hop_rate); at zero, if it stands on something, it
## hops (heading-slanted, strength jittered by its stream, or at its hop_aim
## when steered) and draws its next interval; if not, it hops on landing.
## Every hop_aim is then cleared. A train slime's hop goes in train_hopped.
# @spec-link [[req_hopping_behavior]]
static func auto_hops(b, dt: float) -> void:
	var slime_count: int = b.slime_count
	var state: PackedInt32Array = b.state
	var held: PackedInt32Array = b.held
	var calm: PackedByteArray = b.calm
	var hop_timer: PackedFloat64Array = b.hop_timer
	var supported: PackedInt32Array = b.supported
	var heading: PackedFloat32Array = b.heading
	var hop_aim: PackedVector2Array = b.hop_aim
	var size: PackedInt32Array = b.size
	var id: PackedInt32Array = b.id
	var streams: Array[Rng] = b._streams
	var train_hopped: PackedInt32Array = b.train_hopped
	var rate: float = b.hop_rate
	for s in slime_count:
		if not can_hop(state[s], held[s], calm[s]):
			continue
		var t := hop_timer[s] - dt * rate
		if t > 0.0:
			hop_timer[s] = t
			continue
		hop_timer[s] = 0.0
		if supported[s] == 0:
			continue
		var stream: Rng = streams[s]
		var strength := 1.0 + stream.randf_range(-SlimeBodies.HOP_STRENGTH_JITTER, SlimeBodies.HOP_STRENGTH_JITTER)
		var direction := Vector2(heading[s] * SlimeBodies.HOP_FORWARD, -1.0)
		if hop_aim[s] != Vector2.ZERO:
			hop_at(b, s, hop_aim[s])
		else:
			hop_at(b, s, SlimeBodies.hop_velocity(size[s], direction, strength))
		if state[s] == SlimeBodies.STATE_TRAIN:
			train_hopped.append(id[s])
		var interval := interval_range(size[s])
		hop_timer[s] = stream.randf_range(interval.x, interval.y)
	hop_aim.fill(Vector2.ZERO)


## Holds slime index `s` on a slope running along `tangent` (unit, the way
## up): its mean motion down the slope is taken away and `lift` px/s up it
## added (the Train gives a share of the tick's pull down the slope, so the
## tick ends nearly where it started). Its spin, squish and motion up the
## slope are left alone. How the Train holds a train slime standing on a
## climb.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[rule_train_climbs_without_sliding_back]]
static func hold_on_slope(b, s: int, tangent: Vector2, lift: float) -> void:
	var h: float = b._h
	var velocity: Vector2 = b._velocity_at(s)
	var along := velocity.dot(tangent)
	var step := tangent * (maxf(along, 0.0) + lift - along) * h
	var prev: PackedVector2Array = b.prev
	var first: PackedInt32Array = b.first
	var npts: PackedInt32Array = b.npts
	for i in range(first[s], first[s] + npts[s]):
		prev[i] -= step

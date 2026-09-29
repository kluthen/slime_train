class_name SlimeBodies
extends RefCounted
## The slimes' soft bodies: every slime is a ring of points, and all the rings
## live in packed arrays (struct of arrays, D94). Advanced by tick(dt) on the
## simulation's fixed step, with a Verlet solver split into substeps.
##
## Layout. Per point: `pos` and `prev` (Verlet: the velocity is pos - prev),
## and `rest_off`, the point's offset from the centre on the rest circle.
## Per slime (index 0 .. slime_count - 1): `first` and `npts` give the slime's
## slice of the point arrays, and the other per-slime arrays hold one entry
## each. Slimes are stored in ascending id order, their point slices back to
## back in the same order. Removing a slime compacts every array (no holes,
## order kept), so the index of a slime can change while its id never does.
## Ids are never reused. Use index_of(id) to go from id to index.
##
## One tick: automatic hops (each slime's own seeded stream decides when),
## then `substeps` times: integrate (gravity, air drag, internal damping),
## build the slime-pair grid (first substep only), slime-slime contacts, ring
## constraints (edge springs, area, shape matching), terrain contacts.
##
## Sleepers (STATE_SLEEPER) don't simulate: no hop, no integration, no ring
## or terrain constraint, so their points never move. Other slimes still
## touch them (touching_pairs, for waking) and are pushed off them by the
## whole overlap, as off a wall; two sleepers are never paired.
##
## Calm (chunk 15, master spec §5.3, D96). Each slime also has a `calm`:
##   ACTIVE   simulated as above.
##   RESTING  a settled slime of a pile (in a basket, or asleep at bedtime:
##            the states that never hop, see _can_rest) that stopped
##            simulating, contacts included: like a sleeper it is a wall,
##            and two walls are never paired. Piles rest whole: a group of
##            touching pile slimes rests together once every one of them
##            has been supported and still (its centre within REST_DRIFT of
##            where it was) for REST_TICKS, velocities dropped; it keeps
##            its `pile` (the group's lowest id) and wakes whole. Something
##            disturbing it makes it ACTIVE again: a touching slime moving
##            faster than WAKE_SPEED (a hop, a landing, a neighbour
##            shifting), a state change (bedtime, sunrise, a basket catching
##            or releasing), a new velocity or body, a slime removed, fused
##            or split next to it, or whoever knows of a disturbance calling
##            wake / wake_around / wake_resting_in (a call, a door: Offscreen,
##            FrontierSets). rest_enabled off: no slime rests.
##   PARKED   off screen (Offscreen): not simulated nor touched at all, not
##            even as a wall (it is left out of the pair grid); Offscreen
##            moves it (translate) and un-parks it near the view. Nothing
##            but park / unpark changes it.
## Low detail (zoomed out): set_low_detail() gives a slime's ring the
## LOW_POINTS_BY_SIZE count, read off its current shape (see _resample); the
## rest area follows the point count. Offscreen decides from the zoom.
##
## The interface (create, remove, tick, merge, split, hop, the accessors and
## dump) is kept small and plain so the tick can move to a GDExtension later
## without the callers changing.
# @spec-link [[req_waking_sleepers]]

const STATE_SLEEPER := 0
const STATE_TRAIN := 1
const STATE_FREE := 2
const STATE_BEDTIME_ASLEEP := 3
## Resting in a basket (FrontierSets, chunk 14): it doesn't hop, nor ride
## the train, nor follow a call; it falls and settles like any body.
# @spec-link [[req_switch_basket_gate_set]]
const STATE_IN_BASKET := 4
## Short names for the states.
const SLEEPER := STATE_SLEEPER
const TRAIN := STATE_TRAIN
const FREE := STATE_FREE
const BEDTIME_ASLEEP := STATE_BEDTIME_ASLEEP
const IN_BASKET := STATE_IN_BASKET
## The state names, as dump() writes them.
const STATE_NAMES: PackedStringArray = ["sleeper", "train", "free", "bedtime_asleep", "in_basket"]

const MAX_SIZE := 3
## Ring points per size (index 0 unused).
const POINTS_BY_SIZE: Array[int] = [0, 12, 15, 18]
## The ring radius of a size-1 slime. The drawn body adds EDGE all round, so a
## base slime looks 24 px in radius (PlaceholderArt.SLIME_RADIUS).
const RING_RADIUS_SIZE_1 := 21.0
const EDGE := 3.0

## A train slime's time between hops, in seconds (specs/tuning.md: ~1.5-3 s);
## bigger slimes hop a little less often: x (1 + HOP_INTERVAL_PER_SIZE * (size - 1)).
const HOP_INTERVAL_MIN := 1.5
const HOP_INTERVAL_MAX := 3.0
const HOP_INTERVAL_PER_SIZE := 0.15
## Take-off speed of a full-strength hop (px/s), and how much faster bigger
## slimes take off: further and higher.
const HOP_SPEED := 620.0
const HOP_SPEED_PER_SIZE := 0.12
## Sideways part of an automatic hop's direction, per unit of heading.
const HOP_FORWARD := 0.35
## Random spread of an automatic hop's strength: 1 +- this.
const HOP_STRENGTH_JITTER := 0.1
## A terrain normal steeper than this (n.y below minus it) carries a slime.
const SUPPORT_NORMAL_Y := 0.3
## Extra distance at which two rings count as touching.
const TOUCH_SKIN := 2.0

## A slime's calm (see the class doc): simulated, resting (a wall), parked.
# @spec-link [[req_offscreen_simulation]]
const ACTIVE := 0
const RESTING := 1
const PARKED := 2
## The calm names, as dump() writes them.
const CALM_NAMES: PackedStringArray = ["active", "resting", "parked"]
## Ring points per size when zoomed out (index 0 unused).
const LOW_POINTS_BY_SIZE: Array[int] = [0, 8, 10, 12]
## A supported slime whose centre stays within REST_DRIFT px of where it was
## REST_TICKS ticks ago is still (a distance, not a speed: a settled pile
## jitters by a fraction of a pixel, now and then at 10-20 px/s for a tick).
const REST_DRIFT := 1.0
const REST_TICKS := 30
## A touching slime moving faster than this (px/s) wakes a resting one.
const WAKE_SPEED := 30.0

var gravity := Vector2(0.0, 1400.0)
## The way free slimes fall (a unit vector), set by the Simulation every tick
## from the tilt (Tilt.down()). Only free slimes feel tilt: every other state
## falls along `gravity` (gravity_for).
# @spec-link [[req_tilt_input]]
# @spec-link [[req_slime_states]]
var free_down := Vector2.DOWN
var substeps := 2
var iterations := 1
var edge_stiffness := 0.8
var area_stiffness := 0.6
var shape_stiffness := 0.3
## Share of each point's velocity pulled toward its slime's mean velocity per
## substep: stops internal jiggle without slowing the slime down.
var internal_damping := 0.2
## Velocity lost to the air, per second.
var air_drag := 0.05
## Share of the tangential velocity a point touching the terrain loses per substep.
var terrain_friction := 0.4
## Share of the sliding velocity between a point and the ring it touches lost
## per substep (slime on slime friction, so slimes can pile up).
var slime_friction := 0.3
## How far ring points stay off the terrain: EDGE, so the drawn body (the
## ring plus EDGE) rests on the ground instead of overlapping it.
var terrain_skin := EDGE
## Safety clamp on a point's speed, px/s.
var max_speed := 1200.0
## Whether tick() hops slimes on their own timers. Off, only hop() hops.
var auto_hops := true
## How fast the hop timers run (1: normal). The Simulation sets it every tick
## from the session (Session.hop_rate(): slower hops in the wind-down), so it
## isn't in dump().
# @spec-link [[req_session_lifecycle]]
var hop_rate := 1.0
## The static terrain (built once per level and shared), or null for none.
var terrain: TerrainSegments = null
## Extra solid pieces solved like the terrain, after it: the frontier sets'
## doors that are shut (a switch's trapdoor, a closed gate), set every tick
## by FrontierSets from the object states, so not in dump().
# @spec-link [[req_switch_basket_gate_set]]
var doors: Array[TerrainSegments] = []
## Whether settled pile slimes rest (the resting-pile rule, see the class doc).
var rest_enabled := true

# Per point.
var pos := PackedVector2Array()
var prev := PackedVector2Array()
var rest_off := PackedVector2Array()

# Per slime.
var slime_count := 0
var id := PackedInt32Array()
var first := PackedInt32Array()
var npts := PackedInt32Array()
var size := PackedInt32Array()
var species := PackedInt32Array()
## Each slime's state: STATE_SLEEPER, STATE_TRAIN, STATE_FREE,
## STATE_BEDTIME_ASLEEP or STATE_IN_BASKET.
# @spec-link [[req_slime_states]]
var state := PackedInt32Array()
## 1 while the slime is held still (covered by others, resting in a full
## basket: the chunks that know say so); it doesn't hop.
var held := PackedInt32Array()
## 1 when the slime touched ground (terrain facing up, or another slime from
## above) during the last tick. Only supported slimes hop.
var supported := PackedInt32Array()
var ring_radius := PackedFloat32Array()
var rest_area := PackedFloat32Array()
var rest_edge := PackedFloat32Array()
## Broadphase radius: the ring radius plus room to squash.
var bound_r := PackedFloat32Array()
## Seconds until the slime's next automatic hop.
var hop_timer := PackedFloat64Array()
## Sideways direction of the automatic hops: -1 left, 0 in place, 1 right.
var heading := PackedFloat32Array()
## The take-off velocity (px/s) of the slime's automatic hop if it hops this
## tick, set by whoever steers it (the Train); zero for a plain hop along its
## heading. Valid for one tick only: cleared by every tick, so not state.
var hop_aim := PackedVector2Array()
## The mean of the slime's points, refreshed each substep.
var centre := PackedVector2Array()
## The angle of the slime's point 0 around its centre, refreshed each substep.
var angle0 := PackedFloat32Array()
## The mean displacement of the slime's points over the last substep.
var _drift := PackedVector2Array()
## Each slime's calm: ACTIVE, RESTING or PARKED (see the class doc).
var calm := PackedByteArray()
## 1 while the slime's ring has the low-detail point count.
var low_detail := PackedByteArray()
## Ticks in a row the slime has been supported and still (the rest count,
## capped at REST_TICKS).
var still_ticks := PackedInt32Array()
## Where the slime's centre was when its rest count started.
var rest_anchor := PackedVector2Array()
## The pile a resting slime rests with: the lowest slime id of the group of
## touching pile slimes that came to rest together (0 when not resting).
var pile := PackedInt32Array()

## The next id create() hands out.
var next_id := 1
## Bumped whenever slimes or their point ranges change (create, remove,
## merge, split), so a renderer knows when to rebuild its index buffers.
var topology_version := 0
## The ids of the slimes that hopped during the last tick.
var hopped := PackedInt32Array()

var _master: Rng
var _streams: Array[Rng] = []
## Length of one substep in seconds (the last tick's), to turn pos - prev
## into a velocity.
var _h := (1.0 / 60.0) / 2.0

# Slime-pair broadphase, rebuilt once per tick.
var _cell_size := 104.0
var _grid_w := 1
var _grid_h := 1
var _grid_origin := Vector2.ZERO
var _cell_start := PackedInt32Array()
var _cell_items := PackedInt32Array()
var _slime_cell := PackedInt32Array()
var _pairs := PackedInt32Array()
var _pair_touch := PackedByteArray()
var _touching: Array = []


## `master`: the simulation's master Rng. Each slime draws from its own
## stream, master.derive("slime:<id>"), so its hops don't depend on others.
func _init(master: Rng) -> void:
	_master = master


# --- Sizes ------------------------------------------------------------------

static func points_for(slime_size: int) -> int:
	return POINTS_BY_SIZE[slime_size]


static func ring_radius_for(slime_size: int) -> float:
	return RING_RADIUS_SIZE_1 * sqrt(float(slime_size))


## The area of the rest ring (a regular polygon), proportional to the size
## within about 3 %.
static func rest_area_for(slime_size: int) -> float:
	return _polygon_area(points_for(slime_size), ring_radius_for(slime_size))


## The ring point count of a zoomed-out slime of `slime_size`.
static func low_points_for(slime_size: int) -> int:
	return LOW_POINTS_BY_SIZE[slime_size]


## The area of a regular polygon of `n` points on a circle of radius `r`.
static func _polygon_area(n: int, r: float) -> float:
	return 0.5 * n * r * r * sin(TAU / n)


## (shortest, longest) seconds between two automatic hops.
# @spec-link [[req_hopping_behavior]]
static func hop_interval_range(slime_size: int) -> Vector2:
	var scale := 1.0 + HOP_INTERVAL_PER_SIZE * (slime_size - 1)
	return Vector2(HOP_INTERVAL_MIN, HOP_INTERVAL_MAX) * scale


## The take-off velocity (px/s) of a hop along `direction` (any length).
static func hop_velocity(slime_size: int, direction: Vector2, strength: float) -> Vector2:
	return direction.normalized() * HOP_SPEED * (1.0 + HOP_SPEED_PER_SIZE * (slime_size - 1)) * strength


# --- Creating and removing --------------------------------------------------

## Adds a slime of `slime_species` (0-5) and `slime_size` (1-3) centred at
## `at`, at rest, and returns its id (-1 when an argument is invalid).
func create(slime_species: int, slime_size: int, at: Vector2, slime_state := STATE_TRAIN) -> int:
	if slime_species < 0 or slime_species >= Species.COUNT:
		push_error("SlimeBodies: invalid species %d" % slime_species)
		return -1
	if slime_size < 1 or slime_size > MAX_SIZE:
		push_error("SlimeBodies: invalid size %d" % slime_size)
		return -1
	if slime_state < 0 or slime_state >= STATE_NAMES.size():
		push_error("SlimeBodies: invalid state %d" % slime_state)
		return -1
	var new_id := next_id
	next_id += 1
	var stream := _master.derive("slime:%d" % new_id)
	var interval := hop_interval_range(slime_size)
	id.append(new_id)
	first.append(pos.size())
	npts.append(0)
	size.append(slime_size)
	species.append(slime_species)
	state.append(slime_state)
	held.append(0)
	supported.append(0)
	ring_radius.append(0.0)
	rest_area.append(0.0)
	rest_edge.append(0.0)
	bound_r.append(0.0)
	hop_timer.append(stream.randf_range(interval.x, interval.y))
	heading.append(0.0)
	hop_aim.append(Vector2.ZERO)
	centre.append(at)
	angle0.append(0.0)
	_drift.append(Vector2.ZERO)
	calm.append(ACTIVE)
	low_detail.append(0)
	still_ticks.append(0)
	rest_anchor.append(at)
	pile.append(0)
	_slime_cell.append(0)
	_streams.append(stream)
	slime_count += 1
	_reshape(slime_count - 1, slime_size, at, Vector2.ZERO)
	return new_id


## Removes a slime. False when there is no such slime.
func remove(slime_id: int) -> bool:
	var s := index_of(slime_id)
	if s < 0:
		return false
	if calm[s] != PARKED:
		_wake_around(centre[s], bound_r[s], s)
	_remove_at(s)
	return true


func has(slime_id: int) -> bool:
	return index_of(slime_id) >= 0


## The slime's index in the per-slime arrays, or -1.
func index_of(slime_id: int) -> int:
	var s := id.bsearch(slime_id)
	if s < slime_count and id[s] == slime_id:
		return s
	return -1


## The ids of every slime, ascending.
func ids() -> PackedInt32Array:
	return id.duplicate()


# --- Reading ----------------------------------------------------------------

func species_of(slime_id: int) -> int:
	var s := index_of(slime_id)
	return species[s] if s >= 0 else -1


func size_of(slime_id: int) -> int:
	var s := index_of(slime_id)
	return size[s] if s >= 0 else 0


func state_of(slime_id: int) -> int:
	var s := index_of(slime_id)
	return state[s] if s >= 0 else -1


func radius_of(slime_id: int) -> float:
	var s := index_of(slime_id)
	return ring_radius[s] if s >= 0 else 0.0


func rest_area_of(slime_id: int) -> float:
	var s := index_of(slime_id)
	return rest_area[s] if s >= 0 else 0.0


func hop_timer_of(slime_id: int) -> float:
	var s := index_of(slime_id)
	return hop_timer[s] if s >= 0 else 0.0


func points_of(slime_id: int) -> PackedVector2Array:
	var s := index_of(slime_id)
	if s < 0:
		return PackedVector2Array()
	return pos.slice(first[s], first[s] + npts[s])


## The mean of the slime's points.
func centre_of(slime_id: int) -> Vector2:
	var s := index_of(slime_id)
	return _centre_at(s) if s >= 0 else Vector2.ZERO


## The mean velocity of the slime's points, px/s.
func velocity_of(slime_id: int) -> Vector2:
	var s := index_of(slime_id)
	return _velocity_at(s) if s >= 0 else Vector2.ZERO


## The area inside the ring now.
func area_of(slime_id: int) -> float:
	var s := index_of(slime_id)
	if s < 0:
		return 0.0
	var f := first[s]
	var n := npts[s]
	var area := 0.0
	for k in n:
		area += pos[f + k].cross(pos[f + (k + 1) % n])
	return absf(area) * 0.5


## Whether the two slimes' rings touched during the last tick.
func touching(a: int, b: int) -> bool:
	var pair := Vector2i(mini(a, b), maxi(a, b))
	return _touching.has(pair)


## Every pair of slimes whose rings touched during the last tick, as
## Vector2i(lower id, higher id), in order.
func touching_pairs() -> Array:
	return _touching.duplicate()


# --- Changing ---------------------------------------------------------------

func set_state(slime_id: int, slime_state: int) -> void:
	var s := index_of(slime_id)
	if s < 0 or slime_state < 0 or slime_state >= STATE_NAMES.size():
		push_error("SlimeBodies: can't set state %d on slime %d" % [slime_state, slime_id])
		return
	if state[s] != slime_state:
		_wake_at(s)
	state[s] = slime_state


## Holds a slime still (true) or lets it hop again (false).
func set_hop_held(slime_id: int, is_held: bool) -> void:
	var s := index_of(slime_id)
	if s >= 0:
		held[s] = 1 if is_held else 0


## -1 hops left, 1 right, 0 in place (in between: a slanted hop).
func set_heading(slime_id: int, direction: float) -> void:
	var s := index_of(slime_id)
	if s >= 0:
		heading[s] = clampf(direction, -1.0, 1.0)


## Sets the seconds until the slime's next automatic hop (whoever steers it
## paces its hops: a called slime hops sooner and more often).
func set_hop_timer(slime_id: int, seconds: float) -> void:
	var s := index_of(slime_id)
	if s >= 0:
		hop_timer[s] = maxf(seconds, 0.0)


## Aims the slime's automatic hop, if it hops this tick: its take-off
## velocity (px/s) instead of a plain hop along its heading.
func set_hop_aim(slime_id: int, velocity: Vector2) -> void:
	var s := index_of(slime_id)
	if s >= 0:
		hop_aim[s] = velocity


## Gives every point of the slime the velocity `velocity` (px/s).
func set_velocity(slime_id: int, velocity: Vector2) -> void:
	var s := index_of(slime_id)
	if s < 0:
		return
	_wake_at(s)
	var step := velocity * _h
	for i in range(first[s], first[s] + npts[s]):
		prev[i] = pos[i] - step


## Takes `share` (0 to 1) of the slime's rigid motion away: its mean
## velocity and its spin about its centre, so it neither slides nor rolls,
## while its squish (the points' motion relative to that) is kept. How a slime
## grips the ground between hops (the Train does it for train slimes).
func brake(slime_id: int, share: float) -> void:
	var s := index_of(slime_id)
	if s < 0:
		return
	var f := first[s]
	var n := npts[s]
	var c := _centre_at(s)
	var v := _velocity_at(s)
	var turn := 0.0
	var inertia := 0.0
	for i in range(f, f + n):
		var r := pos[i] - c
		turn += r.cross((pos[i] - prev[i]) / _h - v)
		inertia += r.length_squared()
	var spin := turn / inertia if inertia > 0.0 else 0.0
	var k := clampf(share, 0.0, 1.0) * _h
	for i in range(f, f + n):
		var r := pos[i] - c
		prev[i] += (v + Vector2(-r.y, r.x) * spin) * k


## Whether the slime hops on its own: train and free slimes not held still.
func can_hop(slime_id: int) -> bool:
	var s := index_of(slime_id)
	return s >= 0 and _can_hop_at(s)


## Makes a supported slime hop now along `direction`, `strength` 1 for a
## normal hop. False (and nothing happens) for a missing slime, one that
## doesn't hop in its state, or one not on the ground.
func hop(slime_id: int, direction: Vector2, strength: float) -> bool:
	var s := index_of(slime_id)
	if s < 0 or not _can_hop_at(s) or supported[s] == 0:
		return false
	_hop_at(s, hop_velocity(size[s], direction, strength))
	return true


## Whether `a` and `b` may fuse: two different slimes of the same species
## whose sizes add up to MAX_SIZE at most.
func can_merge(a: int, b: int) -> bool:
	var sa := index_of(a)
	var sb := index_of(b)
	return (sa >= 0 and sb >= 0 and sa != sb and species[sa] == species[sb]
			and size[sa] + size[sb] <= MAX_SIZE)


## Fuses `a` and `b` into one slime and returns its id (the lower of the
## two), or -1 when they can't fuse (see can_merge): then nothing changes.
## The fused ring is a fresh rest circle of the summed size (so the area is
## kept within the rounding of the polygons), at the size-weighted centre,
## moving at the size-weighted velocity (momentum kept). It keeps the lower
## id's state, heading, hop timer and stream; the other slime is removed.
## Deciding when slimes fuse (3 s of contact) is the fusion chunk's job.
# @spec-link [[rule_max_size_three]]
# @spec-link [[rule_fusion_contact_time]]
func merge(a: int, b: int) -> int:
	if not can_merge(a, b):
		return -1
	var keep := index_of(mini(a, b))
	var gone := index_of(maxi(a, b))
	var wk := float(size[keep])
	var wg := float(size[gone])
	var total := size[keep] + size[gone]
	var at := (_centre_at(keep) * wk + _centre_at(gone) * wg) / (wk + wg)
	var velocity := (_velocity_at(keep) * wk + _velocity_at(gone) * wg) / (wk + wg)
	_remove_at(gone)
	_reshape(keep, total, at, velocity)
	_wake_around(at, bound_r[keep], keep)
	return id[keep]


## Splits a slime into base (size-1) slimes of its species and state, placed
## apart without overlapping around its centre, all keeping its velocity.
## Returns their ids, the original id first (it becomes the first part); the
## others are new ids. A base slime returns [its id] unchanged, a missing one
## []. Where slimes split (only in a split zone) is the loop chunk's job.
# @spec-link [[rule_split_zone_only_splitter]]
func split(slime_id: int) -> PackedInt32Array:
	var s := index_of(slime_id)
	if s < 0:
		return PackedInt32Array()
	var parts := PackedInt32Array([slime_id])
	var count := size[s]
	if count == 1:
		return parts
	var at := _centre_at(s)
	var velocity := _velocity_at(s)
	var offsets := _split_offsets(count)
	_reshape(s, 1, at + offsets[0], velocity)
	_wake_around(at, bound_r[s] * 2.0, s)
	var slime_species := species[s]
	var slime_state := state[s]
	var slime_heading := heading[s]
	var slime_held := held[s]
	for k in range(1, count):
		var part := create(slime_species, 1, at + offsets[k], slime_state)
		var p := index_of(part)
		heading[p] = slime_heading
		held[p] = slime_held
		_set_velocity_at(p, velocity)
		parts.append(part)
	return parts


# --- Saves ------------------------------------------------------------------

## create() with a given id, for loading a save: `slime_id` must be at least
## next_id (slimes are created in ascending id order). Returns the id, or -1.
func create_with_id(slime_id: int, slime_species: int, slime_size: int, at: Vector2,
		slime_state := STATE_TRAIN) -> int:
	if slime_id < next_id:
		push_error("SlimeBodies: id %d is taken or out of order (next is %d)" % [slime_id, next_id])
		return -1
	var kept := next_id
	next_id = slime_id
	var made := create(slime_species, slime_size, at, slime_state)
	if made < 0:
		next_id = kept
	return made


## Everything a save needs to put the slime's body back exactly: the points
## and their previous positions (so the velocities), the solver's centre, the
## hop timer, the heading, held and supported, and its stream's state.
## Empty for a missing slime.
func body_of(slime_id: int) -> Dictionary:
	var s := index_of(slime_id)
	if s < 0:
		return {}
	var f := first[s]
	var n := npts[s]
	return {"points": pos.slice(f, f + n), "previous": prev.slice(f, f + n), "centre": centre[s],
			"hop_timer": hop_timer[s], "heading": heading[s], "held": held[s] != 0,
			"supported": supported[s] != 0, "rng_state": _streams[s].state,
			"calm": calm[s], "still": still_ticks[s], "anchor": rest_anchor[s], "pile": pile[s],
			"low": low_detail[s] != 0}


## Puts back a body from body_of(). False (and nothing changes) when the
## slime is missing or the point counts don't match its size (at the body's
## detail, "low", full when absent). The body's "calm" and "still" are put
## back too; a body without them leaves the slime ACTIVE. A body that moves
## the slime by more than a pixel wakes the resting slimes around where it
## was (a slime taken out from under a pile).
# @spec-link [[req_offscreen_simulation]]
func set_body(slime_id: int, body: Dictionary) -> bool:
	var s := index_of(slime_id)
	if s < 0:
		return false
	var points: PackedVector2Array = body["points"]
	var previous: PackedVector2Array = body["previous"]
	var is_low: bool = body.get("low", false)
	var n := low_points_for(size[s]) if is_low else points_for(size[s])
	if points.size() != n or previous.size() != n:
		return false
	if (low_detail[s] != 0) != is_low:
		low_detail[s] = 1 if is_low else 0
		_resample(s, n)
	var was: Vector2 = centre[s]
	var f := first[s]
	for k in n:
		pos[f + k] = points[k]
		prev[f + k] = previous[k]
	centre[s] = body["centre"]
	hop_timer[s] = body["hop_timer"]
	heading[s] = body["heading"]
	held[s] = 1 if body["held"] else 0
	supported[s] = 1 if body["supported"] else 0
	_streams[s].state = body["rng_state"]
	if body.has("calm"):
		calm[s] = int(body["calm"])
		still_ticks[s] = int(body.get("still", 0))
		rest_anchor[s] = body.get("anchor", centre[s])
		pile[s] = int(body.get("pile", 0))
	else:
		_wake_at(s)
	if centre[s].distance_squared_to(was) > 1.0 and calm[s] != PARKED:
		_wake_around(was, bound_r[s], s)
	return true


# --- Calm and detail (chunk 15) ---------------------------------------------

## The slime's calm (ACTIVE, RESTING or PARKED), -1 for a missing slime.
func calm_of(slime_id: int) -> int:
	var s := index_of(slime_id)
	return calm[s] if s >= 0 else -1


func is_parked(slime_id: int) -> bool:
	var s := index_of(slime_id)
	return s >= 0 and calm[s] == PARKED


## Whether the slime's ring has the zoomed-out point count.
func is_low_detail(slime_id: int) -> bool:
	var s := index_of(slime_id)
	return s >= 0 and low_detail[s] != 0


## Parks the slime (off screen): from now on it is neither simulated nor
## touched, not even as a wall, until unpark(). Its velocity is dropped.
# @spec-link [[req_offscreen_simulation]]
func park(slime_id: int) -> void:
	var s := index_of(slime_id)
	if s < 0 or calm[s] == PARKED:
		return
	calm[s] = PARKED
	still_ticks[s] = 0
	_set_velocity_at(s, Vector2.ZERO)
	_drift[s] = Vector2.ZERO


## Simulates a parked slime again, at rest where it was put.
func unpark(slime_id: int) -> void:
	var s := index_of(slime_id)
	if s < 0 or calm[s] != PARKED:
		return
	calm[s] = ACTIVE
	still_ticks[s] = 0
	_set_velocity_at(s, Vector2.ZERO)


## Moves the whole slime by `delta`, its velocity and shape kept (how
## Offscreen carries a parked slime along).
func translate(slime_id: int, delta: Vector2) -> void:
	var s := index_of(slime_id)
	if s < 0:
		return
	for i in range(first[s], first[s] + npts[s]):
		pos[i] += delta
		prev[i] += delta
	centre[s] += delta


## Wakes a resting slime (ACTIVE again). Nothing for an active or parked one.
func wake(slime_id: int) -> void:
	var s := index_of(slime_id)
	if s >= 0:
		_wake_at(s)


## Wakes every resting slime whose centre is in `box`. Returns how many.
func wake_resting_in(box: Rect2) -> int:
	var woken := 0
	for s in slime_count:
		if calm[s] == RESTING and box.has_point(centre[s]):
			woken += _wake_at(s)
	return woken


## Wakes every resting slime whose ring may reach within `radius` of `point`.
## Returns how many.
func wake_around(point: Vector2, radius: float) -> int:
	return _wake_around(point, radius, -1)


## Gives the slime's ring the zoomed-out point count (on) or the full one
## (off), read off its current shape (_resample). False when nothing changed.
# @spec-link [[req_offscreen_simulation]]
func set_low_detail(slime_id: int, on: bool) -> bool:
	var s := index_of(slime_id)
	if s < 0 or (low_detail[s] != 0) == on:
		return false
	low_detail[s] = 1 if on else 0
	_resample(s, _detail_points(s, size[s]))
	return true


# --- Ticking ----------------------------------------------------------------

## Advances every body by `dt` seconds (the simulation's fixed tick).
func tick(dt: float) -> void:
	_h = dt / substeps
	hopped.clear()
	if auto_hops:
		_auto_hops(dt)
	# A resting or parked slime keeps its support: nothing moves it.
	for s in slime_count:
		if calm[s] == ACTIVE:
			supported[s] = 0
	for sub in substeps:
		_integrate(_h)
		if sub == 0:
			_build_pairs()
		for it in iterations:
			_solve_contacts()
			_solve_rings()
			_solve_terrain()
	_touching.clear()
	for k in _pair_touch.size():
		if _pair_touch[k] != 0:
			_touching.append(Vector2i(id[_pairs[2 * k]], id[_pairs[2 * k + 1]]))
	_rest()


## The resting-pile rule (see the class doc), after the tick. A resting pile
## touching a slime moving faster than WAKE_SPEED wakes. Each active pile
## slime counts its still, supported ticks; a group of touching active pile
## slimes whose every member has counted REST_TICKS rests together. Whole
## piles rest and wake as one: half a pile resting would make its moving
## half take every overlap against the wall, jolt, and wake it again.
# @spec-link [[req_offscreen_simulation]]
func _rest() -> void:
	if not rest_enabled:
		for s in slime_count:
			_wake_at(s)
		return
	var drift2 := REST_DRIFT * REST_DRIFT
	var fast2 := WAKE_SPEED * _h * WAKE_SPEED * _h
	for k in _pair_touch.size():
		if _pair_touch[k] == 0:
			continue
		var a: int = _pairs[2 * k]
		var b: int = _pairs[2 * k + 1]
		if calm[a] == RESTING and calm[b] == ACTIVE and state[b] != STATE_SLEEPER:
			if _drift[b].length_squared() > fast2:
				_wake_at(a)
		elif calm[b] == RESTING and calm[a] == ACTIVE and state[a] != STATE_SLEEPER:
			if _drift[a].length_squared() > fast2:
				_wake_at(b)
	var ready := false
	for s in slime_count:
		if calm[s] != ACTIVE or not _can_rest(s):
			continue
		if supported[s] == 0 or centre[s].distance_squared_to(rest_anchor[s]) > drift2:
			still_ticks[s] = 0
			rest_anchor[s] = centre[s]
			continue
		still_ticks[s] = mini(still_ticks[s] + 1, REST_TICKS)
		ready = ready or still_ticks[s] == REST_TICKS
	if ready:
		_rest_piles()


## Rests every group of touching active pile slimes whose members have all
## been still for REST_TICKS (union-find over the touching pairs).
func _rest_piles() -> void:
	var root := PackedInt32Array()
	root.resize(slime_count)
	for s in slime_count:
		root[s] = s
	for k in _pair_touch.size():
		if _pair_touch[k] == 0:
			continue
		var a: int = _pairs[2 * k]
		var b: int = _pairs[2 * k + 1]
		if calm[a] != ACTIVE or calm[b] != ACTIVE or not _can_rest(a) or not _can_rest(b):
			continue
		var ra := _find(root, a)
		var rb := _find(root, b)
		if ra != rb:
			root[maxi(ra, rb)] = mini(ra, rb)
	# A group rests when none of its members is short of REST_TICKS.
	var short := PackedByteArray()
	short.resize(slime_count)
	for s in slime_count:
		if calm[s] == ACTIVE and _can_rest(s) and still_ticks[s] < REST_TICKS:
			short[_find(root, s)] = 1
	for s in slime_count:
		if calm[s] != ACTIVE or not _can_rest(s):
			continue
		var r := _find(root, s)
		if short[r] != 0:
			continue
		calm[s] = RESTING
		still_ticks[s] = 0
		pile[s] = id[r]
		_set_velocity_at(s, Vector2.ZERO)
		_drift[s] = Vector2.ZERO


static func _find(root: PackedInt32Array, s: int) -> int:
	while root[s] != s:
		root[s] = root[root[s]]
		s = root[s]
	return s


## The whole state of the slimes, as plain data in id order, for
## Simulation.dump(). Centres are rounded to 0.01 px and timers to 0.1 ms, so
## the dump is stable to print; the rng states are strings (64-bit).
func dump() -> Array:
	var out := []
	for s in slime_count:
		out.append({
			"id": id[s],
			"species": species[s],
			"size": size[s],
			"state": STATE_NAMES[state[s]],
			"centre": _centre_at(s).snapped(Vector2(0.01, 0.01)),
			"velocity": _velocity_at(s).snapped(Vector2(0.01, 0.01)),
			"hop_timer": snappedf(hop_timer[s], 0.0001),
			"heading": heading[s],
			"held": held[s] != 0,
			"supported": supported[s] != 0,
			"rng_state": str(_streams[s].state),
			"calm": CALM_NAMES[calm[s]],
			"still": still_ticks[s],
			"pile": pile[s],
			"low": low_detail[s] != 0,
		})
	return out


# --- Internals --------------------------------------------------------------

func _can_hop_at(s: int) -> bool:
	return (state[s] == STATE_TRAIN or state[s] == STATE_FREE) and held[s] == 0 and calm[s] == ACTIVE


## Whether the slime may rest: the pile states, which never hop (a slime in a
## basket, or asleep at bedtime).
func _can_rest(s: int) -> bool:
	return state[s] == STATE_IN_BASKET or state[s] == STATE_BEDTIME_ASLEEP


## Whether the slime is a wall in the contacts: a sleeper, or resting.
func _is_wall(s: int) -> bool:
	return state[s] == STATE_SLEEPER or calm[s] == RESTING


## Wakes slime index `s` and, when it rests, its whole pile. Returns how many
## slimes woke.
func _wake_at(s: int) -> int:
	var woken := 0
	if calm[s] == RESTING:
		var group := pile[s]
		for t in slime_count:
			if calm[t] == RESTING and pile[t] == group:
				calm[t] = ACTIVE
				still_ticks[t] = 0
				rest_anchor[t] = centre[t]
				pile[t] = 0
				woken += 1
	if calm[s] == ACTIVE:
		still_ticks[s] = 0
		rest_anchor[s] = centre[s]
	return woken


## Wakes the resting slimes (all but index `except`) whose ring may reach
## within `radius` of `point`. Returns how many.
func _wake_around(point: Vector2, radius: float, except: int) -> int:
	var woken := 0
	for s in slime_count:
		if s == except or calm[s] != RESTING:
			continue
		var reach := radius + bound_r[s] + TOUCH_SKIN
		if centre[s].distance_squared_to(point) < reach * reach:
			woken += _wake_at(s)
	return woken


## The ring point count of slime index `s` at `slime_size`, at its detail.
func _detail_points(s: int, slime_size: int) -> int:
	return low_points_for(slime_size) if low_detail[s] != 0 else points_for(slime_size)


## Gives slime index `s` a ring of `n` points read off its current shape: the
## new points sit at even angles from its point 0's, each at the radius of
## the current ring there (its radial profile), all moving at the slime's
## mean velocity; the rest ring, area and edge are the regular `n`-gon's.
## Its slice changes size like in _reshape.
func _resample(s: int, n: int) -> void:
	var f := first[s]
	var old := npts[s]
	var c := _centre_at(s)
	var velocity := _velocity_at(s)
	var a0 := (pos[f] - c).angle()
	var r := ring_radius[s]
	var ring := PackedVector2Array()
	var back := PackedVector2Array()
	var offs := PackedVector2Array()
	ring.resize(n)
	back.resize(n)
	offs.resize(n)
	var step := velocity * _h
	for k in n:
		var t := float(k) * old / n
		var i := int(t)
		var fr := t - i
		var r0 := (pos[f + i] - c).length()
		var r1 := (pos[f + (i + 1) % old] - c).length()
		var a := a0 + TAU * k / n
		ring[k] = c + Vector2.from_angle(a) * (r0 + (r1 - r0) * fr)
		back[k] = ring[k] - step
		offs[k] = Vector2.from_angle(TAU * k / n + PI * 0.5) * r
	pos = pos.slice(0, f) + ring + pos.slice(f + old)
	prev = prev.slice(0, f) + back + prev.slice(f + old)
	rest_off = rest_off.slice(0, f) + offs + rest_off.slice(f + old)
	for t in range(s + 1, slime_count):
		first[t] += n - old
	npts[s] = n
	rest_area[s] = _polygon_area(n, r)
	rest_edge[s] = 2.0 * r * sin(PI / n)
	centre[s] = c
	_wake_at(s)
	topology_version += 1


func _centre_at(s: int) -> Vector2:
	var c := Vector2.ZERO
	var f := first[s]
	var n := npts[s]
	for i in range(f, f + n):
		c += pos[i]
	return c / n


func _velocity_at(s: int) -> Vector2:
	var v := Vector2.ZERO
	var f := first[s]
	var n := npts[s]
	for i in range(f, f + n):
		v += pos[i] - prev[i]
	return v / (n * _h)


func _set_velocity_at(s: int, velocity: Vector2) -> void:
	var step := velocity * _h
	for i in range(first[s], first[s] + npts[s]):
		prev[i] = pos[i] - step


func _hop_at(s: int, velocity: Vector2) -> void:
	var step := velocity * _h
	for i in range(first[s], first[s] + npts[s]):
		prev[i] -= step
	supported[s] = 0
	hopped.append(id[s])


## Automatic hops: each able slime counts its timer down; at zero, if it
## stands on something, it hops (heading-slanted, strength jittered by its
## stream, or at its hop_aim when steered) and draws its next interval; if
## not, it hops on landing. Every hop_aim is then cleared.
# @spec-link [[req_hopping_behavior]]
func _auto_hops(dt: float) -> void:
	for s in slime_count:
		if not _can_hop_at(s):
			continue
		var t := hop_timer[s] - dt * hop_rate
		if t > 0.0:
			hop_timer[s] = t
			continue
		hop_timer[s] = 0.0
		if supported[s] == 0:
			continue
		var stream: Rng = _streams[s]
		var strength := 1.0 + stream.randf_range(-HOP_STRENGTH_JITTER, HOP_STRENGTH_JITTER)
		var direction := Vector2(heading[s] * HOP_FORWARD, -1.0)
		if hop_aim[s] != Vector2.ZERO:
			_hop_at(s, hop_aim[s])
		else:
			_hop_at(s, hop_velocity(size[s], direction, strength))
		var interval := hop_interval_range(size[s])
		hop_timer[s] = stream.randf_range(interval.x, interval.y)
	hop_aim.fill(Vector2.ZERO)


## Gives slime index `s` a fresh rest ring of `slime_size` centred at `at`,
## moving at `velocity`, replacing its point slice (the later slimes' slices
## move to stay back to back).
func _reshape(s: int, slime_size: int, at: Vector2, velocity: Vector2) -> void:
	var n := _detail_points(s, slime_size)
	var r := ring_radius_for(slime_size)
	_wake_at(s)
	var ring := PackedVector2Array()
	var offs := PackedVector2Array()
	ring.resize(n)
	offs.resize(n)
	for k in n:
		# Point 0 at the bottom: the ring is mirror-symmetric about the
		# vertical and stands on a point (its stable resting pose), whatever
		# the point count, so a resting slime doesn't roll.
		var a := TAU * k / n + PI * 0.5
		var off := Vector2(cos(a), sin(a)) * r
		offs[k] = off
		ring[k] = at + off
	var step := velocity * _h
	var back := PackedVector2Array()
	back.resize(n)
	for k in n:
		back[k] = ring[k] - step
	var f := first[s]
	var old := npts[s]
	pos = pos.slice(0, f) + ring + pos.slice(f + old)
	prev = prev.slice(0, f) + back + prev.slice(f + old)
	rest_off = rest_off.slice(0, f) + offs + rest_off.slice(f + old)
	for t in range(s + 1, slime_count):
		first[t] += n - old
	npts[s] = n
	size[s] = slime_size
	ring_radius[s] = r
	rest_area[s] = _polygon_area(n, r)
	rest_edge[s] = 2.0 * r * sin(PI / n)
	bound_r[s] = r * 1.3
	centre[s] = at
	angle0[s] = 0.0
	topology_version += 1


func _remove_at(s: int) -> void:
	var f := first[s]
	var n := npts[s]
	pos = pos.slice(0, f) + pos.slice(f + n)
	prev = prev.slice(0, f) + prev.slice(f + n)
	rest_off = rest_off.slice(0, f) + rest_off.slice(f + n)
	for t in range(s + 1, slime_count):
		first[t] -= n
	id.remove_at(s)
	first.remove_at(s)
	npts.remove_at(s)
	size.remove_at(s)
	species.remove_at(s)
	state.remove_at(s)
	held.remove_at(s)
	supported.remove_at(s)
	ring_radius.remove_at(s)
	rest_area.remove_at(s)
	rest_edge.remove_at(s)
	bound_r.remove_at(s)
	hop_timer.remove_at(s)
	heading.remove_at(s)
	hop_aim.remove_at(s)
	centre.remove_at(s)
	angle0.remove_at(s)
	_drift.remove_at(s)
	calm.remove_at(s)
	low_detail.remove_at(s)
	still_ticks.remove_at(s)
	rest_anchor.remove_at(s)
	pile.remove_at(s)
	_slime_cell.remove_at(s)
	_streams.remove_at(s)
	slime_count -= 1
	_touching.clear()
	_pairs.clear()
	_pair_touch.clear()
	topology_version += 1


## Centre offsets of the parts of a split, their mean zero, far enough apart
## that the drawn bodies (ring radius + EDGE) don't overlap.
func _split_offsets(count: int) -> PackedVector2Array:
	var gap := 2.0 * (RING_RADIUS_SIZE_1 + EDGE) + 4.0
	if count == 2:
		return PackedVector2Array([Vector2(-gap * 0.5, 0.0), Vector2(gap * 0.5, 0.0)])
	var out := PackedVector2Array()
	var radius := gap / sqrt(3.0)
	for degrees in [150.0, 270.0, 30.0]:
		out.append(Vector2.from_angle(deg_to_rad(degrees)) * radius)
	return out


## The gravity a slime in `slime_state` feels, px/s²: `gravity` turned to
## `free_down` for a free slime, the plain `gravity` for every other state.
# @spec-link [[req_tilt_input]]
# @spec-link [[req_slime_states]]
func gravity_for(slime_state: int) -> Vector2:
	if slime_state != STATE_FREE or free_down == Vector2.DOWN:
		return gravity
	return free_down * gravity.length()


## Verlet step: gravity (gravity_for the slime's state), air drag, and
## internal damping (each point's velocity pulled toward its slime's mean).
## Also refreshes each slime's centre and point-0 angle.
func _integrate(h: float) -> void:
	var p := pos
	var o := prev
	var g := gravity * h * h
	var g_free := gravity_for(STATE_FREE) * h * h
	var ms := max_speed * h
	var idamp := internal_damping
	var damp := 1.0 - air_drag * h
	for s in slime_count:
		var f: int = first[s]
		var cnt: int = npts[s]
		var end: int = f + cnt
		if state[s] == STATE_SLEEPER or calm[s] != ACTIVE:
			# Asleep, resting or parked: it doesn't simulate (its points stay
			# put), but its point-0 angle is kept right for the contacts.
			var r_sleep: Vector2 = p[f] - centre[s]
			angle0[s] = atan2(r_sleep.y, r_sleep.x)
			_drift[s] = Vector2.ZERO
			continue
		var gs: Vector2 = g_free if state[s] == STATE_FREE else g
		var mean := Vector2.ZERO
		for i in range(f, end):
			mean += p[i] - o[i]
		mean /= cnt
		var c := Vector2.ZERO
		for i in range(f, end):
			var cur: Vector2 = p[i]
			var v: Vector2 = cur - o[i]
			v = ((v + (mean - v) * idamp) * damp).limit_length(ms) + gs
			o[i] = cur
			var nxt := cur + v
			p[i] = nxt
			c += nxt
		c /= cnt
		_drift[s] = c - centre[s]
		centre[s] = c
		var r0: Vector2 = p[f] - c
		angle0[s] = atan2(r0.y, r0.x)


## Counting sort of the slimes into a uniform grid on their centres, then the
## list of candidate pairs (index a < index b). Cells are at least as wide as
## the widest possible pair distance, so neighbouring cells are enough.
func _build_pairs() -> void:
	_pairs.clear()
	# Parked slimes are left out of the grid (they touch nothing).
	var placed := 0
	var low := Vector2.INF
	var high := -Vector2.INF
	for s in slime_count:
		if calm[s] == PARKED:
			continue
		placed += 1
		low = low.min(centre[s])
		high = high.max(centre[s])
	if placed < 2:
		_pair_touch.resize(0)
		return
	var extent := high - low
	_cell_size = maxf(104.0, maxf(extent.x, extent.y) / 256.0)
	_grid_origin = low
	_grid_w = int(extent.x / _cell_size) + 1
	_grid_h = int(extent.y / _cell_size) + 1
	var cells := _grid_w * _grid_h
	_cell_start.resize(cells + 1)
	_cell_start.fill(0)
	_cell_items.resize(placed)
	var inv := 1.0 / _cell_size
	for s in slime_count:
		if calm[s] == PARKED:
			_slime_cell[s] = -1
			continue
		var c: Vector2 = centre[s] - low
		var cell := mini(int(c.y * inv), _grid_h - 1) * _grid_w + mini(int(c.x * inv), _grid_w - 1)
		_slime_cell[s] = cell
		_cell_start[cell + 1] += 1
	for k in cells:
		_cell_start[k + 1] += _cell_start[k]
	var fill := _cell_start.slice(0, cells)
	for s in slime_count:
		var cell: int = _slime_cell[s]
		if cell < 0:
			continue
		_cell_items[fill[cell]] = s
		fill[cell] += 1
	for s in slime_count:
		var cell: int = _slime_cell[s]
		if cell < 0:
			continue
		var wall_s := _is_wall(s)
		var cx := cell % _grid_w
		var cy := cell / _grid_w
		var cs: Vector2 = centre[s]
		var rs: float = bound_r[s]
		for gy in range(maxi(cy - 1, 0), mini(cy + 2, _grid_h)):
			for gx in range(maxi(cx - 1, 0), mini(cx + 2, _grid_w)):
				var gc := gy * _grid_w + gx
				for q in range(_cell_start[gc], _cell_start[gc + 1]):
					var t: int = _cell_items[q]
					# Two walls (sleepers, resting slimes) are never paired.
					if t <= s or (wall_s and _is_wall(t)):
						continue
					# Margin: slimes may close in during the tick's substeps.
					var rr: float = rs + bound_r[t] + 8.0
					if (centre[t] - cs).length_squared() < rr * rr:
						_pairs.append(s)
						_pairs.append(t)
	_pair_touch.resize(_pairs.size() / 2)
	_pair_touch.fill(0)


## Ring against ring. For each side of a pair, the points of ring a facing b
## that are inside b's radial profile (read off b's points, ordered by angle
## around its centre) move out by half the overlap, and the whole of ring b
## moves back by the same total, so momentum is kept. Also records touching
## pairs and support (a point resting on the upper half of another ring).
func _solve_contacts() -> void:
	var p := pos
	var o := prev
	var mu := slime_friction
	var np := _pairs.size()
	var inv_tau := 1.0 / TAU
	var skin := TOUCH_SKIN
	var i := 0
	while i < np:
		var s0: int = _pairs[i]
		var s1: int = _pairs[i + 1]
		var pair := i / 2
		i += 2
		var rr: float = bound_r[s0] + bound_r[s1]
		if (centre[s1] - centre[s0]).length_squared() >= rr * rr:
			continue
		for side in 2:
			var a := s0 if side == 0 else s1
			var b := s1 if side == 0 else s0
			var ca: Vector2 = centre[a]
			var cb: Vector2 = centre[b]
			var rb: float = bound_r[b] + skin
			var rb2 := rb * rb
			var nb: int = npts[b]
			var fb: int = first[b]
			var b0: float = angle0[b]
			var na: int = npts[a]
			var fa: int = first[a]
			var dir := cb - ca
			var ta := (atan2(dir.y, dir.x) - angle0[a]) * inv_tau
			if ta < 0.0:
				ta += 1.0
			var mid := int(ta * na + 0.5)
			var half := na / 4 + 1
			var kb := nb * inv_tau
			var react := Vector2.ZERO
			var drag := Vector2.ZERO
			var vb: Vector2 = _drift[b]
			var touched := false
			var rests := false
			# A sleeper (or a resting slime) is a wall: its points only feel
			# the touch, and a slime
			# against it takes the whole overlap.
			var still: bool = _is_wall(a)
			var against_still: bool = _is_wall(b)
			var share := 1.0 if against_still else 0.5
			for m in range(mid - half, mid + half + 1):
				var j := fa + (m % na + na) % na
				var rel: Vector2 = p[j] - cb
				var d2 := rel.length_squared()
				if d2 >= rb2 or d2 < 1e-6:
					continue
				var t := (atan2(rel.y, rel.x) - b0) * kb
				if t < 0.0:
					t += nb
				var k := int(t)
				if k >= nb:
					k -= nb
				var fr := t - k
				var k2 := k + 1 if k + 1 < nb else 0
				var r0: float = (p[fb + k] - cb).length()
				var r := r0 + ((p[fb + k2] - cb).length() - r0) * fr
				var rs := r + skin
				if d2 >= rs * rs:
					continue
				touched = true
				var d := sqrt(d2)
				if rel.y < -SUPPORT_NORMAL_Y * d:
					rests = true
				if d < r and not still:
					var push := rel * ((r - d) * share / d)
					var moved: Vector2 = p[j] + push
					p[j] = moved
					react -= push
					# Friction: slow the point's sliding along b's surface.
					var nrm := rel / d
					var slide: Vector2 = moved - o[j] - vb
					slide = (slide - nrm * slide.dot(nrm)) * mu
					o[j] += slide
					drag += slide
			if touched:
				_pair_touch[pair] = 1
			if rests and not still:
				supported[a] = 1
			if react != Vector2.ZERO and not against_still:
				react /= nb
				drag /= nb
				for q in range(fb, fb + nb):
					p[q] += react
					o[q] -= drag


## Edge springs, area (pressure) and shape matching, per ring (the spike's
## solver, with Jacobi edge springs).
func _solve_rings() -> void:
	var p := pos
	var ks := edge_stiffness * 0.5
	var ka := area_stiffness
	var kshape := shape_stiffness
	for s in slime_count:
		if state[s] == STATE_SLEEPER or calm[s] != ACTIVE:
			continue
		var f: int = first[s]
		var cnt: int = npts[s]
		var last := f + cnt - 1
		var rest: float = rest_edge[s]
		# Edge springs (position-based distance constraints), Jacobi style:
		# every correction comes from the positions before the pass, so the
		# ring has no preferred direction (a sequential pass makes a squashed
		# ring creep sideways).
		var pp: Vector2 = p[last]
		var cur: Vector2 = p[f]
		var first_p := cur
		var d_prev := cur - pp
		var l_prev := d_prev.length()
		var e_prev := (l_prev - rest) / l_prev if l_prev > 1e-5 else 0.0
		for j in range(f, last + 1):
			var nx: Vector2 = p[j + 1] if j < last else first_p
			var d_next := nx - cur
			var l_next := d_next.length()
			var e_next := (l_next - rest) / l_next if l_next > 1e-5 else 0.0
			p[j] = cur + (d_next * e_next - d_prev * e_prev) * ks
			d_prev = d_next
			e_prev = e_next
			cur = nx
		# One read pass: area, area-gradient norm, centre, and the rotation
		# that best fits the rest circle.
		var area := 0.0
		var grad_sq := 0.0
		var c := Vector2.ZERO
		var sd := 0.0
		var sc := 0.0
		pp = p[last]
		cur = p[f]
		for j in range(f, last + 1):
			var nx: Vector2 = p[j + 1] if j < last else p[f]
			area += pp.cross(cur)
			grad_sq += (nx - pp).length_squared()
			c += cur
			var q: Vector2 = rest_off[j]
			sd += q.dot(cur)
			sc += q.cross(cur)
			pp = cur
			cur = nx
		area *= 0.5
		grad_sq *= 0.25
		c /= cnt
		var lam := 0.0
		if grad_sq > 1e-6:
			lam = (rest_area[s] - area) / grad_sq * ka
		var rot := Vector2(sd, sc).normalized()
		# Apply pass: area gradient, then the shape-matching pull, from the
		# neighbours' positions before the pass.
		pp = p[last]
		cur = p[f]
		first_p = cur
		for j in range(f, last + 1):
			var nx: Vector2 = p[j + 1] if j < last else first_p
			var moved := cur + Vector2(nx.y - pp.y, pp.x - nx.x) * (0.5 * lam)
			var q: Vector2 = rest_off[j]
			var goal := c + Vector2(q.x * rot.x - q.y * rot.y, q.x * rot.y + q.y * rot.x)
			p[j] = moved + (goal - moved) * kshape
			pp = cur
			cur = nx


## Ring points against the terrain segments (O78): a point inside the terrain,
## or closer than `terrain_skin` to it, goes to `terrain_skin` off the nearest
## surface point; its velocity loses the part going into the surface and
## `terrain_friction` of the part along it. A point pushed out by a surface
## facing up supports its slime. The shut doors are solved the same way,
## after the terrain.
func _solve_terrain() -> void:
	if terrain != null and not terrain.is_empty():
		_solve_against(terrain)
	for door in doors:
		if door != null and not door.is_empty():
			_solve_against(door)


func _solve_against(tf: TerrainSegments) -> void:
	var p := pos
	var o := prev
	var sa := tf.seg_a
	var sdir := tf.seg_d
	var sil := tf.seg_inv_len2
	var sn := tf.seg_n
	var sna := tf.seg_na
	var snb := tf.seg_nb
	var starts := tf.cell_start
	var items := tf.cell_items
	var ox := tf.origin.x
	var oy := tf.origin.y
	var inv := tf.inv_cell
	var gw := tf.grid_w
	var gh := tf.grid_h
	var keep := 1.0 - terrain_friction
	var skin := terrain_skin
	var skin2 := skin * skin
	for s in slime_count:
		if state[s] == STATE_SLEEPER or calm[s] != ACTIVE:
			continue
		var f: int = first[s]
		var carried := false
		for i in range(f, f + npts[s]):
			var c: Vector2 = p[i]
			var cx := int(floor((c.x - ox) * inv))
			var cy := int(floor((c.y - oy) * inv))
			if cx < 0 or cy < 0 or cx >= gw or cy >= gh:
				continue
			var cell := cy * gw + cx
			var best := -1
			var best_d2 := INF
			var best_q := Vector2.ZERO
			var best_t := 0.0
			for qi in range(starts[cell], starts[cell + 1]):
				var k: int = items[qi]
				var a: Vector2 = sa[k]
				var d: Vector2 = sdir[k]
				var t := clampf((c - a).dot(d) * sil[k], 0.0, 1.0)
				var q := a + d * t
				var d2 := c.distance_squared_to(q)
				if d2 < best_d2:
					best_d2 = d2
					best = k
					best_q = q
					best_t = t
			if best < 0:
				continue
			var n: Vector2 = sn[best]
			var off := c - best_q
			# Inside or out: at a segment's end, by the vertex's normal
			# (TerrainSegments.side_normal, inlined).
			var side := n
			if best_t <= 0.0:
				side = sna[best]
			elif best_t >= 1.0:
				side = snb[best]
			if off.dot(side) >= 0.0:
				# Outside: only within the skin, pushed away from the nearest
				# surface point (round around convex corners).
				if best_d2 >= skin2:
					continue
				if best_d2 > 1e-8:
					n = off / sqrt(best_d2)
			var target := best_q + n * skin
			p[i] = target
			var v: Vector2 = target - o[i]
			var vn := v.dot(n)
			var vt := v - n * vn
			o[i] = target - (vt * keep + n * maxf(vn, 0.0))
			if n.y < -SUPPORT_NORMAL_Y:
				carried = true
		if carried:
			supported[s] = 1

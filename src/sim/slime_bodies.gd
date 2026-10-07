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
##            the anchor fixed where its count started) for REST_TICKS, velocities dropped; it keeps
##            its `pile` (the group's lowest id). Piles wake locally (the
##            local wake, D156): every wake goes through _wake_at, which
##            wakes that slime alone; the rest of the pile rests on, a wall,
##            keeping its `pile`, and a woken slime's `pile` is 0 until it
##            rests again with its new group. What wakes a resting slime:
##            a touching slime moving faster than WAKE_SPEED (a hop, a
##            landing, a neighbour shifting), its own state change (bedtime,
##            sunrise, a basket catching or releasing it), a new velocity or
##            body, a slime moved away by a body from where it touched it, a
##            slime removed, fused or split touching it, or whoever knows of
##            a disturbance calling wake / wake_around / wake_resting_in (a
##            call, a door: Offscreen, FrontierSets). A sleeper is a state,
##            never the resting calm: no wake changes it. rest_enabled off:
##            no slime rests.
##   PARKED   off screen (Offscreen): not simulated nor touched at all, not
##            even as a wall (it is left out of the pair grid); Offscreen
##            moves it (translate) and un-parks it near the view. Nothing
##            but park / unpark changes it.
## Detail: each slime's ring has the point count of its detail level, 0
## (full, POINTS_BY_SIZE) to MAX_DETAIL (POINTS_BY_DETAIL). set_detail()
## gives a slime another level, read off its current shape (see _resample);
## the rest area follows the point count. Offscreen decides the level from
## the zoom and the crowd (set_active_detail, crowd_count).
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

## The passes of tick(), as the debug phase timers (`phases`) time them:
## the hop clears and automatic hops; integrate; the pair grid (PAIRS,
## first substep); slime contacts; rings; the terrain pass and the door
## passes (_solve_terrain); the touching list and the rest pass (REST: _rest,
## _rest_piles, the local wake); TICK_OTHER, the rest of tick() (the
## support reset, the centre cache cleared); NATIVE, the native solver's
## step() (SlimeSolver.step: every solver pass of the tick in one call, so
## on the native tick the passes before it aren't timed one by one).
enum TickPhase { AUTO_HOPS, INTEGRATE, PAIRS, CONTACTS, RINGS, TERRAIN, DOORS, REST, TICK_OTHER, NATIVE }

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
## Ring points per detail level (0: full) and size (index 0 unused).
# @spec-link [[req_offscreen_simulation]]
const POINTS_BY_DETAIL: Array[Array] = [[0, 12, 15, 18], [0, 10, 12, 15], [0, 8, 10, 12], [0, 6, 8, 9]]
const MAX_DETAIL := 3
## The detail level of a zoomed-out ring.
const LOW_DETAIL := 2
## The highest detail level a pile slime (_can_rest: in a basket, asleep at
## bedtime) takes from set_active_detail: a pile of 6-point rings creeps for
## long before it rests (stress-still's 140: about 1300 ticks, against 410 at
## this level), and a resting pile is what costs nothing.
const PILE_MAX_DETAIL := LOW_DETAIL
## A supported slime is still when its centre stays within REST_DRIFT px of an
## anchor fixed where its count started, for REST_TICKS ticks in a row; a
## step beyond REST_DRIFT (or losing support) moves the anchor to the centre
## and starts the count again (the anchor never slides along). A distance, not a speed: a settled pile
## jitters by a fraction of a pixel, now and then at 10-20 px/s for a tick.
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
## The game leaves it on. Tests turn it off for set-ups that the seeded hops
## would disturb (a pile settled first, a slime placed by hand); it costs one
## branch per tick.
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
## The game leaves it on. A few physics tests turn it off to watch the solver
## alone, without the rest rule; it costs one branch per tick.
var rest_enabled := true
## The debug phase timers of tick() (chunk 5N, U0a: src/debug/phase_timers.gd,
## PhaseTimers.attach), or null: off, as in every normal run (one null check
## per pass, no clock read). Measurement only: tick() and the terrain pass
## (SlimeSolverGD.solve_terrain) hand it start() and lap(TickPhase), nothing reads it back, so the state
## and its hash are the same either way. Not in dump(). Untyped: src/sim
## names nothing in src/debug (left out of release).
var phases = null
## The native solver (SlimeSolver, chunk 5N: use_native), or null: the
## GDScript tick. Untyped: the class comes from the extension, named only
## through ClassDB (TickChoice), so this script parses without it.
var _solver = null

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
## Each slime's detail level, 0 (full) to MAX_DETAIL (see the class doc).
var detail := PackedByteArray()
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
## The ids of the train slimes (STATE_TRAIN) that took an automatic hop
## during the last tick, ascending: the train's hop counters read it (the
## PERF line's hops), and its relay, in the same tick (Train.follow). A fact
## about the tick, cleared by every tick, so not state: not in dump() nor in
## saves. A hop() (the celebration's) isn't in it.
# @spec-link [[req_platform_and_performance_targets]]
var train_hopped := PackedInt32Array()

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
# Per slime, a box holding all its points during the terrain contacts (see
# _solve_terrain): the shut doors skip the slimes whose box is outside their
# grid.
var _box_lo := PackedVector2Array()
var _box_hi := PackedVector2Array()
# centre_of()'s cache, per slime: the exact _centre_at() of its points, valid
# while _centre_ok is 1. Every write to a slime's points clears its flag (a
# tick clears them all), so a centre is summed at most once between moves.
var _centre_cache := PackedVector2Array()
var _centre_ok := PackedByteArray()


## `master`: the simulation's master Rng. Each slime draws from its own
## stream, master.derive("slime:<id>"), so its hops don't depend on others.
## The tick is the run's (TickChoice.current(), see use_native).
func _init(master: Rng) -> void:
	_master = master
	if TickChoice.current().native:
		use_native(true)


# --- Native or GDScript tick (chunk 5N) ------------------------------------

## Runs tick()'s solver passes on the native solver (true) or in GDScript
## (false). Returns whether the tick asked for is the one in use: false, with
## an error, when the extension is missing or its solver can't read these
## bodies (SlimeSolver.check_schema); the GDScript tick runs on. Each native
## pass that doesn't run (a stub returns false) falls back to its GDScript
## pass (see tick()). The solver keeps nothing between calls and the state
## lives here, so a run (or a save) moves from one tick to the other at any
## time.
func use_native(on: bool) -> bool:
	if not on:
		_solver = null
		return true
	if not ClassDB.class_exists(TickChoice.SOLVER_CLASS):
		push_error("SlimeBodies: the native tick needs the slime_native extension (%s), which isn't loaded."
				% TickChoice.SOLVER_CLASS)
		return false
	var solver: Object = ClassDB.instantiate(TickChoice.SOLVER_CLASS)
	var problems: PackedStringArray = solver.check_schema(self)
	if not problems.is_empty():
		push_error("SlimeBodies: the native solver can't read these bodies: %s" % ", ".join(problems))
		return false
	_solver = solver
	return true


## Whether tick() runs on the native solver (use_native).
func uses_native() -> bool:
	return _solver != null


# --- Sizes ------------------------------------------------------------------

## How many ring points a slime of `slime_size` has.
static func points_for(slime_size: int) -> int:
	return POINTS_BY_SIZE[slime_size]


## The rest ring's radius of a slime of `slime_size`, px: its area grows
## with the size.
static func ring_radius_for(slime_size: int) -> float:
	return RING_RADIUS_SIZE_1 * sqrt(float(slime_size))


## The area of the rest ring (a regular polygon), proportional to the size
## within about 3 %.
static func rest_area_for(slime_size: int) -> float:
	return _polygon_area(points_for(slime_size), ring_radius_for(slime_size))


## The ring point count of a slime of `slime_size` at detail `level`
## (POINTS_BY_DETAIL; level 0 is points_for()).
static func detail_points_for(slime_size: int, level: int) -> int:
	assert(level >= 0 and level <= MAX_DETAIL, "SlimeBodies: invalid detail level %d" % level)
	return POINTS_BY_DETAIL[level][slime_size]


## The area of a regular polygon of `n` points on a circle of radius `r`.
static func _polygon_area(n: int, r: float) -> float:
	return 0.5 * n * r * r * sin(TAU / n)


## (shortest, longest) seconds between two automatic hops
## (SlimeHops.interval_range).
static func hop_interval_range(slime_size: int) -> Vector2:
	return SlimeHops.interval_range(slime_size)


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
	_centre_cache.append(Vector2.ZERO)
	_centre_ok.append(0)
	angle0.append(0.0)
	_drift.append(Vector2.ZERO)
	calm.append(ACTIVE)
	detail.append(0)
	still_ticks.append(0)
	rest_anchor.append(at)
	pile.append(0)
	_slime_cell.append(0)
	_streams.append(stream)
	slime_count += 1
	_reshape(slime_count - 1, slime_size, at, Vector2.ZERO)
	return new_id


## Removes a slime. False when there is no such slime. The resting slimes
## touching it wake, not the rest of their piles (D156).
func remove(slime_id: int) -> bool:
	var s := index_of(slime_id)
	if s < 0:
		return false
	if calm[s] != PARKED:
		_wake_around(centre[s], bound_r[s], s)
	_remove_at(s)
	return true


## Whether slime `slime_id` exists.
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

## The slime's species. `slime_id` must exist (asserted in debug builds).
func species_of(slime_id: int) -> int:
	var s := index_of(slime_id)
	assert(s >= 0, "SlimeBodies.species_of: no such slime")
	return species[s] if s >= 0 else -1


## The slime's size. `slime_id` must exist (asserted in debug builds).
func size_of(slime_id: int) -> int:
	var s := index_of(slime_id)
	assert(s >= 0, "SlimeBodies.size_of: no such slime")
	return size[s] if s >= 0 else 0


## The slime's state (TRAIN, FREE...). `slime_id` must exist (asserted in debug builds).
func state_of(slime_id: int) -> int:
	var s := index_of(slime_id)
	assert(s >= 0, "SlimeBodies.state_of: no such slime")
	return state[s] if s >= 0 else -1


## The slime's rest ring radius, px. `slime_id` must exist (asserted in debug builds).
func radius_of(slime_id: int) -> float:
	var s := index_of(slime_id)
	assert(s >= 0, "SlimeBodies.radius_of: no such slime")
	return ring_radius[s] if s >= 0 else 0.0


## The slime's rest ring area, px². `slime_id` must exist (asserted in debug builds).
func rest_area_of(slime_id: int) -> float:
	var s := index_of(slime_id)
	assert(s >= 0, "SlimeBodies.rest_area_of: no such slime")
	return rest_area[s] if s >= 0 else 0.0


## The slime's time to its next hop, seconds. `slime_id` must exist (asserted in debug builds).
func hop_timer_of(slime_id: int) -> float:
	var s := index_of(slime_id)
	assert(s >= 0, "SlimeBodies.hop_timer_of: no such slime")
	return hop_timer[s] if s >= 0 else 0.0


## A copy of the slime's ring points. `slime_id` must exist (asserted in
## debug builds).
func points_of(slime_id: int) -> PackedVector2Array:
	var s := index_of(slime_id)
	assert(s >= 0, "SlimeBodies.points_of: no such slime")
	if s < 0:
		return PackedVector2Array()
	return pos.slice(first[s], first[s] + npts[s])


## The mean of the slime's points (cached until they move).
func centre_of(slime_id: int) -> Vector2:
	var s := index_of(slime_id)
	return _centre_cached(s) if s >= 0 else Vector2.ZERO


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


## How many candidate pairs the last tick's contacts checked (the pair grid,
## built on its first substep): the solver's work, for measuring it. Read only.
func candidate_pair_count() -> int:
	return _pairs.size() / 2


# --- Changing ---------------------------------------------------------------

## Sets the slime's state, waking it when the state changes. An unknown
## slime or state is refused loudly.
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
	var c := _centre_cached(s)
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


## Holds the slime on a slope running along `tangent` (unit, the way up):
## its mean motion down the slope is taken away and `lift` px/s up it added
## (the Train gives a share of the tick's pull down the slope, so the tick
## ends nearly where it started). Its spin, squish and motion up the slope
## are left alone. How the Train holds a train slime standing on a climb
## (SlimeHops.hold_on_slope).
func hold_on_slope(slime_id: int, tangent: Vector2, lift: float) -> void:
	var s := index_of(slime_id)
	if s >= 0:
		SlimeHops.hold_on_slope(self, s, tangent, lift)


## Whether the slime hops on its own: train and free slimes not held still
## (SlimeHops.can_hop).
func can_hop(slime_id: int) -> bool:
	var s := index_of(slime_id)
	return s >= 0 and SlimeHops.can_hop(state[s], held[s], calm[s])


## Makes a supported slime hop now along `direction`, `strength` 1 for a
## normal hop. False (and nothing happens) for a missing slime, one that
## doesn't hop in its state, or one not on the ground (SlimeHops.hop_at).
func hop(slime_id: int, direction: Vector2, strength: float) -> bool:
	var s := index_of(slime_id)
	if s < 0 or not SlimeHops.can_hop(state[s], held[s], calm[s]) or supported[s] == 0:
		return false
	SlimeHops.hop_at(self, s, hop_velocity(size[s], direction, strength))
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
## next_id (slimes are created in ascending id order). Returns the id, or -1
## (SlimeBodiesSave.create_with_id).
func create_with_id(slime_id: int, slime_species: int, slime_size: int, at: Vector2,
		slime_state := STATE_TRAIN) -> int:
	return SlimeBodiesSave.create_with_id(self, slime_id, slime_species, slime_size, at, slime_state)


## Everything a save needs to put the slime's body back exactly: the points
## and their previous positions (so the velocities), the solver's centre, the
## hop timer, the heading, held and supported, its stream's state, its calm
## and detail. Empty for a missing slime (SlimeBodiesSave.body_of).
func body_of(slime_id: int) -> Dictionary:
	return SlimeBodiesSave.body_of(self, slime_id)


## Puts back a body from body_of(). False (and nothing changes) when the
## slime is missing or the point counts don't match its size at the body's
## detail level. A body that moves the slime by more than a pixel wakes the
## resting slimes touching where it was (SlimeBodiesSave.set_body).
func set_body(slime_id: int, body: Dictionary) -> bool:
	return SlimeBodiesSave.set_body(self, slime_id, body)


# --- Calm and detail (chunk 15) ---------------------------------------------

## The slime's calm (ACTIVE, RESTING or PARKED), -1 for a missing slime.
func calm_of(slime_id: int) -> int:
	var s := index_of(slime_id)
	return calm[s] if s >= 0 else -1


## Whether the slime is parked (false for a missing slime).
func is_parked(slime_id: int) -> bool:
	var s := index_of(slime_id)
	return s >= 0 and calm[s] == PARKED


## The slime's detail level (0: full), -1 for a missing slime.
func detail_of(slime_id: int) -> int:
	var s := index_of(slime_id)
	return detail[s] if s >= 0 else -1


## How many slimes cost physics on a tick: calm ACTIVE and not sleepers
## (SlimeDetail.crowd_count).
func crowd_count() -> int:
	return SlimeDetail.crowd_count(self)


## Parks the slime (off screen): from now on it is neither simulated nor
## touched, not even as a wall, until unpark() (SlimeDetail.park). Offscreen
## calls it every tick for every far slime: the parked ones return here.
func park(slime_id: int) -> void:
	var s := index_of(slime_id)
	if s >= 0 and calm[s] != PARKED:
		SlimeDetail.park(self, s)


## Simulates a parked slime again, at rest where it was put
## (SlimeDetail.unpark). Offscreen calls it every tick for every near slime:
## the unparked ones return here.
func unpark(slime_id: int) -> void:
	var s := index_of(slime_id)
	if s >= 0 and calm[s] == PARKED:
		SlimeDetail.unpark(self, s)


## Moves the whole slime by `delta`, its velocity and shape kept (how
## Offscreen carries a parked slime along, every tick: so it stays here, on
## the bodies' own arrays).
func translate(slime_id: int, delta: Vector2) -> void:
	var s := index_of(slime_id)
	if s < 0:
		return
	for i in range(first[s], first[s] + npts[s]):
		pos[i] += delta
		prev[i] += delta
	_centre_ok[s] = 0
	centre[s] += delta


## Wakes a resting slime (ACTIVE again), only it: the rest of its pile rests
## on (D156). Nothing for an active or parked one.
# @spec-link [[req_offscreen_simulation]]
func wake(slime_id: int) -> void:
	var s := index_of(slime_id)
	if s >= 0:
		_wake_at(s)


## Wakes every resting slime whose centre is in `box`. Returns how many
## (SlimeDetail.wake_resting_in).
func wake_resting_in(box: Rect2) -> int:
	return SlimeDetail.wake_resting_in(self, box)


## Wakes every resting slime whose ring may reach within `radius` of `point`.
## Returns how many.
# @spec-link [[req_offscreen_simulation]]
func wake_around(point: Vector2, radius: float) -> int:
	return _wake_around(point, radius, -1)


## Gives the slime's ring the point count of detail `level` (0 to
## MAX_DETAIL), read off its current shape, whatever its calm. False when
## nothing changed (SlimeDetail.set_detail).
func set_detail(slime_id: int, level: int) -> bool:
	return SlimeDetail.set_detail(self, slime_id, level)


## set_detail(`level`) on every calm ACTIVE slime, a pile slime at
## PILE_MAX_DETAIL at most; resting and parked slimes keep their rings.
## Returns how many rings changed (SlimeDetail.set_active_detail).
func set_active_detail(level: int) -> int:
	return SlimeDetail.set_active_detail(self, level)


# --- Ticking ----------------------------------------------------------------

## Advances every body by `dt` seconds (the simulation's fixed tick). With
## the debug phase timers on (`phases`), each pass (TickPhase) is timed as it
## ends. The hops and the support reset run here in GDScript; the solver
## passes run on the native solver when there is one (use_native): the whole
## of them in one call (SlimeSolver.step, timed as NATIVE), else pass by
## pass, each falling back to its GDScript pass when the native one doesn't
## run (_solve). step() builds the touching list and clears the centre
## cache itself, as _solve does.
func tick(dt: float) -> void:
	var ph = phases
	if ph != null:
		ph.start()
	_h = dt / substeps
	hopped.clear()
	train_hopped.clear()
	if auto_hops:
		_auto_hops(dt)
	if ph != null:
		ph.lap(TickPhase.AUTO_HOPS)
	# A resting or parked slime keeps its support: nothing moves it.
	for s in slime_count:
		if calm[s] == ACTIVE:
			supported[s] = 0
	if ph != null:
		ph.lap(TickPhase.TICK_OTHER)
	# The native step isn't timed pass by pass: one lap for the whole of it.
	if _solver != null and _solver.step(self, _h):
		if ph != null:
			ph.lap(TickPhase.NATIVE)
	else:
		_solve(ph)


## The solver passes of one tick, pass by pass (see tick()): `substeps`
## times integrate, the pair grid (first substep), then `iterations` times
## the contacts, rings and terrain; then the touching list and the rest
## pass. A pass runs on the native solver if there is one and it runs it,
## else in GDScript.
func _solve(ph) -> void:
	var sv = _solver
	for sub in substeps:
		if sv == null or not sv.integrate(self, _h):
			_integrate(_h)
		if ph != null:
			ph.lap(TickPhase.INTEGRATE)
		if sub == 0:
			if sv == null or not sv.build_pairs(self):
				_build_pairs()
			if ph != null:
				ph.lap(TickPhase.PAIRS)
		for it in iterations:
			_solve_iteration(sv, ph)
	_centre_ok.fill(0)
	if ph != null:
		ph.lap(TickPhase.TICK_OTHER)
	_touching.clear()
	for k in _pair_touch.size():
		if _pair_touch[k] != 0:
			_touching.append(Vector2i(id[_pairs[2 * k]], id[_pairs[2 * k + 1]]))
	if sv == null or not sv.rest(self, _h):
		_rest()
	if ph != null:
		ph.lap(TickPhase.REST)


## One solver iteration: contacts, rings, terrain (with the doors), each on
## the native solver `sv` if it runs it, else in GDScript (see _solve).
func _solve_iteration(sv, ph) -> void:
	if sv == null or not sv.solve_contacts(self):
		_solve_contacts()
	if ph != null:
		ph.lap(TickPhase.CONTACTS)
	if sv == null or not sv.solve_rings(self):
		_solve_rings()
	if ph != null:
		ph.lap(TickPhase.RINGS)
	if sv != null and sv.solve_terrain(self):
		# The native pass times the terrain and the doors together.
		if ph != null:
			ph.lap(TickPhase.TERRAIN)
	else:
		_solve_terrain()


## The resting-pile rule (see the class doc), after the tick, in GDScript:
## SlimeDetail.rest (the native equivalence tests call this).
func _rest() -> void:
	SlimeDetail.rest(self)


## The whole state of the slimes, as plain data in id order, for
## Simulation.dump(). Centres are rounded to 0.01 px and timers to 0.1 ms, so
## the dump is stable to print; the rng states are strings (64-bit)
## (SlimeBodiesSave.dump).
func dump() -> Array:
	return SlimeBodiesSave.dump(self)


# --- Internals --------------------------------------------------------------

## Whether the slime may rest: the pile states, which never hop (a slime in a
## basket, or asleep at bedtime; SlimeDetail.can_rest).
func _can_rest(s: int) -> bool:
	return SlimeDetail.can_rest(state[s])


## Whether the slime is a wall in the contacts: a sleeper, or resting.
func _is_wall(s: int) -> bool:
	return state[s] == STATE_SLEEPER or calm[s] == RESTING


## The one wake every path goes through (D156 (7)): wakes slime index `s`
## when it rests, only it: the rest of its pile rests on and keeps its
## `pile`; `s` leaves it (pile 0). An active slime starts its still count
## again; a parked one is left alone. A sleeper is never resting, so no wake
## changes it. Returns how many slimes woke (0 or 1).
# @spec-link [[req_offscreen_simulation]]
func _wake_at(s: int) -> int:
	var woken := 0
	if calm[s] == RESTING:
		calm[s] = ACTIVE
		pile[s] = 0
		woken = 1
	if calm[s] == ACTIVE:
		still_ticks[s] = 0
		rest_anchor[s] = centre[s]
	return woken


## Wakes the resting slimes (all but index `except`) whose ring may reach
## within `radius` of `point`, only those, not the rest of their piles
## (D156). Returns how many.
# @spec-link [[req_offscreen_simulation]]
func _wake_around(point: Vector2, radius: float, except: int) -> int:
	var woken := 0
	for s in slime_count:
		if s == except or calm[s] != RESTING:
			continue
		var reach := radius + bound_r[s] + TOUCH_SKIN
		if centre[s].distance_squared_to(point) < reach * reach:
			woken += _wake_at(s)
	return woken


## Gives slime index `s` a ring of `n` points read off its current shape
## (SlimeDetail.resample).
func _resample(s: int, n: int) -> void:
	SlimeDetail.resample(self, s, n)


## The mean of slime index `s`'s points: _centre_at() from the cache when its
## points haven't moved since it was last summed (so bit for bit the same).
func _centre_cached(s: int) -> Vector2:
	if _centre_ok[s] == 0:
		_centre_cache[s] = _centre_at(s)
		_centre_ok[s] = 1
	return _centre_cache[s]


## The mean of slime index `s`'s points, summed in point order.
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


## Automatic hops, `dt` seconds of them (SlimeHops.auto_hops: the timers,
## the take-offs, train_hopped; the native equivalence tests call this).
func _auto_hops(dt: float) -> void:
	SlimeHops.auto_hops(self, dt)


## Gives slime index `s` a fresh rest ring of `slime_size` centred at `at`,
## moving at `velocity`, replacing its point slice (SlimeDetail.reshape).
func _reshape(s: int, slime_size: int, at: Vector2, velocity: Vector2) -> void:
	SlimeDetail.reshape(self, s, slime_size, at, velocity)


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
	_centre_cache.remove_at(s)
	_centre_ok.remove_at(s)
	angle0.remove_at(s)
	_drift.remove_at(s)
	calm.remove_at(s)
	detail.remove_at(s)
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


# The GDScript solver passes, each run whole by SlimeSolverGD
# (src/sim/slime_solver.gd) over these bodies' arrays: tick() falls back to
# them pass by pass (_solve), and the native equivalence tests call them.

## Verlet step: gravity, air drag and internal damping, then each slime's
## centre and point-0 angle (SlimeSolverGD.integrate).
func _integrate(h: float) -> void:
	SlimeSolverGD.integrate(self, h)


## The slime-pair grid and the candidate pairs (SlimeSolverGD.build_pairs).
func _build_pairs() -> void:
	SlimeSolverGD.build_pairs(self)


## Ring against ring, with touching and support (SlimeSolverGD.solve_contacts).
func _solve_contacts() -> void:
	SlimeSolverGD.solve_contacts(self)


## Edge springs, area and shape matching, per ring (SlimeSolverGD.solve_rings).
func _solve_rings() -> void:
	SlimeSolverGD.solve_rings(self)


## Ring points against the terrain, then the shut doors
## (SlimeSolverGD.solve_terrain).
func _solve_terrain() -> void:
	SlimeSolverGD.solve_terrain(self)

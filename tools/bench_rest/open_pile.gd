extends RefCounted
## A bedtime pile on open ground (chunk 22, D107 measurements), for
## tools/bench_rest.gd and tests/e2e/test_bench_rest_e2e.gd. Not a fixture:
## the state is built from the test level as new, the way the stress
## fixtures are (tools/make_fixture.gd), and never saved.
##   the level:  gates 1 and 2 open (LevelStates, as after their baskets
##               fired), so the whole loop is in use and the camera's rails
##               reach every section;
##   the heap:   the whole population's bodies go; `count` size-1 free
##               slimes (the first `count` of the population, in stable ID
##               order, each its own species) are heaped around `at`, a
##               point in the air just above open ground (default: the
##               parade, section 2's flat stretch): in columns COLUMN_PITCH
##               px apart, stacked ROW_PITCH px apart from the ground up to
##               the first terrain above (a ledge's underside), the spots
##               nearest `at` first by STEEPNESS (a mound about 45° steep);
##   the seed:   `run_seed` seeds the simulation and, through its own stream,
##               how bedtime catches the heap: each slime is moved by up to
##               JITTER px and set moving at up to CAUGHT_SPEED px/s in any
##               direction (a crowd caught mid-hop);
##   bedtime:    as the session brings it (Session.jump to BEDTIME_MS on test
##               mode's default clocks, as make_fixture's session fixtures):
##               every free slime falls asleep for the night where it is;
##   the view:   the camera on the rails nearest `at`, off-screen simulation
##               on (as src/main.gd turns it on), the hint's world shown.
# @spec-link [[req_offscreen_simulation]]

const S := LevelData.SCREEN
## The parade (section 2, 9.0 to 10.0 screens, floor at y -18; two overhang
## ledges above it, undersides at y -214): the default heap point.
const PARADE := Vector2(9.5 * S, -60.0)
const COLUMN_PITCH := 50.0
const ROW_PITCH := 44.0
## How far each side of `at` columns are looked for, px.
const HALF_SPAN := 1.2 * S
## How far above the ground a column is looked at, at most, px.
const MAX_RISE := 600.0
## A spot's cost: its height over its ground times this, plus its distance
## from `at` along x. 1: a mound about 45° steep.
const STEEPNESS := 1.0
const JITTER := 6.0
const CAUGHT_SPEED := 120.0


## The pile built on `level` (with its baked `terrain`): {"sim": the
## Simulation at bedtime, "spots": the heap's spots used, "error": "" or why
## it couldn't be built (then "sim" is null)}.
static func build(level: Level, terrain: TerrainSegments, count: int, run_seed: int, at := PARADE) -> Dictionary:
	var sim := LevelStates.fresh_simulation(level.data, terrain, run_seed)
	var problems := LevelStates.open_gates(sim, level.data, LevelStates.gates_before(level.data, 3))
	if not problems.is_empty():
		return {"sim": null, "spots": [], "error": "; ".join(problems)}
	var population := _whole_population(sim, level.data)
	if population.size() < count:
		return {"sim": null, "spots": [], "error": "the level has %d slimes, %d asked" % [population.size(), count]}
	var spots := heap_spots(terrain, at, count)
	if spots.size() < count:
		return {"sim": null, "spots": [], "error": "room for %d slimes around %s, %d asked" % [spots.size(), at, count]}
	var rng := Rng.new(Rng.derive_seed(run_seed, "bench_rest.heap"))
	for k in count:
		var jitter := Vector2(rng.randf_range(-JITTER, JITTER), rng.randf_range(-JITTER, 0.0))
		var slime := sim.slimes.create(population[k][1], 1, spots[k] + jitter, SlimeBodies.FREE)
		sim.identities.assign(slime, PackedStringArray([population[k][0]]))
		var caught := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, CAUGHT_SPEED)
		sim.slimes.set_velocity(slime, caught)
	sim.session.read_clock(TestClock.default_reading())
	sim.session.start(sim)
	sim.session.jump(sim, Session.BEDTIME_MS)
	sim.session.save_due = false
	sim.camera.start(level.data.loop, sim.train.open_gates, at)
	sim.offscreen.enabled = true
	sim.hint.world_shown(sim.tick)
	return {"sim": sim, "spots": spots.slice(0, count), "error": ""}


## Room for `count` size-1 slimes heaped around `at` (see the class doc),
## cheapest first; fewer when the ground around `at` is short of room.
static func heap_spots(terrain: TerrainSegments, at: Vector2, count: int) -> Array:
	var reach := SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE
	var scored := []
	var x := at.x - floorf(HALF_SPAN / COLUMN_PITCH) * COLUMN_PITCH
	while x <= at.x + HALF_SPAN:
		var ground := _ground_below(terrain, Vector2(x, at.y))
		if not is_nan(ground):
			var ceiling := _ceiling_above(terrain, x, ground)
			var centre := ground - reach - 2.0
			while centre - reach >= ceiling + 2.0:
				scored.append([(ground - centre) * STEEPNESS + absf(x - at.x), Vector2(x, centre)])
				centre -= ROW_PITCH
		x += COLUMN_PITCH
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var spots := []
	for entry in scored.slice(0, count):
		spots.append(entry[1])
	return spots


## The top of the ground under `from` (the first terrain met going down), or
## NAN when `from` is inside the terrain or nothing is under it within
## MAX_RISE.
static func _ground_below(terrain: TerrainSegments, from: Vector2) -> float:
	if terrain.is_solid(from):
		return NAN
	var y := from.y
	while y < from.y + MAX_RISE:
		if terrain.resolve(Vector2(from.x, y))["hit"]:
			return y
		y += 2.0
	return NAN


## The underside of the first terrain above `ground` at `x`, or MAX_RISE
## above the ground when there is none that close.
static func _ceiling_above(terrain: TerrainSegments, x: float, ground: float) -> float:
	var y := ground - 4.0
	while y > ground - MAX_RISE:
		if terrain.resolve(Vector2(x, y))["hit"]:
			return y
		y -= 2.0
	return ground - MAX_RISE


## Every slime's body goes; returns [stable ID, species] for each, the first
## slime first, then the sleepers in stable ID order (as make_fixture's
## stress fixtures).
static func _whole_population(sim: Simulation, data: LevelData) -> Array:
	var first := str(data.first_slime["id"])
	var species_of := {}
	for slime_id in sim.slimes.ids():
		species_of[sim.identities.stable_id_of(slime_id)] = sim.slimes.species_of(slime_id)
		sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var ids := species_of.keys()
	ids.erase(first)
	ids.sort()
	ids.push_front(first)
	var out := []
	for id in ids:
		out.append([id, species_of[id]])
	return out

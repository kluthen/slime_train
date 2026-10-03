extends RefCounted
## The scenes of the native solver's equivalence harness (chunk 5N; not a
## test script: no test_ prefix). tests/unit/native_equivalence_support.gd
## hands out copies of them; see its doc. Each scene is a SlimeBodies at a
## tick boundary, built on the GDScript tick (whatever the run's tick, so a
## scene doesn't change as the native passes land), and built once per run
## (source() caches it; never change what it returns).
##
##   stress-moving     the test level's fixture (200 train slimes in section
##                     3's bowl), LEAD_IN ticks after loading: a moving crowd.
##   s3-basket-59of60  the fixture (59 slimes resting in basket 3, 141 train
##                     slimes in the bowl), LEAD_IN ticks after loading.
##   stress-still      the fixture once its pile (140 slimes asleep for the
##                     night) rests, AFTER_REST ticks later: resting walls.
##   gate2-open        the fixture LEAD_IN ticks after loading: shut doors
##                     (the trapdoors of the switches not flipped, gate 3).
##   synthetic         a small box (see _synthetic_rested()): detail-3 rings,
##                     walls (sleepers, a resting pile) with active slimes
##                     on them, parked slimes, an active slime at index 0
##                     pressed against another, one wedged in a pit, one on
##                     a shut door, a door far away and an empty one; at the
##                     last index, a free slime dropped onto the pile, the
##                     tick before it wakes a resting slime; and a slime
##                     with a point on a segment's end (a convex corner).
## Fixtures load as tools/bench_level.gd loads them (test mode's save, the
## camera where the fixture puts it, off-screen simulation on, the view
## following the camera), seed SEED.

const STRESS_MOVING := "stress-moving"
const S3_BASKET := "s3-basket-59of60"
const STRESS_STILL := "stress-still"
const GATE2_OPEN := "gate2-open"
const SYNTHETIC := "synthetic"
const NAMES: PackedStringArray = [STRESS_MOVING, S3_BASKET, STRESS_STILL, GATE2_OPEN, SYNTHETIC]
const SEED := 909
## Ticks run after loading a fixture (but stress-still).
const LEAD_IN := 120
## stress-still: the pile rests within this many ticks (about 410 since
## chunk 19; tests/e2e/test_fixtures_e2e.gd's bound), then AFTER_REST more.
const PILE_RESTS_WITHIN := 900
const AFTER_REST := 10
## synthetic: its pile rests within this many ticks, and the dropped slime
## wakes a resting one within DROP_WITHIN ticks.
const SYNTHETIC_RESTS_WITHIN := 1500
const DROP_WITHIN := 120
## synthetic: a pit in the floor, a slime wedged in it.
const PIT_LEFT := 200.0
const PIT_WIDTH := 30.0
const IN_PIT := 12
## synthetic: a convex corner of the floor (the V notch's right rim), and
## the slime moved onto it at the end (its lowest point CORNER_OFFSET from
## it, where the corner is the nearest terrain point: a segment's end).
const CORNER := Vector2(490, 0)
const CORNER_OFFSET := Vector2(-0.5, -2.5)
const ON_CORNER := 14
## synthetic: a slime held on the two sleepers, one held on the pile.
const ON_SLEEPERS := 15
const ON_PILE := 16
const PILE_REST := preload("res://tools/bench_level/pile_rest.gd")
const DT := 1.0 / Simulation.TICK_RATE

## The scenes built so far, by name.
static var _built := {}


## The scene `name` (see the class doc), built on first use; null, with an
## error, for an unknown name or a scene that doesn't build. Shared: copy it
## (native_equivalence_support.gd's clone()) before changing anything.
static func source(name: String) -> SlimeBodies:
	if not _built.has(name):
		if name not in NAMES:
			push_error("native_equivalence_scenes: no scene '%s' (the scenes: %s)" % [name, ", ".join(NAMES)])
			return null
		var bodies := _synthetic() if name == SYNTHETIC else _from_fixture(name)
		if bodies == null:
			return null
		_built[name] = bodies
	return _built[name]


# --- The fixtures -------------------------------------------------------------

## Fixture `fixture_name` of the test level, loaded as the bench loads it and
## run on (LEAD_IN ticks, or until stress-still's pile rests); its bodies.
static func _from_fixture(fixture_name: String) -> SlimeBodies:
	var level: Level = load(LevelCatalog.scene_path(LevelCatalog.DEFAULT_ID)).instantiate()
	var bodies := _load_and_run(level, fixture_name)
	level.free()
	return bodies


static func _load_and_run(level: Level, fixture_name: String) -> SlimeBodies:
	var problems := level.build()
	if not problems.is_empty():
		push_error("native_equivalence_scenes: the test level doesn't build: %s" % ", ".join(problems))
		return null
	var loaded := TestMode.load_fixture(fixture_name)
	if not loaded["ok"] or loaded["save"].is_empty():
		push_error("native_equivalence_scenes: fixture %s: %s" % [fixture_name, loaded["error"]])
		return null
	var sim := Simulation.from_save(loaded["save"], level.data, SlimeWorld.terrain_from(level), SEED)
	if sim == null:
		push_error("native_equivalence_scenes: fixture %s doesn't load on the test level" % fixture_name)
		return null
	# The GDScript tick, whatever the run's (see the class doc).
	sim.slimes.use_native(false)
	var camera: Variant = loaded["camera"]
	if camera is String:
		camera = level.point_of(camera)
	if camera != null:
		sim.camera.start(level.data.loop, sim.train.open_gates, camera)
	sim.offscreen.enabled = true
	sim.hint.world_shown(sim.tick)
	var step := func() -> void:
		sim.camera.apply_to(sim.view, ScreenView.DEFAULT_SIZE)
		sim.step()
	var ticks := LEAD_IN
	if fixture_name == STRESS_STILL:
		var rested := PILE_REST.ticks_to_rest(sim, PILE_REST.pile_of(sim), PILE_RESTS_WITHIN, step)
		if rested == PILE_REST.NEVER:
			push_error("native_equivalence_scenes: stress-still's pile doesn't rest within %d ticks"
					% PILE_RESTS_WITHIN)
			return null
		ticks = AFTER_REST
	for t in ticks:
		step.call()
	return sim.slimes


# --- The synthetic scene ------------------------------------------------------

## The synthetic scene (see the class doc): its pile at rest, the free slime
## dropped onto it and run on to the tick before it wakes a resting slime
## (built twice: once to find that tick, once to stop before it); then
## slime ON_CORNER moved onto CORNER. Points rarely stay on a convex corner
## (the push is away from it), hence the move.
static func _synthetic() -> SlimeBodies:
	var probe := _synthetic_rested()
	if probe == null:
		return null
	_drop(probe)
	var wakes_after := -1
	var resting := probe.calm.count(SlimeBodies.RESTING)
	for t in DROP_WITHIN:
		probe.tick(DT)
		if probe.calm.count(SlimeBodies.RESTING) < resting:
			wakes_after = t + 1
			break
	if wakes_after < 1:
		push_error("native_equivalence_scenes: the synthetic drop wakes no resting slime within %d ticks"
				% DROP_WITHIN)
		return null
	var bodies := _synthetic_rested()
	_drop(bodies)
	for t in wakes_after - 1:
		bodies.tick(DT)
	var s := ON_CORNER
	var lowest := bodies.first[s]
	for i in range(bodies.first[s], bodies.first[s] + bodies.npts[s]):
		if bodies.pos[i].y > bodies.pos[lowest].y:
			lowest = i
	bodies.translate(bodies.id[s], CORNER + CORNER_OFFSET - bodies.pos[lowest])
	return bodies


## The synthetic box, on the GDScript tick, run until its pile rests. A floor
## (top at y = 0) from x = -600 to 600 between two walls, with a pit
## PIT_WIDTH px wide and 60 deep at x = PIT_LEFT and a V notch 50 px deep
## at x = 350 to 490; a shut door, a slab on the floor at
## x = -200 to -100, 10 px high; a door far away (outside every slime's
## box) and an empty one. Slimes, by index (held: doesn't hop): 0 and 1 held
## train slimes pressed together in the notch (0 at detail 3); 2-7 the
## pile, in a basket, at the left wall (some at detail 3); 8 and 9 two
## sleepers side by side in mid-air; 10 parked inside the pile; 11 parked in
## the air; IN_PIT (12) held in the pit (detail 3); 13 held on the shut
## door; ON_CORNER (14) a held free slime, on the floor; ON_SLEEPERS (15) a held train slime on the
## sleepers; ON_PILE (16) one on the pile. Null, with an error, when the
## pile doesn't rest.
static func _synthetic_rested() -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(SEED))
	bodies.use_native(false)
	var pit_right := PIT_LEFT + PIT_WIDTH
	bodies.terrain = TerrainSegments.new([
		_box(-600, 0, PIT_LEFT, 300), _box(PIT_LEFT, 60, pit_right, 300),
		PackedVector2Array([Vector2(pit_right, 0), Vector2(350, 0), Vector2(420, 50), Vector2(490, 0),
				Vector2(600, 0), Vector2(600, 300), Vector2(pit_right, 300)]),
		_box(-700, -1000, -600, 300), _box(600, -1000, 700, 300),
	])
	bodies.doors.append(TerrainSegments.new([_box(-200, -10, -100, 0)]))
	bodies.doors.append(TerrainSegments.new([_box(1000, -600, 1100, -500)]))
	bodies.doors.append(TerrainSegments.new())
	bodies.set_detail(_held(bodies, SlimeBodies.TRAIN, 1, Vector2(400, -10)), SlimeBodies.MAX_DETAIL)
	_held(bodies, SlimeBodies.TRAIN, 1, Vector2(445, -10))
	var pile := PackedInt32Array()
	for spot in [[1, Vector2(-570, -21)], [2, Vector2(-520, -30)], [1, Vector2(-470, -21)],
			[3, Vector2(-420, -40)], [1, Vector2(-545, -80)], [2, Vector2(-490, -90)]]:
		pile.append(bodies.create(1, spot[0], spot[1], SlimeBodies.IN_BASKET))
	for k in [0, 3, 4]:
		bodies.set_detail(pile[k], SlimeBodies.MAX_DETAIL)
	bodies.create(2, 1, Vector2(280, -150), SlimeBodies.SLEEPER)
	bodies.create(2, 1, Vector2(320, -150), SlimeBodies.SLEEPER)
	bodies.park(bodies.create(3, 2, Vector2(-480, -60)))
	bodies.park(bodies.create(3, 1, Vector2(150, -100)))
	bodies.set_detail(_held(bodies, SlimeBodies.TRAIN, 2, Vector2(PIT_LEFT + PIT_WIDTH / 2, -30)),
			SlimeBodies.MAX_DETAIL)
	_held(bodies, SlimeBodies.TRAIN, 1, Vector2(-150, -31))
	_held(bodies, SlimeBodies.FREE, 1, Vector2(540, -21))
	_held(bodies, SlimeBodies.TRAIN, 1, Vector2(300, -200))
	_held(bodies, SlimeBodies.TRAIN, 1, Vector2(-480, -200))
	for t in SYNTHETIC_RESTS_WITHIN:
		bodies.tick(DT)
		if Array(pile).all(func(slime_id: int) -> bool: return bodies.calm_of(slime_id) == SlimeBodies.RESTING):
			return bodies
	push_error("native_equivalence_scenes: the synthetic pile doesn't rest within %d ticks" % SYNTHETIC_RESTS_WITHIN)
	return null


## Drops a size-2 free slime (the last index) onto the synthetic pile.
static func _drop(bodies: SlimeBodies) -> void:
	var slime_id := bodies.create(4, 2, Vector2(-500, -250), SlimeBodies.FREE)
	bodies.set_velocity(slime_id, Vector2(0, 300))


## A slime of `slime_state` and `slime_size` at `at` that doesn't hop; its id.
static func _held(bodies: SlimeBodies, slime_state: int, slime_size: int, at: Vector2) -> int:
	var slime_id := bodies.create(0, slime_size, at, slime_state)
	bodies.set_hop_held(slime_id, true)
	return slime_id


## The rectangle from (x0, y0) to (x1, y1), as a terrain outline.
static func _box(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

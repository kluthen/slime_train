extends GutTest
## A free slime heading straight for the loop (in no exploration branch)
## gets off the spots where the test level's rule 7 checks found it stuck
## (chunk 16d): a hollow with 20 px lips, like the dip hollows, and a thin
## ledge whose high end faces another one across a 104 px gap, like the
## hills' bumps. Both were the terrain's fault, not the slime's aim: ring
## points passing just outside a sharp convex corner counted as inside the
## terrain and were pulled onto the corner (TerrainSegments' vertex normals,
## test_terrain_segments.gd), which threw the slime back into the hollow, or
## against the ledge's end until its ring wrapped round the 25 px slab.
## Through the Simulation, like test_call.gd.
##
## The synthetic world: a floor whose top is at y = 0 from x = -2000 to 2000;
## the loop runs along it at a base slime's centre height (y = -24) from
## x = -1500 to 1500 and returns under the floor. No exploration branch.

# @test-link [[rule_gravity_leads_back_to_loop]]
# @test-link [[req_call_mechanic]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const SEEDS := [11, 12, 13]
## A size-1 slime's centre rests this far above the ground, px.
const RIDE := 24.0
## The hills around the test level's bumps 2 and 3 (x shifted by -1862
## px): the ground's top, and two thin ledges 104 px apart over it, the
## left one rising toward the gap, the right one falling away from it.
const HILLS := [Vector2(-2000, 20), Vector2(-364, 20), Vector2(-192, 40), Vector2(-19, 0),
		Vector2(154, 30), Vector2(327, -10), Vector2(2000, -10)]


func _level() -> LevelData:
	var data := LevelData.new("heading-back", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	return data


## A simulation of the synthetic world with `pieces` (outlines) floating
## over the floor.
func _sim(master_seed: int, pieces: Array) -> Simulation:
	var sim := Simulation.new(master_seed)
	var polygons: Array = [Support.floor_polygon()]
	polygons.append_array(pieces)
	sim.slimes.terrain = TerrainSegments.new(polygons)
	sim.load_level(_level())
	sim.view.set_to(Vector2(0, -200), 1.0, ScreenView.DEFAULT_SIZE)
	return sim


## A floating hollow like the test level's dip hollows: a floor at y = -150
## from `x0` + 23 to `x1` - 23, lips 20 px high at both ends, 20 px thick
## under the floor.
static func _hollow(x0: float, x1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, -170), Vector2(x0 + 23, -150), Vector2(x1 - 23, -150),
			Vector2(x1, -170), Vector2(x1, -130), Vector2(x0, -130)])


## A 25 px thick ledge from `x0` to `x1` whose top runs from y `y0` to `y1`,
## like the test level's hill bumps.
static func _slab(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1), Vector2(x1, y1 + 25), Vector2(x0, y0 + 25)])


## Makes a free slime (heading back: nobody called it) centred at `at`, and
## runs until it rejoins the train or `seconds` pass. Returns the ticks it
## took, or -1.
func _way_back_ticks(sim: Simulation, at: Vector2, seconds: int) -> int:
	var slime := sim.slimes.create(0, 1, at, SlimeBodies.FREE)
	for tick in seconds * Simulation.TICK_RATE:
		sim.step()
		if sim.slimes.state_of(slime) == SlimeBodies.TRAIN:
			return tick + 1
	gut.p("still free at %s" % sim.slimes.centre_of(slime).round())
	return -1


func test_a_slime_in_a_hollow_with_lips_gets_out_and_back() -> void:
	# The loop is right below: it hops 60 px along, 34 px high, over the
	# lip's corner (it used to be pulled back onto the corner and slide back
	# in).
	for master_seed in SEEDS:
		for x in [-60.0, 60.0]:
			var sim := _sim(master_seed, [_hollow(-92, 92)])
			var ticks := _way_back_ticks(sim, Vector2(x, -150 - RIDE), 30)
			assert_gt(ticks, 0, "seed %d, from x %d: out of the hollow and back within 30 s" % [master_seed, x])


## The hills' world: the ground, the two ledges, and the loop RIDE px above
## the ground.
func _hills_sim(master_seed: int) -> Simulation:
	var ground := PackedVector2Array(HILLS)
	ground.append_array([Vector2(2000, 300), Vector2(-2000, 300)])
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = TerrainSegments.new([ground, _slab(-284, -100, -158, -182),
			_slab(4, 188, -182, -158)])
	var data := LevelData.new("hills", 1)
	var route := PackedVector2Array()
	for point: Vector2 in HILLS:
		route.append(Vector2(clampf(point.x, -1500, 1500), point.y - RIDE))
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, route)
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			route[route.size() - 1], Vector2(1500, 400), Vector2(-1500, 400), route[0]]), "t.gate")
	data.loop = loop
	sim.load_level(data)
	sim.view.set_to(Vector2(0, -200), 1.0, ScreenView.DEFAULT_SIZE)
	return sim


func test_a_slime_off_a_ledges_high_end_clears_the_next_ledge() -> void:
	# Off the left ledge's high end it hops for the loop's nearest point,
	# down in the gap, past the right ledge's top corner (it used to be
	# pulled onto that corner, thrown back, and wrapped round the left
	# ledge's end).
	for master_seed in [3, 4, 5, 6, 909]:  # each stuck from one start or both before chunk 16d
		for x in [-230.0, -150.0]:
			var sim := _hills_sim(master_seed)
			var y := lerpf(-158, -182, (x + 284) / 184.0) - RIDE
			var ticks := _way_back_ticks(sim, Vector2(x, y), 30)
			assert_gt(ticks, 0, "seed %d, from x %d: off the ledges and back within 30 s" % [master_seed, x])

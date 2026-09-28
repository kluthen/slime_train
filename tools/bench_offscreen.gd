extends SceneTree
## Tick cost of the chunk 15 fallbacks, headless. Not a test: it records the
## numbers in docs/dev/README.md ("Off-screen simulation (chunk 15)").
##
## Run:   godot --headless -s res://tools/bench_offscreen.gd [-- --ticks=600]
##
## Cases, each timed over `ticks` ticks after SETTLE_TICKS untimed:
##   pile      the realistic worst case (D96): a full basket (60 base slimes,
##             basket 3's quota, IN_BASKET, piled in a pit 460 px wide and
##             PIT_DEPTH deep, so the pile stays below the floor) and
##             the train beside it (20 base train slimes hopping on the
##             floor away from it), about two screens wide. SlimeBodies.tick
##             only.
##               rest=off  every slime simulated (the resting-pile rule off)
##               rest=on   the resting-pile rule on (chunk 15)
##               low=on    the same, rings at the zoomed-out point counts
##   level     the whole Simulation.step on the test level: the first slime
##             and `spread` (40) base train slimes spread along the loop, the
##             camera on the start, no input.
##               offscreen=off  every slime simulated
##               offscreen=on   physics only near the view (chunk 15)
## The rest=on / low=on / offscreen=on cases only run when the code has
## them (the same script measured the code before chunk 15).
# @spec-link [[req_platform_and_performance_targets]]

const TICK := 1.0 / 60.0
const SETTLE_TICKS := 600
const LEVEL_SCENE := "res://levels/test/level.tscn"
const PIT_HALF_WIDTH := 230.0
const FLOOR_HALF_WIDTH := 1000.0
const PIT_DEPTH := 400.0
## SlimeBodies.RESTING and PARKED (chunk 15), as numbers: the script also
## runs on the code from before them.
const RESTING := 1
const PARKED := 2

var ticks := 600
var spread := 40


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		match parts[0]:
			"ticks":
				ticks = int(parts[1])
			"spread":
				spread = int(parts[1])
	var probe := SlimeBodies.new(Rng.new(1))
	var has_rest := "rest_enabled" in probe
	_pile(false, false)
	if has_rest:
		_pile(true, false)
		_pile(true, true)
	_level(false)
	if "offscreen" in Simulation.new(1):
		_level(true)
	quit()


func _pile(rest: bool, low: bool) -> void:
	var rng := Rng.new(20260928)
	var bodies := SlimeBodies.new(rng)
	if "rest_enabled" in bodies:
		bodies.set("rest_enabled", rest)
	bodies.terrain = TerrainSegments.new(_pit())
	var d := 2.0 * (SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE) + 2.0
	# The basket: 60 base slimes shelf-packed in the pit, falling into a pile.
	var per_row := int((2.0 * PIT_HALF_WIDTH - 8.0) / d)
	for i in 60:
		var at := Vector2(-PIT_HALF_WIDTH + 4.0 + d * (0.5 + i % per_row), PIT_DEPTH - d * (0.5 + i / per_row))
		bodies.create(i % Species.COUNT, 1, at, SlimeBodies.IN_BASKET)
	# The train: 20 base slimes on the floor either side of the pit.
	for i in 20:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (PIT_HALF_WIDTH + 150.0 + d * (i / 2))
		var slime := bodies.create(i % Species.COUNT, 1, Vector2(x, -d * 0.5), SlimeBodies.TRAIN)
		# Hopping away from the pit: beside the basket, not on its pile.
		bodies.set_heading(slime, side)
	if low:
		for slime_id in bodies.ids():
			bodies.call("set_low_detail", slime_id, true)
	for t in SETTLE_TICKS:
		bodies.tick(TICK)
	var start := Time.get_ticks_usec()
	var hops := 0
	for t in ticks:
		bodies.tick(TICK)
		hops += bodies.hopped.size()
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / ticks
	var resting := 0
	if "rest_enabled" in bodies:
		var calm: PackedByteArray = bodies.get("calm")
		for s in bodies.slime_count:
			resting += 1 if calm[s] == RESTING else 0
	print("RESULT case=pile rest=%s low=%s slimes=%d points=%d ticks=%d ms_per_tick=%.3f hops=%d resting=%d" % [
		"on" if rest else "off", "on" if low else "off", bodies.slime_count, bodies.pos.size(), ticks, ms,
		hops, resting])


func _level(offscreen: bool) -> void:
	var level: Level = load(LEVEL_SCENE).instantiate()
	level.build()
	var sim := Simulation.new(909)
	sim.slimes.terrain = SlimeWorld.terrain_from(level)
	sim.load_level(level.data)
	if "offscreen" in sim:
		sim.get("offscreen").set("enabled", offscreen)
	var length := sim.train.length()
	for i in spread:
		sim.spawn_train_slime(i % 3, 1, length * (i + 0.5) / spread)
	for t in SETTLE_TICKS:
		_step(sim)
	var start := Time.get_ticks_usec()
	for t in ticks:
		_step(sim)
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / ticks
	var parked := 0
	if "rest_enabled" in sim.slimes:
		var calm: PackedByteArray = sim.slimes.get("calm")
		for s in sim.slimes.slime_count:
			parked += 1 if calm[s] == PARKED else 0
	print("RESULT case=level offscreen=%s slimes=%d ticks=%d ms_per_tick=%.3f parked=%d" % [
		"on" if offscreen else "off", sim.slimes.slime_count, ticks, ms, parked])
	level.free()


## One tick as the game runs it: the view follows the camera first.
func _step(sim: Simulation) -> void:
	sim.camera.apply_to(sim.view, ScreenView.DEFAULT_SIZE)
	sim.step()


## A floor 2000 px wide with a pit 460 px wide and PIT_DEPTH deep in its middle,
## walled at both ends.
func _pit() -> Array:
	var w := FLOOR_HALF_WIDTH
	var p := PIT_HALF_WIDTH
	return [
		PackedVector2Array([Vector2(-w - 100, 0), Vector2(-p, 0), Vector2(-p, PIT_DEPTH), Vector2(p, PIT_DEPTH),
				Vector2(p, 0), Vector2(w + 100, 0), Vector2(w + 100, PIT_DEPTH + 100), Vector2(-w - 100, PIT_DEPTH + 100)]),
		PackedVector2Array([Vector2(-w - 100, -3000), Vector2(-w, -3000), Vector2(-w, 10), Vector2(-w - 100, 10)]),
		PackedVector2Array([Vector2(w, -3000), Vector2(w + 100, -3000), Vector2(w + 100, 10), Vector2(w, 10)]),
	]

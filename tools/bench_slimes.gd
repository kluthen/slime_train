extends SceneTree
## Tick cost of the slime bodies (SlimeBodies.tick), headless. Not a test:
## it records a number for docs/dev/README.md ("Slimes").
##
## Run:   godot --headless -s res://tools/bench_slimes.gd [-- --count=200 --ticks=600]
## For each case: `count` slimes dropped as a pile into a box 1152 px wide,
## settled for 180 ticks (untimed), then `ticks` ticks timed.
##   still   every slime bedtime-asleep (simulated, no hops): a resting pile
##   moving  every slime a train slime hopping on its own timer, heading
##           left, right or in place
## Sizes: "size1" all size 1 (12 points); "mix" 60 % size 1, 25 % size 2,
## 15 % size 3 (the soft-slimes spike's mix, 12/15/18 points).

const TICK := 1.0 / 60.0
const HALF_WIDTH := 576.0
const SETTLE_TICKS := 180

var count := 200
var ticks := 600


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		match parts[0]:
			"count":
				count = int(parts[1])
			"ticks":
				ticks = int(parts[1])
	for sizes in ["size1", "mix"]:
		for mode in ["still", "moving"]:
			_run(sizes, mode)
	quit()


func _run(sizes: String, mode: String) -> void:
	var rng := Rng.new(20260928)
	var bodies := SlimeBodies.new(rng)
	bodies.terrain = TerrainSegments.new(_box())
	var state := SlimeBodies.BEDTIME_ASLEEP if mode == "still" else SlimeBodies.TRAIN
	# Shelf-pack from the floor up; the upper rows fall into the pile.
	var x := -HALF_WIDTH + 4.0
	var y := 0.0
	var row := 0.0
	for i in count:
		var size := 1
		if sizes == "mix":
			var r := i % 20
			size = 1 if r < 12 else (2 if r < 17 else 3)
		var d := 2.0 * (SlimeBodies.ring_radius_for(size) + SlimeBodies.EDGE) + 2.0
		if x + d > HALF_WIDTH - 4.0:
			x = -HALF_WIDTH + 4.0
			y -= row
			row = 0.0
		var slime := bodies.create(i % Species.COUNT, size, Vector2(x + d * 0.5, y - d * 0.5), state)
		bodies.set_heading(slime, float(rng.randi_range(-1, 1)))
		x += d
		row = maxf(row, d)
	for t in SETTLE_TICKS:
		bodies.tick(TICK)
	var start := Time.get_ticks_usec()
	var hops := 0
	for t in ticks:
		bodies.tick(TICK)
		hops += bodies.hopped.size()
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / ticks
	print("RESULT sizes=%s mode=%s slimes=%d points=%d ticks=%d ms_per_tick=%.3f hops=%d" % [
		sizes, mode, bodies.slime_count, bodies.pos.size(), ticks, ms, hops])


func _box() -> Array:
	return [
		PackedVector2Array([Vector2(-HALF_WIDTH - 100, 0), Vector2(HALF_WIDTH + 100, 0),
				Vector2(HALF_WIDTH + 100, 300), Vector2(-HALF_WIDTH - 100, 300)]),
		PackedVector2Array([Vector2(-HALF_WIDTH - 100, -3000), Vector2(-HALF_WIDTH, -3000),
				Vector2(-HALF_WIDTH, 10), Vector2(-HALF_WIDTH - 100, 10)]),
		PackedVector2Array([Vector2(HALF_WIDTH, -3000), Vector2(HALF_WIDTH + 100, -3000),
				Vector2(HALF_WIDTH + 100, 10), Vector2(HALF_WIDTH, 10)]),
	]

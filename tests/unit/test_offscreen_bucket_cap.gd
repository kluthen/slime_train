extends GutTest
## The bucket cap off screen (chunk 22i, D151 (5): Offscreen._train_proxy).
## With Train.bucket_cap on, a parked train slime's advance stops just short
## of its loop bucket's front edge while the next bucket has no room for it,
## as it stops behind the slime ahead (single file), and goes on once there
## is room. Off, it doesn't stop there. A parked slime carried on a slide is
## never stopped by the cap (D151 (5)).
##
## The world (as tests/unit/test_offscreen_single_file.gd's): a floor whose
## top is at y = 0 from x = -6000 to 6000; the loop runs along it at a base
## slime's centre height from x = -5000 to 5000 and returns under the floor.
## The view is far above the level: every slime is parked. The cap's density
## is 1 per 100 px: a 300 px bucket's cap is 3 (bucket 1 holds d 300 to 600,
## bucket 2 d 600 to 900). The return route, a slide, starts at d 10000;
## bucket 35 (d 10500 to 10800) is on it.
# @test-link [[req_offscreen_simulation]]

## Far above the level: nothing comes near the view.
const AWAY := Vector2(0, -5000)
const DENSITY := 1.0
const EDGE := 600.0
## Bucket 35's back edge (bucket 34's front edge), on the slide.
const SLIDE_EDGE := 10500.0


func _level() -> LevelData:
	var data := LevelData.new("offscreen-bucket-cap", 1)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-5000, -24), Vector2(5000, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(5000, -24), Vector2(5000, 400), Vector2(-5000, 400), Vector2(-5000, -24)]))
	data.loop = loop
	data.first_slime = {"id": "t.first-slime", "species": "A", "position": Vector2(-4900, -24)}
	return data


func _terrain() -> TerrainSegments:
	return TerrainSegments.new([
		PackedVector2Array([Vector2(-6000, 0), Vector2(6000, 0), Vector2(6000, 300), Vector2(-6000, 300)])])


## A simulation on the level, off-screen simulation on, the view away, the
## bucket cap switched `on` (the first slime is removed: tests place their own).
func _sim(on: bool) -> Simulation:
	var sim := Simulation.new(5)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	for slime_id in sim.slimes.ids():
		sim.slimes.remove(slime_id)
	sim.offscreen.enabled = true
	sim.view.set_to(AWAY, 1.0, ScreenView.DEFAULT_SIZE)
	sim.train.bucket_cap = on
	sim.train.bucket_cap_density = DENSITY
	return sim


## A parked base slime 10 px before bucket 1's front edge, a parked size 3
## 100 px past it (bucket 2 full), run until the size 3 has left bucket 2
## and 60 ticks more: [the base slime's furthest distance while the size 3
## was in bucket 2 at the tick's start, its distance at the end, whether the
## size 3 left bucket 2].
func _run(on: bool) -> Array:
	var sim := _sim(on)
	var slime := sim.spawn_train_slime(0, 1, EDGE - 10.0)
	var full := sim.spawn_train_slime(1, 3, EDGE + 100.0)
	var furthest := 0.0
	var left := false
	for i in 600:
		var full_ahead := sim.train.distance_of(full) < 900.0
		sim.run(1)
		assert_true(sim.slimes.is_parked(slime), "parked")
		if full_ahead:
			furthest = maxf(furthest, sim.train.distance_of(slime))
		elif not left:
			left = true
			sim.run(60)
			break
	return [furthest, sim.train.distance_of(slime), left]


func test_a_parked_slime_stops_at_a_full_buckets_front_edge_and_goes_on_once_there_is_room() -> void:
	var run := _run(true)
	assert_true(run[2], "the size 3 left bucket 2")
	assert_lt(run[0], EDGE, "it never entered the full bucket")
	assert_gt(run[0], EDGE - 0.5, "it stopped just short of the front edge")
	assert_gt(run[1], EDGE + 10.0, "room ahead: it went on")


func test_with_the_cap_off_a_parked_slime_goes_into_a_full_bucket() -> void:
	var run := _run(false)
	assert_gt(run[0], EDGE, "only single file stops it")


func test_a_parked_slime_on_a_slide_passes_a_full_buckets_front_edge() -> void:
	var sim := _sim(true)
	var slime := sim.spawn_train_slime(0, 1, SLIDE_EDGE - 10.0)
	var full := sim.spawn_train_slime(1, 3, SLIDE_EDGE + 250.0)
	assert_true(sim.train.is_slide_at(SLIDE_EDGE - 10.0), "on the slide")
	var furthest := 0.0
	for i in 60:
		if sim.train.distance_of(full) >= SLIDE_EDGE + 300.0:
			break
		sim.run(1)
		assert_true(sim.slimes.is_parked(slime), "parked")
		furthest = maxf(furthest, sim.train.distance_of(slime))
	assert_gt(furthest, SLIDE_EDGE, "carried on the slide into the full bucket")

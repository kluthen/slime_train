extends GutTest
## SlimeBodies' centre cache (chunk 22 performance pass): centre_of() keeps
## each slime's centre until its points move, and must always return exactly
## (bit for bit) the mean of its current points, whatever moved them.
# @test-link [[req_slime_states]]
# @test-link [[req_offscreen_simulation]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0


## Three slimes (a size 2 and two base ones) falling onto a floor.
func _bodies() -> SlimeBodies:
	var bodies := Support.bodies_on_floor(5)
	bodies.create(0, 2, Vector2(0, -60))
	bodies.create(0, 1, Vector2(90, -40))
	bodies.create(1, 1, Vector2(-90, -40))
	return bodies


## Reads every centre through the cache (so it is filled).
func _warm(bodies: SlimeBodies) -> void:
	for slime_id in bodies.ids():
		bodies.centre_of(slime_id)


## The mean of the slime's current points, summed like _centre_at.
func _mean(bodies: SlimeBodies, slime_id: int) -> Vector2:
	var points := bodies.points_of(slime_id)
	var c := Vector2.ZERO
	for p in points:
		c += p
	return c / points.size()


## Asserts every cached centre equals the mean of the current points exactly.
func _assert_fresh(bodies: SlimeBodies, after: String) -> void:
	for slime_id in bodies.ids():
		assert_eq(bodies.centre_of(slime_id), _mean(bodies, slime_id),
				"slime %d's centre after %s" % [slime_id, after])


func test_a_tick_refreshes_every_centre() -> void:
	var bodies := _bodies()
	for t in 5:
		_warm(bodies)
		bodies.tick(DT)
		_assert_fresh(bodies, "tick %d" % t)


func test_translate_refreshes_the_moved_slime() -> void:
	var bodies := _bodies()
	bodies.tick(DT)
	_warm(bodies)
	bodies.translate(bodies.ids()[1], Vector2(13.25, -7.5))
	_assert_fresh(bodies, "translate")


func test_set_body_refreshes_the_slime() -> void:
	var bodies := _bodies()
	bodies.tick(DT)
	var slime_id := bodies.ids()[0]
	var body := bodies.body_of(slime_id)
	bodies.translate(slime_id, Vector2(40, 0))
	_warm(bodies)
	assert_true(bodies.set_body(slime_id, body))
	_assert_fresh(bodies, "set_body")


## A body at another detail level: set_body resamples the ring, then writes it.
func test_set_body_at_another_detail_refreshes_the_slime() -> void:
	var bodies := _bodies()
	bodies.tick(DT)
	var slime_id := bodies.ids()[0]
	var body := bodies.body_of(slime_id)
	assert_true(bodies.set_detail(slime_id, SlimeBodies.MAX_DETAIL))
	bodies.translate(slime_id, Vector2(40, 0))
	_warm(bodies)
	assert_true(bodies.set_body(slime_id, body))
	assert_eq(bodies.detail_of(slime_id), 0)
	_assert_fresh(bodies, "set_body at another detail")


func test_a_change_of_detail_refreshes_the_slime() -> void:
	var bodies := _bodies()
	bodies.tick(DT)
	_warm(bodies)
	assert_true(bodies.set_detail(bodies.ids()[0], SlimeBodies.LOW_DETAIL))
	_assert_fresh(bodies, "set_detail")
	_warm(bodies)
	assert_gt(bodies.set_active_detail(SlimeBodies.MAX_DETAIL), 0)
	_assert_fresh(bodies, "set_active_detail up")
	_warm(bodies)
	assert_gt(bodies.set_active_detail(0), 0)
	_assert_fresh(bodies, "set_active_detail back")


func test_merge_and_split_refresh_the_slimes() -> void:
	var bodies := _bodies()
	bodies.tick(DT)
	var ids := bodies.ids()
	_warm(bodies)
	var fused := bodies.merge(ids[0], ids[1])
	assert_eq(fused, ids[0])
	_assert_fresh(bodies, "merge")
	_warm(bodies)
	assert_eq(bodies.split(fused).size(), 3)
	_assert_fresh(bodies, "split")


func test_create_and_remove_keep_the_cache_in_line_with_the_indices() -> void:
	var bodies := _bodies()
	bodies.tick(DT)
	_warm(bodies)
	bodies.create(2, 1, Vector2(200, -40))
	_assert_fresh(bodies, "create")
	_warm(bodies)
	assert_true(bodies.remove(bodies.ids()[0]))
	_assert_fresh(bodies, "remove")
	_warm(bodies)
	var loaded := bodies.next_id + 3
	assert_eq(bodies.create_with_id(loaded, 1, 1, Vector2(-200, -40)), loaded)
	_assert_fresh(bodies, "create_with_id")
	assert_eq(Support.layout_problems(bodies), PackedStringArray())


func test_park_and_unpark_leave_the_centre_right() -> void:
	var bodies := _bodies()
	bodies.tick(DT)
	var slime_id := bodies.ids()[2]
	_warm(bodies)
	bodies.park(slime_id)
	bodies.translate(slime_id, Vector2(-30, 5))
	_assert_fresh(bodies, "park and translate")
	_warm(bodies)
	bodies.unpark(slime_id)
	bodies.tick(DT)
	_assert_fresh(bodies, "unpark and tick")

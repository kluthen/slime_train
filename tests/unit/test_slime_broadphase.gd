extends GutTest
## The shortcuts of SlimeBodies' tick that skip work (chunk 22 performance
## pass) and must not change what happens: the slime pairs, where a wall (a
## sleeper, or resting) is still paired with the moving slimes whatever their
## order, and the shut doors, which still push a slime whose centre is
## outside a door's grid when some of its points are in it, or which an
## earlier door pushed.
# @test-link [[req_waking_sleepers]]
# @test-link [[req_switch_basket_gate_set]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0


func _run(bodies: SlimeBodies, ticks: int) -> void:
	for i in ticks:
		bodies.tick(DT)


## A thin door from x = `left` to `right`, its top at y = 0 (thicker than
## 2 x MARGIN, as terrain pieces must be).
func _door(left: float, right: float) -> TerrainSegments:
	return TerrainSegments.new([PackedVector2Array([
			Vector2(left, 0), Vector2(right, 0), Vector2(right, 40), Vector2(left, 40)])])


## Bodies with the given doors, over no terrain or over a floor far below.
func _bodies_with_doors(door_list: Array[TerrainSegments], with_floor: bool) -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(3))
	if with_floor:
		bodies.terrain = TerrainSegments.new([PackedVector2Array([
				Vector2(-2000, 600), Vector2(2000, 600), Vector2(2000, 900), Vector2(-2000, 900)])])
	bodies.doors = door_list
	bodies.auto_hops = false
	return bodies


func test_walls_are_paired_with_the_moving_slimes_before_and_after_them() -> void:
	# In index order; neighbours overlap by 2 px. The last two sleepers come
	# after the last moving slime.
	var states := [SlimeBodies.SLEEPER, SlimeBodies.TRAIN, SlimeBodies.SLEEPER, SlimeBodies.SLEEPER,
			SlimeBodies.TRAIN, SlimeBodies.SLEEPER, SlimeBodies.SLEEPER]
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var ids := []
	for i in states.size():
		ids.append(bodies.create(i % Species.COUNT, 1, Vector2(40.0 * i, -24), states[i]))
	_run(bodies, 1)
	assert_eq(bodies.touching_pairs(), [Vector2i(ids[0], ids[1]), Vector2i(ids[1], ids[2]),
			Vector2i(ids[3], ids[4]), Vector2i(ids[4], ids[5])],
			"every wall touching a moving slime, in pair order; never two walls")


func test_walls_alone_are_never_paired() -> void:
	var bodies := Support.bodies_on_floor()
	for i in 4:
		bodies.create(i % Species.COUNT, 1, Vector2(40.0 * i, -24), SlimeBodies.SLEEPER)
	_run(bodies, 1)
	assert_eq(bodies.touching_pairs(), [])


func test_a_big_slime_whose_centre_is_above_a_doors_grid_rests_on_it() -> void:
	for with_floor in [false, true]:
		var door := _door(-100, 100)
		var bodies := _bodies_with_doors([door], with_floor)
		var slime := bodies.create(0, 3, Vector2(0, -60), SlimeBodies.BEDTIME_ASLEEP)
		_run(bodies, 120)
		var centre := bodies.centre_of(slime)
		assert_lt(centre.y, door.origin.y, "floor %s: the centre is outside the door's grid" % with_floor)
		assert_between(centre.y, -bodies.radius_of(slime) * 1.3, 0.0, "floor %s: it rests on the door" % with_floor)


func test_a_slime_across_two_doors_side_by_side_rests_on_both() -> void:
	for with_floor in [false, true]:
		var bodies := _bodies_with_doors([_door(-200, 0), _door(0, 200)], with_floor)
		var slime := bodies.create(0, 3, Vector2(0, -60), SlimeBodies.BEDTIME_ASLEEP)
		_run(bodies, 120)
		var centre := bodies.centre_of(slime)
		assert_between(centre.y, -bodies.radius_of(slime) * 1.3, 0.0, "floor %s: held up" % with_floor)
		assert_almost_eq(centre.x, 0.0, bodies.radius_of(slime) * 0.5, "floor %s: still across both" % with_floor)
		for p in bodies.points_of(slime):
			assert_lt(p.y, 1.0, "floor %s: no point sinks into either door" % with_floor)

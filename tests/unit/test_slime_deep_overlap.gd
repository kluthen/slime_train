extends GutTest
## Two rings deep inside each other come apart (O91, the slime gobbled by
## another): SlimeBodies._solve_contacts pushes a point of one ring that went
## past the other's centre back out on its own side. Pushed straight out from
## the other's centre, it drew the two together until their centres met, and
## there nothing pushed any more: a slime stayed inside another (different
## species, or sizes that can't fuse) for good. Bedtime-asleep slimes (they
## simulate, never hop), rest off, on whichever tick the run uses (a test_slime_
## script: tools/test.sh runs it on both).
# @test-link [[req_slime_states]]
# @test-link [[rule_contact_pushes_slimes_apart]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0
## The size pairs tried: [the one put inside, the other].
const SIZES: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]
## How deep: the centres this share of the smaller ring radius apart.
const DEPTHS: Array[float] = [0.1, 0.4, 0.7, 0.95]


## Two slimes of other species, the first `offset` from the second's centre,
## both at detail level `detail`; no gravity and no terrain unless
## `on_floor` (then the floor of slime_test_support.gd and gravity).
func _pair(sizes: Vector2i, offset: Vector2, detail: int, on_floor := false) -> SlimeBodies:
	var bodies := Support.bodies_on_floor() if on_floor else SlimeBodies.new(Rng.new(1))
	if not on_floor:
		bodies.gravity = Vector2.ZERO
	bodies.rest_enabled = false
	var at := Vector2(0, -SlimeBodies.ring_radius_for(sizes.y) - 4.0) if on_floor else Vector2.ZERO
	var big := bodies.create(1, sizes.y, at, SlimeBodies.BEDTIME_ASLEEP)
	var small := bodies.create(0, sizes.x, at + offset, SlimeBodies.BEDTIME_ASLEEP)
	bodies.set_detail(big, detail)
	bodies.set_detail(small, detail)
	return bodies


func _gap(bodies: SlimeBodies) -> float:
	var ids := bodies.ids()
	return bodies.centre_of(ids[0]).distance_to(bodies.centre_of(ids[1]))


func test_two_rings_deep_inside_each_other_come_apart() -> void:
	for detail in [0, SlimeBodies.MAX_DETAIL]:
		for sizes in SIZES:
			var radius := minf(SlimeBodies.ring_radius_for(sizes.x), SlimeBodies.ring_radius_for(sizes.y))
			var reach := SlimeBodies.ring_radius_for(sizes.x) + SlimeBodies.ring_radius_for(sizes.y)
			for depth in DEPTHS:
				var bodies := _pair(sizes, Vector2(depth * radius, 0.25), detail)
				var label := "sizes %s, detail %d, %.2f of a radius apart" % [sizes, detail, depth]
				var before := _gap(bodies)
				for i in 30:
					bodies.tick(DT)
				gut.p("%s: %.1f -> %.1f px" % [label, before, _gap(bodies)])
				assert_gt(_gap(bodies), reach, "%s: the rings parted" % label)


func test_a_slime_put_inside_a_bigger_one_on_the_floor_gets_out() -> void:
	for detail in [0, SlimeBodies.MAX_DETAIL]:
		for sizes in [Vector2i(1, 3), Vector2i(1, 2), Vector2i(2, 3)]:
			var bodies := _pair(sizes, Vector2(3.0, -2.0), detail, true)
			for i in 240:
				bodies.tick(DT)
			var ids := bodies.ids()
			var label := "sizes %s, detail %d" % [sizes, detail]
			var small_centre := bodies.centre_of(ids[1])
			gut.p("%s: centres %.1f px apart" % [label, _gap(bodies)])
			assert_false(Geometry2D.is_point_in_polygon(small_centre, bodies.points_of(ids[0])),
					"%s: the smaller slime's centre is out of the bigger one" % label)
			var reach := SlimeBodies.ring_radius_for(sizes.x) + SlimeBodies.ring_radius_for(sizes.y)
			assert_gt(_gap(bodies), reach * 0.7, "%s: side by side, not one inside the other" % label)

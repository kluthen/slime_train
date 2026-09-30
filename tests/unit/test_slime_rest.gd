extends GutTest
## The cheaper states of SlimeBodies (chunk 15, D96): the resting-pile rule
## (a settled pile stops simulating, contacts included, until something
## disturbs it), parked slimes (off screen: not simulated, not touched) and
## the zoomed-out ring point counts.
# @test-link [[req_offscreen_simulation]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0
const BOX_HALF_WIDTH := 130.0


func _run(bodies: SlimeBodies, ticks: int) -> void:
	for i in ticks:
		bodies.tick(DT)


## `count` base slimes in `slime_state`, shelf-packed in a box, falling into
## a pile.
func _pile(count: int, slime_state := SlimeBodies.IN_BASKET, master_seed := 7) -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(master_seed))
	bodies.terrain = TerrainSegments.new(Support.box_polygons(BOX_HALF_WIDTH))
	var d := 2.0 * (SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE) + 2.0
	var per_row := int((2.0 * BOX_HALF_WIDTH - 8.0) / d)
	for i in count:
		var at := Vector2(-BOX_HALF_WIDTH + 4.0 + d * (0.5 + i % per_row), -d * (0.5 + i / per_row))
		bodies.create(i % Species.COUNT, 1, at, slime_state)
	return bodies


func _count(bodies: SlimeBodies, calm: int) -> int:
	var n := 0
	for s in bodies.slime_count:
		n += 1 if bodies.calm[s] == calm else 0
	return n


## Ticks until every slime rests (-1 if not within `limit`).
func _ticks_to_rest(bodies: SlimeBodies, limit: int) -> int:
	for t in limit:
		bodies.tick(DT)
		if _count(bodies, SlimeBodies.RESTING) == bodies.slime_count:
			return t + 1
	return -1


func test_a_basket_pile_comes_to_rest_whole_and_stops_moving() -> void:
	var bodies := _pile(24)
	var ticks := _ticks_to_rest(bodies, 900)
	gut.p("the pile rests after %d ticks" % ticks)
	assert_between(ticks, SlimeBodies.REST_TICKS, 900, "the whole pile rests")
	var group := bodies.pile[0]
	for s in bodies.slime_count:
		assert_eq(bodies.pile[s], group, "one pile")
	var before := bodies.pos.duplicate()
	_run(bodies, 120)
	assert_eq(bodies.pos, before, "a resting pile doesn't move at all")
	assert_eq(bodies.touching_pairs(), [], "walls are never paired")
	assert_eq(Support.layout_problems(bodies), PackedStringArray())


func test_bedtime_asleep_slimes_rest_too() -> void:
	var bodies := _pile(6, SlimeBodies.BEDTIME_ASLEEP)
	assert_gt(_ticks_to_rest(bodies, 900), 0)


func test_train_and_free_slimes_never_rest() -> void:
	for slime_state in [SlimeBodies.TRAIN, SlimeBodies.FREE, SlimeBodies.SLEEPER]:
		var bodies := _pile(6, slime_state)
		bodies.auto_hops = false
		_run(bodies, 600)
		assert_eq(_count(bodies, SlimeBodies.RESTING), 0, SlimeBodies.STATE_NAMES[slime_state])


func test_with_the_rule_off_nothing_rests() -> void:
	var bodies := _pile(12)
	bodies.rest_enabled = false
	_run(bodies, 600)
	assert_eq(_count(bodies, SlimeBodies.RESTING), 0)


func test_a_slime_landing_on_the_pile_wakes_it_whole() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	var dropped := bodies.create(0, 1, Vector2(0, -400), SlimeBodies.IN_BASKET)
	var woke := -1
	for t in 120:
		bodies.tick(DT)
		if _count(bodies, SlimeBodies.RESTING) == 0:
			woke = t
			break
	assert_gt(woke, 0, "the landing woke the whole pile")
	assert_gt(_ticks_to_rest(bodies, 900), 0, "and it rests again, the new slime with it")
	assert_eq(bodies.calm_of(dropped), SlimeBodies.RESTING)


func test_a_state_change_wakes_the_whole_pile() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	bodies.set_state(bodies.id[0], SlimeBodies.TRAIN)
	assert_eq(_count(bodies, SlimeBodies.RESTING), 0, "sunrise, a release: the pile simulates again")


func test_setting_the_same_state_does_not_wake() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	bodies.set_state(bodies.id[0], SlimeBodies.IN_BASKET)
	assert_eq(_count(bodies, SlimeBodies.RESTING), 12)


func test_taking_a_slime_out_wakes_the_pile_around_it() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	bodies.remove(bodies.id[0])
	assert_eq(_count(bodies, SlimeBodies.RESTING), 0)
	# Moved away by a new body (how a basket releases a slime at its outlet).
	var other := _pile(12)
	assert_gt(_ticks_to_rest(other, 900), 0)
	var moved := other.id[0]
	var body := other.body_of(moved)
	var shift := Vector2(600, -300)
	var points: PackedVector2Array = body["points"]
	var previous: PackedVector2Array = body["previous"]
	for k in points.size():
		points[k] += shift
		previous[k] += shift
	body["points"] = points
	body["previous"] = previous
	body["centre"] = body["centre"] + shift
	assert_true(other.set_body(moved, body))
	assert_eq(_count(other, SlimeBodies.RESTING), 0, "the pile it left wakes")


func test_wake_calls_wake_the_pile() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	assert_eq(bodies.wake_resting_in(Rect2(-2000, -2000, 10, 10)), 0, "nothing there")
	assert_eq(_count(bodies, SlimeBodies.RESTING), 12)
	assert_eq(bodies.wake_around(Vector2(0, -60), 10.0), 12, "a call on the pile")
	assert_eq(_count(bodies, SlimeBodies.RESTING), 0)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	var box := Rect2(-BOX_HALF_WIDTH, -400, 2.0 * BOX_HALF_WIDTH, 400)
	assert_eq(bodies.wake_resting_in(box), 12, "a door beside it")


func test_a_parked_slime_is_neither_simulated_nor_touched() -> void:
	var bodies := Support.bodies_on_floor()
	var parked := bodies.create(0, 1, Vector2(0, -200), SlimeBodies.TRAIN)
	bodies.park(parked)
	assert_true(bodies.is_parked(parked))
	var before := bodies.points_of(parked)
	# A slime falling right through where the parked one hangs.
	var falling := bodies.create(1, 1, Vector2(0, -300), SlimeBodies.FREE)
	bodies.auto_hops = false
	_run(bodies, 120)
	assert_eq(bodies.points_of(parked), before, "no gravity, no contact")
	assert_false(bodies.touching(parked, falling))
	assert_gt(bodies.centre_of(falling).y, -60.0, "it fell through to the floor")
	assert_false(bodies.can_hop(parked), "a parked slime doesn't hop")
	assert_false(bodies.hop(parked, Vector2.UP, 1.0))


func test_a_parked_slime_moves_only_by_translate_and_lands_when_unparked() -> void:
	var bodies := Support.bodies_on_floor()
	var slime := bodies.create(0, 1, Vector2(0, -200), SlimeBodies.TRAIN)
	bodies.auto_hops = false
	bodies.park(slime)
	bodies.translate(slime, Vector2(500, 100))
	assert_almost_eq(bodies.centre_of(slime), Vector2(500, -100), Vector2(0.01, 0.01))
	assert_almost_eq(bodies.velocity_of(slime), Vector2.ZERO, Vector2(0.01, 0.01), "translate keeps it still")
	bodies.unpark(slime)
	assert_eq(bodies.calm_of(slime), SlimeBodies.ACTIVE)
	_run(bodies, 180)
	assert_between(bodies.centre_of(slime).y, -30.0, 0.0, "it fell to the floor")


func test_parked_slimes_are_left_out_of_the_pairs() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var a := bodies.create(0, 1, Vector2(0, -24))
	var b := bodies.create(0, 1, Vector2(36, -24))
	var far := bodies.create(0, 1, Vector2(100000, -24))
	bodies.park(far)
	_run(bodies, 1)
	assert_true(bodies.touching(a, b), "the grid still pairs the others (overlapping, pushed apart)")
	for s in bodies.slime_count:
		if bodies.calm[s] == SlimeBodies.PARKED:
			assert_eq(bodies._slime_cell[s], -1)


func test_low_detail_resamples_the_ring_and_back() -> void:
	for size in [1, 2, 3]:
		var bodies := Support.bodies_on_floor()
		bodies.auto_hops = false
		var slime := bodies.create(0, size, Vector2(0, -100), SlimeBodies.FREE)
		_run(bodies, 20)
		var centre := bodies.centre_of(slime)
		var velocity := bodies.velocity_of(slime)
		var version := bodies.topology_version
		assert_true(bodies.set_low_detail(slime, true))
		assert_false(bodies.set_low_detail(slime, true), "no change")
		assert_true(bodies.is_low_detail(slime))
		assert_eq(bodies.points_of(slime).size(), SlimeBodies.low_points_for(size))
		assert_gt(bodies.topology_version, version, "the renderer rebuilds")
		assert_almost_eq(bodies.centre_of(slime), centre, Vector2(1.0, 1.0), "size %d: in place" % size)
		assert_almost_eq(bodies.velocity_of(slime), velocity, Vector2(0.01, 0.01), "size %d: moving on" % size)
		assert_eq(Support.layout_problems(bodies), PackedStringArray())
		_run(bodies, 240)
		var area := bodies.area_of(slime) / bodies.rest_area_of(slime)
		assert_between(area, 0.85, 1.1, "size %d: a low-detail slime keeps its area" % size)
		assert_between(bodies.centre_of(slime).y, -bodies.radius_of(slime) * 1.2 - 3.0, 0.0,
				"size %d: it rests on the floor" % size)
		assert_true(bodies.set_low_detail(slime, false))
		assert_eq(bodies.points_of(slime).size(), SlimeBodies.points_for(size))
		assert_eq(Support.layout_problems(bodies), PackedStringArray())


## Every ring at once (set_all_low_detail, what Offscreen does each tick)
## leaves exactly the state one set_low_detail per id, ascending, leaves:
## same points, same calm (a resampled resting slime wakes its pile), same
## hash, the rings already at that detail untouched.
func test_setting_every_rings_detail_matches_setting_each_by_id() -> void:
	var by_id := _pile(12)
	var at_once := _pile(12)
	assert_gt(_ticks_to_rest(by_id, 900), 0)
	assert_gt(_ticks_to_rest(at_once, 900), 0)
	for bodies in [by_id, at_once]:
		bodies.set_low_detail(bodies.id[3], true)
	for on in [true, false]:
		var changed := 0
		for slime_id in by_id.ids():
			changed += 1 if by_id.set_low_detail(slime_id, on) else 0
		assert_eq(at_once.set_all_low_detail(on), changed, "as many rings changed")
		assert_eq(at_once.pos, by_id.pos)
		assert_eq(at_once.prev, by_id.prev)
		assert_eq(at_once.calm, by_id.calm)
		assert_eq(StateHash.of(at_once.dump()), StateHash.of(by_id.dump()))
		assert_eq(at_once.set_all_low_detail(on), 0, "nothing left to change")
		_run(by_id, 30)
		_run(at_once, 30)
		assert_eq(at_once.pos, by_id.pos, "and they move on alike")
	assert_eq(Support.layout_problems(at_once), PackedStringArray())


func test_a_low_detail_slime_merges_and_splits_at_low_detail() -> void:
	var bodies := Support.bodies_on_floor()
	var a := bodies.create(0, 1, Vector2(0, -30))
	var b := bodies.create(0, 2, Vector2(60, -30))
	bodies.set_low_detail(a, true)
	var merged := bodies.merge(a, b)
	assert_eq(bodies.points_of(merged).size(), SlimeBodies.low_points_for(3))
	var parts := bodies.split(merged)
	assert_eq(bodies.points_of(parts[0]).size(), SlimeBodies.low_points_for(1))
	assert_eq(Support.layout_problems(bodies), PackedStringArray())


func test_a_body_round_trip_keeps_the_calm_and_the_detail() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	var slime := bodies.id[3]
	bodies.set_low_detail(bodies.id[5], true)
	var copy := _pile(12)
	for s in bodies.slime_count:
		var body := bodies.body_of(bodies.id[s])
		assert_true(copy.set_body(copy.id[s], body), "slime %d" % s)
	assert_eq(copy.dump(), bodies.dump())
	_run(bodies, 90)
	_run(copy, 90)
	assert_eq(copy.dump(), bodies.dump(), "and they stay equal")
	assert_eq(bodies.calm_of(slime), copy.calm_of(slime))


func test_set_body_refuses_the_wrong_point_count() -> void:
	var bodies := Support.bodies_on_floor()
	var slime := bodies.create(0, 1, Vector2(0, -30))
	var body := bodies.body_of(slime)
	body["low"] = true
	assert_false(bodies.set_body(slime, body), "12 points for a low-detail ring of 8")
	assert_false(bodies.is_low_detail(slime), "nothing changed")


func test_the_same_seed_rests_the_same() -> void:
	var dumps := []
	for run in 2:
		var bodies := _pile(18, SlimeBodies.IN_BASKET, 11)
		_run(bodies, 400)
		bodies.create(0, 1, Vector2(0, -400), SlimeBodies.IN_BASKET)
		_run(bodies, 200)
		dumps.append(bodies.dump())
	assert_eq(dumps[0], dumps[1])

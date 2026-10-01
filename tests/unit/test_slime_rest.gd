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


## The pile slime indices (all but `except`) whose ring may reach within
## `radius` of `point`: the slimes a disturbance there touches.
func _in_reach(bodies: SlimeBodies, point: Vector2, radius: float, except := -1) -> Array:
	var out := []
	for s in bodies.slime_count:
		var reach := radius + bodies.bound_r[s] + SlimeBodies.TOUCH_SKIN
		if s != except and bodies.centre[s].distance_squared_to(point) < reach * reach:
			out.append(s)
	return out


## The indices of the slimes whose calm is `calm`.
func _with_calm(bodies: SlimeBodies, calm: int) -> Array:
	var out := []
	for s in bodies.slime_count:
		if bodies.calm[s] == calm:
			out.append(s)
	return out


## The local wake (D145): a touch faster than WAKE_SPEED wakes only the
## resting slimes touched, the rest of the pile stays resting (it replaces
## D96's whole-pile wake, which this test asserted before).
# @test-link [[req_offscreen_simulation]]
func test_a_slime_landing_on_the_pile_wakes_only_the_slimes_it_touches() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	var group := bodies.pile[0]
	var dropped := bodies.create(0, 1, Vector2(0, -400), SlimeBodies.IN_BASKET)
	var woken := []
	for t in 120:
		bodies.tick(DT)
		woken = _with_calm(bodies, SlimeBodies.ACTIVE)
		woken.erase(bodies.index_of(dropped))
		if not woken.is_empty():
			break
	assert_false(woken.is_empty(), "the landing woke the slimes it hit")
	for s in woken:
		assert_true(bodies.touching(dropped, bodies.id[s]), "slime %d: touched by the landing" % bodies.id[s])
		assert_eq(bodies.pile[s], 0, "a woken slime leaves its pile")
	assert_eq(_count(bodies, SlimeBodies.RESTING), 12 - woken.size(), "the rest of the pile rests on")
	for s in _with_calm(bodies, SlimeBodies.RESTING):
		assert_eq(bodies.pile[s], group, "and keeps its pile")
	assert_gt(_ticks_to_rest(bodies, 900), 0, "and it rests again, the new slime with it")
	assert_eq(bodies.calm_of(dropped), SlimeBodies.RESTING)


# @test-link [[req_offscreen_simulation]]
func test_a_state_change_wakes_only_that_slime() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	bodies.set_state(bodies.id[0], SlimeBodies.TRAIN)
	assert_eq(_with_calm(bodies, SlimeBodies.ACTIVE), [0], "sunrise, a release: that slime simulates again")


func test_setting_the_same_state_does_not_wake() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	bodies.set_state(bodies.id[0], SlimeBodies.IN_BASKET)
	assert_eq(_count(bodies, SlimeBodies.RESTING), 12)


## A slime taken out of a pile wakes the resting slimes that touched it, not
## the rest of the pile (D145; D96 woke the whole pile).
# @test-link [[req_offscreen_simulation]]
func test_taking_a_slime_out_wakes_only_the_slimes_touching_it() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	var touched := _in_reach(bodies, bodies.centre[0], bodies.bound_r[0], 0)
	var touched_ids := []
	for s in touched:
		touched_ids.append(bodies.id[s])
	assert_between(touched.size(), 1, 10, "some, not all, of the pile touch it")
	bodies.remove(bodies.id[0])
	var woken_ids := []
	for s in _with_calm(bodies, SlimeBodies.ACTIVE):
		woken_ids.append(bodies.id[s])
	assert_eq(woken_ids, touched_ids, "the slimes it touched wake")
	assert_eq(_count(bodies, SlimeBodies.RESTING), 11 - touched.size(), "the others rest on")
	# Moved away by a new body (how a basket releases a slime at its outlet).
	var other := _pile(12)
	assert_gt(_ticks_to_rest(other, 900), 0)
	var near := _in_reach(other, other.centre[0], other.bound_r[0], 0)
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
	assert_eq(other.calm_of(moved), SlimeBodies.RESTING, "the body's calm (a release then sets its state)")
	assert_eq(_with_calm(other, SlimeBodies.ACTIVE), near, "the slimes it left wake")


# @test-link [[req_offscreen_simulation]]
func test_waking_a_pile_slime_wakes_only_it_and_it_rests_again_in_a_pile_of_its_own() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	var group := bodies.pile[0]
	bodies.wake(bodies.id[5])
	assert_eq(_with_calm(bodies, SlimeBodies.ACTIVE), [5])
	assert_eq(bodies.pile[5], 0)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	assert_eq(bodies.pile[5], bodies.id[5], "a group of one: its own id")
	for s in bodies.slime_count:
		if s != 5:
			assert_eq(bodies.pile[s], group, "the others keep theirs")


# @test-link [[req_offscreen_simulation]]
func test_wake_calls_wake_only_the_slimes_in_reach() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	assert_eq(bodies.wake_resting_in(Rect2(-2000, -2000, 10, 10)), 0, "nothing there")
	assert_eq(_count(bodies, SlimeBodies.RESTING), 12)
	var reached := _in_reach(bodies, Vector2(0, -60), 10.0)
	assert_between(reached.size(), 1, 11, "a call on part of the pile")
	assert_eq(bodies.wake_around(Vector2(0, -60), 10.0), reached.size(), "a call on the pile")
	assert_eq(_with_calm(bodies, SlimeBodies.ACTIVE), reached, "wakes the slimes it reaches")
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	var low := Rect2(-BOX_HALF_WIDTH, -40, 2.0 * BOX_HALF_WIDTH, 40)
	var in_low := []
	for s in bodies.slime_count:
		if low.has_point(bodies.centre[s]):
			in_low.append(s)
	assert_between(in_low.size(), 1, 11)
	assert_eq(bodies.wake_resting_in(low), in_low.size(), "a door by the bottom row")
	assert_eq(_with_calm(bodies, SlimeBodies.ACTIVE), in_low, "wakes that row")
	var box := Rect2(-BOX_HALF_WIDTH, -400, 2.0 * BOX_HALF_WIDTH, 400)
	assert_eq(bodies.wake_resting_in(box), 12 - in_low.size(), "a door beside it wakes the rest")


## A sleeper is a state, not the resting calm: no wake ever changes it, and
## a pile slime woken beside it leaves it asleep.
# @test-link [[req_offscreen_simulation]]
func test_the_local_wake_never_wakes_a_sleeper() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	var top := 0
	for s in bodies.slime_count:
		if bodies.centre[s].y < bodies.centre[top].y:
			top = s
	var beside := bodies.centre[top] + Vector2(0, -2.0 * (SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE))
	var sleeper := bodies.create(1, 1, beside, SlimeBodies.SLEEPER)
	var points := bodies.points_of(sleeper)
	bodies.wake(bodies.id[top])
	bodies.wake_around(beside, 30.0)
	bodies.wake_resting_in(Rect2(beside - Vector2(50, 50), Vector2(100, 100)))
	bodies.wake(sleeper)
	bodies.auto_hops = false
	_run(bodies, 60)
	assert_eq(bodies.state_of(sleeper), SlimeBodies.SLEEPER)
	assert_eq(bodies.points_of(sleeper), points, "it never moved")


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


func test_a_detail_level_resamples_the_ring_and_back() -> void:
	for size in [1, 2, 3]:
		var bodies := Support.bodies_on_floor()
		bodies.auto_hops = false
		var slime := bodies.create(0, size, Vector2(0, -100), SlimeBodies.FREE)
		_run(bodies, 20)
		var centre := bodies.centre_of(slime)
		var velocity := bodies.velocity_of(slime)
		var version := bodies.topology_version
		assert_true(bodies.set_detail(slime, SlimeBodies.MAX_DETAIL))
		assert_false(bodies.set_detail(slime, SlimeBodies.MAX_DETAIL), "no change")
		assert_eq(bodies.detail_of(slime), SlimeBodies.MAX_DETAIL)
		assert_eq(bodies.points_of(slime).size(), SlimeBodies.detail_points_for(size, SlimeBodies.MAX_DETAIL))
		assert_gt(bodies.topology_version, version, "the renderer rebuilds")
		assert_almost_eq(bodies.centre_of(slime), centre, Vector2(1.0, 1.0), "size %d: in place" % size)
		assert_almost_eq(bodies.velocity_of(slime), velocity, Vector2(0.01, 0.01), "size %d: moving on" % size)
		assert_eq(Support.layout_problems(bodies), PackedStringArray())
		_run(bodies, 240)
		var area := bodies.area_of(slime) / bodies.rest_area_of(slime)
		assert_between(area, 0.85, 1.1, "size %d: a low-detail slime keeps its area" % size)
		assert_between(bodies.centre_of(slime).y, -bodies.radius_of(slime) * 1.2 - 3.0, 0.0,
				"size %d: it rests on the floor" % size)
		assert_true(bodies.set_detail(slime, 0))
		assert_eq(bodies.points_of(slime).size(), SlimeBodies.points_for(size))
		assert_eq(Support.layout_problems(bodies), PackedStringArray())


## Every active ring at once (set_active_detail, what Offscreen does each
## tick) leaves resting rings as they are, pile still resting, and leaves
## exactly the state one set_detail per active id, ascending, leaves (at
## PILE_MAX_DETAIL at most: these are pile slimes, in a basket): same
## points, same calm, same hash, the rings already at that level untouched.
func test_setting_every_active_rings_detail_matches_setting_each_by_id() -> void:
	var by_id := _pile(12)
	var at_once := _pile(12)
	assert_gt(_ticks_to_rest(by_id, 900), 0)
	assert_gt(_ticks_to_rest(at_once, 900), 0)
	var resting := at_once.pos
	assert_eq(at_once.set_active_detail(SlimeBodies.MAX_DETAIL), 0, "a resting pile keeps its rings")
	assert_eq(at_once.pos, resting)
	assert_eq(_count(at_once, SlimeBodies.RESTING), at_once.slime_count, "and rests")
	for bodies in [by_id, at_once]:
		bodies.set_detail(bodies.id[3], SlimeBodies.LOW_DETAIL)
		assert_eq(_with_calm(bodies, SlimeBodies.ACTIVE), [3], "a reshape by id wakes that slime")
		bodies.wake_resting_in(Rect2(-2000, -2000, 4000, 4000))
		assert_eq(_count(bodies, SlimeBodies.ACTIVE), bodies.slime_count, "a door wakes the rest")
	for level in [SlimeBodies.MAX_DETAIL, 1, 0]:
		var changed := 0
		for slime_id in by_id.ids():
			changed += 1 if by_id.set_detail(slime_id, mini(level, SlimeBodies.PILE_MAX_DETAIL)) else 0
		assert_eq(at_once.set_active_detail(level), changed, "as many rings changed")
		assert_eq(at_once.pos, by_id.pos)
		assert_eq(at_once.prev, by_id.prev)
		assert_eq(at_once.calm, by_id.calm)
		assert_eq(StateHash.of(at_once.dump()), StateHash.of(by_id.dump()))
		assert_eq(at_once.set_active_detail(level), 0, "nothing left to change")
		_run(by_id, 30)
		_run(at_once, 30)
		assert_eq(at_once.pos, by_id.pos, "and they move on alike")
	assert_eq(Support.layout_problems(at_once), PackedStringArray())


func test_a_low_detail_slime_merges_and_splits_at_low_detail() -> void:
	var bodies := Support.bodies_on_floor()
	var a := bodies.create(0, 1, Vector2(0, -30))
	var b := bodies.create(0, 2, Vector2(60, -30))
	bodies.set_detail(a, SlimeBodies.LOW_DETAIL)
	var merged := bodies.merge(a, b)
	assert_eq(bodies.points_of(merged).size(), SlimeBodies.detail_points_for(3, SlimeBodies.LOW_DETAIL))
	var parts := bodies.split(merged)
	assert_eq(bodies.points_of(parts[0]).size(), SlimeBodies.detail_points_for(1, SlimeBodies.LOW_DETAIL))
	assert_eq(Support.layout_problems(bodies), PackedStringArray())


func test_a_body_round_trip_keeps_the_calm_and_the_detail() -> void:
	var bodies := _pile(12)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	var slime := bodies.id[3]
	bodies.set_detail(bodies.id[5], SlimeBodies.MAX_DETAIL)
	# Created where they lie, as a save reload does: a body moving a slime
	# would wake the restored resting slimes it touched (D145: those only).
	var copy := SlimeBodies.new(Rng.new(7))
	copy.terrain = bodies.terrain
	for s in bodies.slime_count:
		copy.create(bodies.species[s], bodies.size[s], bodies.centre_of(bodies.id[s]), bodies.state[s])
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
	body["detail"] = SlimeBodies.LOW_DETAIL
	assert_false(bodies.set_body(slime, body), "12 points for a level-2 ring of 8")
	assert_eq(bodies.detail_of(slime), 0, "nothing changed")


func test_the_same_seed_rests_the_same() -> void:
	var dumps := []
	for run in 2:
		var bodies := _pile(18, SlimeBodies.IN_BASKET, 11)
		_run(bodies, 400)
		bodies.create(0, 1, Vector2(0, -400), SlimeBodies.IN_BASKET)
		_run(bodies, 200)
		dumps.append(bodies.dump())
	assert_eq(dumps[0], dumps[1])

extends GutTest
## SlimeBodies' "may rest" input (chunk 22e, D145): the behaviour code (the
## Train, for a holding train slime) lets a train slime rest under the pile
## rule; it is an input, not state. Also the read-only crowd count ahead of
## a hop (awake_count_ahead) and Fusion's "counts toward fusion".

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0
const BOX_HALF_WIDTH := 130.0
## A base slime's centre height when standing on the floor (y = 0).
const STAND_Y := -(SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE)


## Ticks the bodies `ticks` times.
func _run(bodies: SlimeBodies, ticks: int) -> void:
	for i in ticks:
		bodies.tick(DT)


## `count` base train slimes, shelf-packed in a box, falling into a pile,
## automatic hops off.
func _train_pile(count: int) -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(7))
	bodies.terrain = TerrainSegments.new(Support.box_polygons(BOX_HALF_WIDTH))
	bodies.auto_hops = false
	var d := 2.0 * (SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE) + 2.0
	var per_row := int((2.0 * BOX_HALF_WIDTH - 8.0) / d)
	for i in count:
		var at := Vector2(-BOX_HALF_WIDTH + 4.0 + d * (0.5 + i % per_row), -d * (0.5 + i / per_row))
		bodies.create(i % Species.COUNT, 1, at, SlimeBodies.TRAIN)
	return bodies


## How many slimes have calm `calm`.
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


# --- The "may rest" input ------------------------------------------------------

# @test-link [[req_offscreen_simulation]]
func test_a_train_slime_that_may_rest_rests_like_a_pile_slime() -> void:
	var bodies := _train_pile(6)
	for slime_id in bodies.ids():
		bodies.set_may_rest(slime_id, true)
		assert_true(bodies.may_rest_of(slime_id))
	assert_eq(bodies.crowd_count(), 6, "all cost physics while settling")
	var ticks := _ticks_to_rest(bodies, 900)
	assert_between(ticks, SlimeBodies.REST_TICKS, 900, "the holding train slimes rest")
	assert_eq(bodies.crowd_count(), 0, "resting: they cost nothing")
	for s in bodies.slime_count:
		assert_ne(bodies.pile[s], 0, "in a pile")
		assert_eq(bodies.state[s], SlimeBodies.TRAIN, "still train slimes")


# @test-link [[req_offscreen_simulation]]
func test_a_train_slime_without_may_rest_never_rests() -> void:
	var bodies := _train_pile(6)
	_run(bodies, 600)
	assert_eq(_count(bodies, SlimeBodies.RESTING), 0)
	assert_eq(bodies.crowd_count(), 6)


# @test-link [[req_offscreen_simulation]]
func test_only_a_train_slime_may_rest_by_the_input() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var free := bodies.create(0, 1, Vector2(0, STAND_Y), SlimeBodies.FREE)
	bodies.set_may_rest(free, true)
	_run(bodies, 300)
	assert_eq(bodies.calm_of(free), SlimeBodies.ACTIVE, "a free slime never rests, input or not")


# @test-link [[req_offscreen_simulation]]
func test_may_rest_is_an_input_not_in_dump_nor_in_body() -> void:
	var bodies := _train_pile(3)
	_run(bodies, 10)
	var slime_id := bodies.id[1]
	var dump_before := bodies.dump()
	var body_before := bodies.body_of(slime_id)
	bodies.set_may_rest(slime_id, true)
	assert_eq(bodies.dump(), dump_before, "not in dump()")
	assert_eq(bodies.body_of(slime_id), body_before, "not in body_of()")
	assert_false(body_before.has("may_rest"))


# @test-link [[req_offscreen_simulation]]
func test_clearing_may_rest_does_not_wake_a_resting_slime() -> void:
	var bodies := _train_pile(3)
	for slime_id in bodies.ids():
		bodies.set_may_rest(slime_id, true)
	assert_gt(_ticks_to_rest(bodies, 900), 0)
	for slime_id in bodies.ids():
		bodies.set_may_rest(slime_id, false)
	_run(bodies, 60)
	assert_eq(_count(bodies, SlimeBodies.RESTING), 3, "the behaviour code wakes it (wake), not the input")
	bodies.wake(bodies.id[0])
	assert_eq(bodies.calm_of(bodies.id[0]), SlimeBodies.ACTIVE)
	_run(bodies, 300)
	assert_eq(bodies.calm_of(bodies.id[0]), SlimeBodies.ACTIVE, "woken without may rest: stays active")


# @test-link [[req_offscreen_simulation]]
func test_a_state_change_clears_may_rest() -> void:
	var bodies := _train_pile(2)
	var a := bodies.id[0]
	var b := bodies.id[1]
	bodies.set_may_rest(a, true)
	bodies.set_may_rest(b, true)
	bodies.set_state(a, SlimeBodies.TRAIN)
	assert_true(bodies.may_rest_of(a), "the same state: kept")
	bodies.set_state(a, SlimeBodies.FREE)
	assert_false(bodies.may_rest_of(a), "a new state: cleared")
	bodies.set_state(a, SlimeBodies.TRAIN)
	assert_false(bodies.may_rest_of(a), "and not back with the state")
	assert_true(bodies.may_rest_of(b), "the other slime keeps its own")
	assert_false(bodies.may_rest_of(9999), "a missing slime: false")


# @test-link [[req_offscreen_simulation]]
func test_a_train_slime_that_may_rest_keeps_its_detail_while_a_basket_slime_is_capped() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var holder := bodies.create(0, 1, Vector2(-200, STAND_Y), SlimeBodies.TRAIN)
	var in_basket := bodies.create(1, 1, Vector2(200, STAND_Y), SlimeBodies.IN_BASKET)
	bodies.set_may_rest(holder, true)
	bodies.set_active_detail(SlimeBodies.MAX_DETAIL)
	assert_eq(bodies.detail_of(holder), SlimeBodies.MAX_DETAIL, "a holder is not capped")
	assert_eq(bodies.detail_of(in_basket), SlimeBodies.PILE_MAX_DETAIL, "a pile slime is, as before")


# @test-link [[req_offscreen_simulation]]
func test_may_rest_stays_with_its_slime_through_removal_merge_and_split() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var a := bodies.create(0, 1, Vector2(-300, STAND_Y))
	var b := bodies.create(1, 1, Vector2(-100, STAND_Y))
	var c := bodies.create(2, 1, Vector2(100, STAND_Y))
	var d := bodies.create(2, 1, Vector2(300, STAND_Y))
	bodies.set_may_rest(c, true)
	assert_true(bodies.remove(a))
	assert_false(bodies.may_rest_of(b), "b moved down an index: not c's input")
	assert_true(bodies.may_rest_of(c), "c keeps its own")
	assert_eq(bodies.may_rest.size(), bodies.slime_count, "one entry per slime")
	bodies.set_may_rest(d, true)
	var fused := bodies.merge(c, d)
	assert_eq(fused, c)
	assert_false(bodies.may_rest_of(fused), "a fused slime starts at 0")
	bodies.set_may_rest(fused, true)
	var parts := bodies.split(fused)
	assert_eq(parts.size(), 2)
	for part in parts:
		assert_false(bodies.may_rest_of(part), "a split part starts at 0")
	assert_eq(bodies.may_rest.size(), bodies.slime_count)
	var fresh := bodies.create(3, 1, Vector2(600, STAND_Y))
	assert_false(bodies.may_rest_of(fresh), "a new slime starts at 0")


# --- The crowd ahead of a hop ----------------------------------------------------

# @test-link [[req_hopping_behavior]]
func test_awake_count_ahead_counts_only_physics_slimes_out_of_baskets_near_the_target_and_ahead() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var from := Vector2(-300, STAND_Y)
	var target := Vector2(0, STAND_Y)
	var me := bodies.create(0, 1, from)
	var counted := [
		bodies.create(1, 1, Vector2(-100, STAND_Y)),
		bodies.create(2, 1, Vector2(0, STAND_Y)),
		bodies.create(3, 1, Vector2(150, STAND_Y), SlimeBodies.FREE),
	]
	bodies.create(4, 1, Vector2(50, STAND_Y), SlimeBodies.IN_BASKET)
	bodies.create(5, 1, Vector2(-50, STAND_Y), SlimeBodies.SLEEPER)
	bodies.create(0, 1, Vector2(400, STAND_Y))
	var parked := bodies.create(1, 1, Vector2(100, STAND_Y))
	bodies.park(parked)
	var resting := bodies.create(2, 1, Vector2(200, STAND_Y))
	var body := bodies.body_of(resting)
	body["calm"] = SlimeBodies.RESTING
	assert_true(bodies.set_body(resting, body))
	assert_eq(bodies.calm_of(resting), SlimeBodies.RESTING)
	assert_eq(bodies.awake_count_ahead(target, 240.0, from, me), counted.size(),
			"two train slimes and a free one; not a basket, sleeper, far, parked or resting slime")
	assert_eq(bodies.awake_count_ahead(target, 240.0, from, -1), counted.size(),
			"itself sits at `from`: never ahead")
	assert_eq(bodies.awake_count_ahead(target, 100.0, from, me), 1, "strictly within the radius: only the one at 0")


# @test-link [[req_hopping_behavior]]
func test_a_crowd_behind_the_slime_counts_zero() -> void:
	var bodies := Support.bodies_on_floor()
	bodies.auto_hops = false
	var from := Vector2(-100, STAND_Y)
	var target := Vector2(0, STAND_Y)
	var me := bodies.create(0, 1, from)
	for k in 4:
		bodies.create(1, 1, Vector2(-160 - 50 * k, STAND_Y))
	assert_eq(bodies.awake_count_ahead(target, 240.0, from, me), 0, "within the radius but behind it")
	assert_eq(bodies.awake_count_ahead(Vector2(-350, STAND_Y), 240.0, from, me), 4, "ahead the other way")


# --- Fusion: a contact counting toward fusion ------------------------------------

## A simulation on a flat floor, automatic hops off, the view on the origin.
func _sim() -> Simulation:
	var sim := Simulation.new(11)
	sim.slimes.terrain = TerrainSegments.new([Support.floor_polygon()])
	sim.slimes.auto_hops = false
	sim.view.set_to(Vector2(0, -100), 1.0, ScreenView.DEFAULT_SIZE)
	return sim


## Two base slimes side by side on the floor, their rings touching.
func _pair(sim: Simulation, species_a: int, species_b: int, x := 0.0) -> Array[int]:
	var r := SlimeBodies.RING_RADIUS_SIZE_1
	var a := sim.slimes.create(species_a, 1, Vector2(x - r, STAND_Y))
	var b := sim.slimes.create(species_b, 1, Vector2(x + r, STAND_Y))
	return [a, b]


# @test-link [[rule_fusion_contact_time]]
func test_counts_toward_fusion_for_two_same_species_train_slimes_touching_on_screen() -> void:
	var sim := _sim()
	var same := _pair(sim, 2, 2, -200.0)
	var other := _pair(sim, 0, 1, 200.0)
	var alone := sim.slimes.create(3, 1, Vector2(0, STAND_Y))
	assert_false(sim.fusion.counts_toward_fusion(same[0]), "before any step")
	sim.step()
	assert_true(sim.slimes.touching(same[0], same[1]))
	assert_true(sim.slimes.touching(other[0], other[1]))
	assert_true(sim.fusion.counts_toward_fusion(same[0]))
	assert_true(sim.fusion.counts_toward_fusion(same[1]))
	assert_false(sim.fusion.counts_toward_fusion(other[0]), "different species never count")
	assert_false(sim.fusion.counts_toward_fusion(other[1]))
	assert_false(sim.fusion.counts_toward_fusion(alone), "no contact")
	assert_false(sim.fusion.counts_toward_fusion(9999), "a missing slime")


# @test-link [[rule_fusion_contact_time]]
func test_counts_toward_fusion_is_false_off_screen() -> void:
	var sim := _sim()
	var far := _pair(sim, 2, 2, 1500.0)
	sim.step()
	assert_true(sim.slimes.touching(far[0], far[1]))
	assert_false(sim.fusion.counts_toward_fusion(far[0]), "off screen nothing counts")

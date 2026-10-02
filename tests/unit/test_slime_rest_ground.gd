extends GutTest
## Resting on the ground and the wake up the stack (chunk 22f, D147 5 (b)):
## a train slime resting through "may rest" (a holder, or a slime resting by
## contact with one) may only start resting on the ground: touching terrain
## facing up, or standing on a resting slime. Standing on an awake slime isn't
## ground. When a slime wakes, the may-rest slimes resting on it wake too, up
## the stack. Pile slimes (in a basket, asleep at bedtime) rest and wake as
## before, and a sleeper is a state no wake changes.

const Support := preload("res://tests/unit/slime_test_support.gd")
const DT := 1.0 / 60.0
## A base slime's centre height when standing on the floor (y = 0).
const STAND_Y := -(SlimeBodies.RING_RADIUS_SIZE_1 + SlimeBodies.EDGE)
## A box two base slimes wide (a groove for a third on top), and a box one
## base slime wide (a column).
const GROOVE_HALF_WIDTH := 46.0
const COLUMN_HALF_WIDTH := 25.0
## Two base rings' centres when they touch, px (the radii plus 1).
const TOUCH := 2.0 * SlimeBodies.RING_RADIUS_SIZE_1 + 1.0


## Bodies in a box `half_width` px either side of x = 0, automatic hops off.
func _bodies(half_width: float) -> SlimeBodies:
	var bodies := SlimeBodies.new(Rng.new(3))
	bodies.terrain = TerrainSegments.new(Support.box_polygons(half_width))
	bodies.auto_hops = false
	return bodies


## Two base slimes side by side on the floor of a groove box and a third on
## them: [left, right, top], all in `slime_state`, of different species.
func _groove(bodies: SlimeBodies, slime_state: int) -> Array[int]:
	var half := TOUCH * 0.5
	var left := bodies.create(0, 1, Vector2(-half, STAND_Y), slime_state)
	var right := bodies.create(1, 1, Vector2(half, STAND_Y), slime_state)
	var top := bodies.create(2, 1, Vector2(0, STAND_Y - sqrt(TOUCH * TOUCH - half * half)), slime_state)
	return [left, right, top]


## A column of base slimes in a column box, bottom first, in `states` (one
## slime per entry), of different species.
func _column(bodies: SlimeBodies, states: Array) -> Array[int]:
	var out: Array[int] = []
	for i in states.size():
		out.append(bodies.create(i % Species.COUNT, 1, Vector2(0, STAND_Y - TOUCH * i), states[i]))
	return out


func _resting(bodies: SlimeBodies, slime_id: int) -> bool:
	return bodies.calm_of(slime_id) == SlimeBodies.RESTING


## Ticks until every slime of `slimes` rests (at most `limit`); returns, per
## slime, the tick it began resting (-1: never).
func _rest_ticks(bodies: SlimeBodies, slimes: Array[int], limit: int) -> Array[int]:
	var out: Array[int] = []
	for slime_id in slimes:
		out.append(-1)
	for t in limit:
		bodies.tick(DT)
		for k in slimes.size():
			if out[k] < 0 and _resting(bodies, slimes[k]):
				out[k] = t
		if not out.has(-1):
			break
	return out


# --- On the ground --------------------------------------------------------------

# @test-link [[req_offscreen_simulation]]
func test_a_may_rest_slime_standing_on_an_awake_slime_does_not_rest() -> void:
	var bodies := _bodies(GROOVE_HALF_WIDTH)
	var slimes := _groove(bodies, SlimeBodies.TRAIN)
	var top: int = slimes[2]
	bodies.set_may_rest(top, true)
	for i in 300:
		bodies.tick(DT)
		assert_false(_resting(bodies, top), "on awake slimes: never rests")
	var s := bodies.index_of(top)
	assert_ne(bodies.supported[s], 0, "it is supported (it may hop)")
	assert_false(bodies.on_ground_of(top), "but not on the ground")
	for slime_id in slimes.slice(0, 2):
		assert_true(bodies.on_ground_of(slime_id), "the slimes under it stand on terrain")


# @test-link [[req_offscreen_simulation]]
func test_a_may_rest_slime_standing_on_resting_slimes_on_terrain_rests_after_them() -> void:
	var bodies := _bodies(GROOVE_HALF_WIDTH)
	var slimes := _groove(bodies, SlimeBodies.TRAIN)
	for slime_id in slimes:
		bodies.set_may_rest(slime_id, true)
	var rested := _rest_ticks(bodies, slimes, 600)
	assert_false(rested.has(-1), "all three rest: %s" % [rested])
	assert_gt(rested[2], maxi(rested[0], rested[1]), "the top one once those under it rest: %s" % [rested])
	assert_true(bodies.on_ground_of(slimes[2]), "standing on resting slimes: on the ground")


# @test-link [[req_offscreen_simulation]]
func test_pile_slimes_on_awake_slimes_rest_whole_as_before() -> void:
	var bodies := _bodies(GROOVE_HALF_WIDTH)
	var slimes := _groove(bodies, SlimeBodies.IN_BASKET)
	var rested := _rest_ticks(bodies, slimes, 600)
	assert_false(rested.has(-1), "the basket pile rests: %s" % [rested])
	assert_eq(rested[2], rested[0], "whole, on the same tick: %s" % [rested])
	assert_eq(rested[2], rested[1])


# --- The wake up the stack ------------------------------------------------------

# @test-link [[req_offscreen_simulation]]
func test_waking_a_slime_wakes_the_may_rest_slimes_resting_on_it_up_a_stack_of_3() -> void:
	var bodies := _bodies(COLUMN_HALF_WIDTH)
	var stack := _column(bodies, [SlimeBodies.TRAIN, SlimeBodies.TRAIN, SlimeBodies.TRAIN])
	for slime_id in stack:
		bodies.set_may_rest(slime_id, true)
	assert_false(_rest_ticks(bodies, stack, 900).has(-1), "the stack rests")
	bodies.wake(stack[1])
	assert_true(_resting(bodies, stack[0]), "the slime under the woken one rests on")
	assert_false(_resting(bodies, stack[1]), "woken")
	assert_false(_resting(bodies, stack[2]), "the one on it wakes too")
	assert_false(_rest_ticks(bodies, stack, 900).has(-1), "it rests again")
	bodies.wake(stack[0])
	for slime_id in stack:
		assert_false(_resting(bodies, slime_id), "the whole stack above the bottom one wakes")


# @test-link [[req_offscreen_simulation]]
func test_the_wake_up_the_stack_spares_a_slime_beside_the_woken_one() -> void:
	var bodies := _bodies(GROOVE_HALF_WIDTH)
	var slimes := _groove(bodies, SlimeBodies.TRAIN)
	for slime_id in slimes:
		bodies.set_may_rest(slime_id, true)
	assert_false(_rest_ticks(bodies, slimes, 600).has(-1), "the three rest")
	bodies.wake(slimes[0])
	assert_false(_resting(bodies, slimes[2]), "the slime on it wakes")
	assert_true(_resting(bodies, slimes[1]), "the slime beside it rests on")


# @test-link [[req_offscreen_simulation]]
func test_the_wake_up_the_stack_never_wakes_a_basket_pile_nor_a_sleeper() -> void:
	var pile := _bodies(COLUMN_HALF_WIDTH)
	var basket := _column(pile, [SlimeBodies.IN_BASKET, SlimeBodies.IN_BASKET, SlimeBodies.IN_BASKET])
	assert_false(_rest_ticks(pile, basket, 900).has(-1), "the basket pile rests")
	pile.wake(basket[0])
	assert_true(_resting(pile, basket[1]) and _resting(pile, basket[2]), "the pile above rests on, as before")
	var mixed := _bodies(COLUMN_HALF_WIDTH)
	var under_pile := _column(mixed, [SlimeBodies.TRAIN, SlimeBodies.IN_BASKET, SlimeBodies.IN_BASKET])
	mixed.set_may_rest(under_pile[0], true)
	assert_false(_rest_ticks(mixed, under_pile, 900).has(-1), "a holder under basket slimes rests with them")
	mixed.wake(under_pile[0])
	assert_true(_resting(mixed, under_pile[1]) and _resting(mixed, under_pile[2]),
			"pile slimes on a woken train slime rest on")
	var asleep := _bodies(COLUMN_HALF_WIDTH)
	var under_sleeper := _column(asleep, [SlimeBodies.TRAIN, SlimeBodies.SLEEPER])
	asleep.set_may_rest(under_sleeper[0], true)
	assert_false(_rest_ticks(asleep, under_sleeper.slice(0, 1), 600).has(-1), "the slime under a sleeper rests")
	asleep.wake(under_sleeper[0])
	assert_eq(asleep.state_of(under_sleeper[1]), SlimeBodies.SLEEPER, "the sleeper is still a sleeper")
	assert_eq(asleep.calm_of(under_sleeper[1]), SlimeBodies.ACTIVE, "its calm untouched")


# --- Derived, not state ----------------------------------------------------------

# @test-link [[req_offscreen_simulation]]
func test_on_ground_is_derived_each_tick_not_in_dump_nor_in_body() -> void:
	var bodies := _bodies(GROOVE_HALF_WIDTH)
	var slimes := _groove(bodies, SlimeBodies.TRAIN)
	for i in 30:
		bodies.tick(DT)
	assert_false(bodies.dump()[0].has("on_ground"), "not in dump()")
	assert_false(bodies.body_of(slimes[0]).has("on_ground"), "not in body_of()")
	assert_eq(bodies.on_ground.size(), bodies.slime_count, "one entry per slime")
	bodies.remove(slimes[0])
	assert_eq(bodies.on_ground.size(), bodies.slime_count, "kept in step on removal")
	assert_false(bodies.on_ground_of(9999), "a missing slime: false")

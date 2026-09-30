extends GutTest
## FrontierView (src/frontier/frontier_view.gd): the way each switch sends
## the flow (its arrow and its signposts' arrows) is worked out along the loop
## once per level and set of open gates, then read from a cache every frame.

const Frontier := preload("res://tests/unit/frontier_test_support.gd")


func _view(sim: Simulation) -> FrontierView:
	var view := FrontierView.new()
	view.simulation = sim
	autofree(view)
	return view


func test_an_unflipped_switch_points_on_along_the_loop() -> void:
	var sim := Frontier.sim()
	var view := _view(sim)
	assert_almost_eq(view.way_of(Frontier.SWITCH).distance_to(Vector2.RIGHT), 0.0, 0.001)


func test_a_flipped_switch_points_down_into_its_basket() -> void:
	var sim := Frontier.sim()
	var view := _view(sim)
	sim.object_states[Frontier.SWITCH] = {"flipped": true}
	assert_eq(view.way_of(Frontier.SWITCH), Vector2.DOWN)


func test_the_way_is_cached_until_the_open_gates_change() -> void:
	var sim := Frontier.sim()
	var view := _view(sim)
	assert_almost_eq(view.way_of(Frontier.SWITCH).distance_to(Vector2.RIGHT), 0.0, 0.001)
	# Moved over the return route's bottom, where the loop runs left.
	(sim.level.switches[Frontier.SWITCH] as Dictionary)["box"] = Rect2(-725, 375, 50, 50)
	assert_almost_eq(view.way_of(Frontier.SWITCH).distance_to(Vector2.RIGHT), 0.0, 0.001,
			"same level, same gates: the cached way")
	assert_almost_eq(_view(sim).way_of(Frontier.SWITCH).distance_to(Vector2.LEFT), 0.0, 0.001,
			"a new view works it out afresh")
	sim.train.open_gates.append(Frontier.GATE)
	assert_almost_eq(view.way_of(Frontier.SWITCH).distance_to(Vector2.LEFT), 0.0, 0.001,
			"a gate opened: worked out again")


func test_a_new_level_empties_the_cache() -> void:
	var sim := Frontier.sim()
	var view := _view(sim)
	view.way_of(Frontier.SWITCH)
	var level := Frontier.level()
	(level.switches[Frontier.SWITCH] as Dictionary)["box"] = Rect2(-725, 375, 50, 50)
	sim.level = level
	assert_almost_eq(view.way_of(Frontier.SWITCH).distance_to(Vector2.LEFT), 0.0, 0.001)


## A view of `sim` in the tree, and how many times it has redrawn so far
## (its `draw` signal, emitted on every real redraw): [view, [count]].
func _drawn_view(sim: Simulation) -> Array:
	var view := FrontierView.new()
	view.simulation = sim
	var draws := [0]
	view.draw.connect(func() -> void: draws[0] += 1)
	add_child_autofree(view)
	return [view, draws]


## Waits a few frames and returns how many redraws happened meanwhile.
func _redraws_over_frames(draws: Array) -> int:
	var before: int = draws[0]
	await wait_process_frames(3)
	return draws[0] - before


# @test-link [[req_platform_and_performance_targets]]
func test_nothing_changed_nothing_redrawn() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	assert_gt(await _redraws_over_frames(drawn[1]), 0, "the first picture")
	assert_eq(await _redraws_over_frames(drawn[1]), 0, "nothing changed: the last picture stays")
	sim.tick += 10
	assert_eq(await _redraws_over_frames(drawn[1]), 0, "ticks alone change nothing drawn")


# @test-link [[req_platform_and_performance_targets]]
func test_each_frontier_change_redraws_once() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	await _redraws_over_frames(drawn[1])
	var changes := {
		"a switch flipped (its arrow and its signpost's)": func() -> void:
			sim.object_states[Frontier.SWITCH]["flipped"] = true,
		"a trapdoor opened": func() -> void:
			sim.object_states[Frontier.SWITCH]["trapdoor_shut"] = false,
		"a basket's weight": func() -> void:
			sim.object_states[Frontier.BASKET]["weight"] = 2,
		"a basket's phase": func() -> void:
			sim.object_states[Frontier.BASKET]["phase"] = FrontierSets.FULL,
		"a gate opened": func() -> void:
			sim.gate_states[Frontier.GATE]["open"] = true,
		"a gate's entrance closed (its lid)": func() -> void:
			sim.gate_states[Frontier.GATE]["entrance_closed"] = true,
		"the lasting mark": func() -> void:
			sim.frontier.celebration_done = true,
		"a new simulation": func() -> void:
			drawn[0].simulation = Frontier.sim(),
	}
	for what in changes:
		(changes[what] as Callable).call()
		assert_eq(await _redraws_over_frames(drawn[1]), 1, what)


# @test-link [[req_platform_and_performance_targets]]
func test_a_gate_opening_turns_the_arrows_along_the_new_loop() -> void:
	var sim := Frontier.sim()
	# On section 1's return route, where the loop runs down; once the gate
	# opens, the nearest loop is section 2's return route, running left.
	(sim.level.switches[Frontier.SWITCH] as Dictionary)["box"] = Rect2(-25, 175, 50, 50)
	var drawn := _drawn_view(sim)
	await _redraws_over_frames(drawn[1])
	assert_almost_eq(drawn[0].way_of(Frontier.SWITCH).distance_to(Vector2.DOWN), 0.0, 0.001)
	sim.train.open_gates.append(Frontier.GATE)
	assert_eq(await _redraws_over_frames(drawn[1]), 1)
	assert_almost_eq(drawn[0].way_of(Frontier.SWITCH).distance_to(Vector2.LEFT), 0.0, 0.001)


# @test-link [[req_platform_and_performance_targets]]
func test_the_reward_pulse_redraws_every_tick() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	sim.object_states[Frontier.BASKET]["phase"] = FrontierSets.REWARD
	sim.object_states[Frontier.BASKET]["since"] = sim.tick
	await _redraws_over_frames(drawn[1])
	assert_eq(await _redraws_over_frames(drawn[1]), 0, "no tick: the pulse stands still")
	sim.tick += 1
	assert_eq(await _redraws_over_frames(drawn[1]), 1, "a tick on: the pulse moved")


# @test-link [[req_platform_and_performance_targets]]
func test_the_celebration_redraws_every_frame_while_it_shows() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	await _redraws_over_frames(drawn[1])
	sim.frontier.celebration_since = sim.tick
	assert_gte(await _redraws_over_frames(drawn[1]), 3, "the burst moves with the view too")
	sim.tick += Frontier.CELEBRATION_TICKS
	assert_eq(await _redraws_over_frames(drawn[1]), 1, "the burst over: once more to take it away")


## The slot centres of basket t.basket (quota 3, box x -900 to -600, top at
## y -200): a row OUTLINE_LIFT above the box, centred, OUTLINE_RADIUS * 2 +
## OUTLINE_GAP apart.
func _slot_centres() -> Array:
	var step := FrontierView.OUTLINE_RADIUS * 2.0 + FrontierView.OUTLINE_GAP
	var y := Frontier.BASKET_BOX.position.y - FrontierView.OUTLINE_LIFT
	var mid := Frontier.BASKET_BOX.get_center().x
	return [Vector2(mid - step, y), Vector2(mid, y), Vector2(mid + step, y)]


## Where copies 0 to count - 1 of `shapes` are drawn.
func _instances(shapes: ShapeInstances) -> Array:
	var out := []
	for k in shapes.instance_count:
		out.append(shapes.instance_at(k))
	return out


# @test-link [[req_platform_and_performance_targets]]
func test_a_basket_slots_are_two_instanced_draws() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	var view: FrontierView = drawn[0]
	sim.object_states[Frontier.BASKET]["weight"] = 2
	await _redraws_over_frames(drawn[1])
	var slots := view.basket_slots(Frontier.BASKET)
	var discs: ShapeInstances = slots[0]
	var outlines: ShapeInstances = slots[1]
	var centres := _slot_centres()
	assert_eq(_instances(outlines), centres, "an outline per quota slot")
	assert_eq(_instances(discs), centres.slice(0, 2), "a disc per unit of weight, from the left")
	assert_eq(discs.self_modulate, FrontierView.FILL_COLOR)
	assert_eq(outlines.self_modulate, FrontierView.OUTLINE_COLOR)
	assert_eq(discs.points[0].x, FrontierView.OUTLINE_RADIUS, "draw_circle()'s disc of the outline radius")
	assert_eq(outlines.points.size(), 3 * 2 * FrontierView.OUTLINE_SEGMENTS, "draw_arc()'s antialiased polyline")
	assert_eq(view.get_children(), [discs, outlines, view.get_child(2)], "discs, outlines, then the overlay")
	assert_eq(view.get_child(2).name, &"Overlay")
	sim.object_states[Frontier.BASKET]["phase"] = FrontierSets.FIRED
	sim.object_states[Frontier.BASKET]["weight"] = 0
	await _redraws_over_frames(drawn[1])
	assert_eq(_instances(discs), centres, "fired: every slot filled")


# @test-link [[req_platform_and_performance_targets]]
func test_the_reward_pulse_draws_slot_by_slot_once_outlines_reach_the_next_disc() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	var view: FrontierView = drawn[0]
	sim.object_states[Frontier.BASKET]["phase"] = FrontierSets.REWARD
	sim.object_states[Frontier.BASKET]["weight"] = Frontier.QUOTA
	sim.object_states[Frontier.BASKET]["since"] = sim.tick
	await _redraws_over_frames(drawn[1])
	var discs: ShapeInstances = view.basket_slots(Frontier.BASKET)[0]
	var outlines: ShapeInstances = view.basket_slots(Frontier.BASKET)[1]
	assert_eq(discs.instance_count, Frontier.QUOTA, "at rest: instanced")
	assert_eq(discs.self_modulate, FrontierView.REWARD_COLOR)
	# 1 + 0.25 * sin(5 * 0.3): swollen to 17.5 px, the outline (+1.75) reaches
	# the next disc (36 px on, so from 18.5 px).
	sim.tick += 5
	await _redraws_over_frames(drawn[1])
	assert_eq(discs.instance_count, 0, "swollen: drawn slot by slot, disc then outline")
	assert_eq(outlines.instance_count, 0)
	sim.tick += 10
	await _redraws_over_frames(drawn[1])
	assert_eq(discs.instance_count, Frontier.QUOTA, "shrunk back: instanced again")


# @test-link [[req_platform_and_performance_targets]]
func test_a_new_level_remakes_the_basket_draws() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	var view: FrontierView = drawn[0]
	await _redraws_over_frames(drawn[1])
	view.simulation = Frontier.sim(3, true)
	await _redraws_over_frames(drawn[1])
	assert_eq(view.get_child_count(), 5, "two draws per basket, then the overlay")
	assert_eq(view.get_child(4).name, &"Overlay")
	assert_eq(view.basket_slots(Frontier.BASKET_2)[1].instance_count, 1)

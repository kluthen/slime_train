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
	var step := QuotaDisplay.OUTLINE_RADIUS * 2.0 + QuotaDisplay.OUTLINE_GAP
	var y := Frontier.BASKET_BOX.position.y - QuotaDisplay.OUTLINE_LIFT
	var mid := Frontier.BASKET_BOX.get_center().x
	return [Vector2(mid - step, y), Vector2(mid, y), Vector2(mid + step, y)]


## Where copies 0 to count - 1 of `shapes` are drawn.
func _instances(shapes: ShapeInstances) -> Array:
	var out := []
	for k in shapes.instance_count:
		out.append(shapes.instance_at(k))
	return out


## Puts slimes of `letters` (one species letter each) and sizes `sizes` in
## basket t.basket, in that id order, and sets its weight as a tick would.
## Returns their ids.
func _catch(sim: Simulation, letters: String, sizes: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in letters.length():
		var size: int = sizes[k]
		var at := Vector2(-880.0 + 20.0 * k, -SlimeBodies.ring_radius_for(size) - SlimeBodies.EDGE)
		out.append(sim.slimes.create(Species.from_letter(letters[k]), size, at, SlimeBodies.IN_BASKET))
	_reweigh(sim)
	return out


## Basket t.basket's weight from the slimes in it, as FrontierSets sets it
## each tick.
func _reweigh(sim: Simulation) -> void:
	var weight := 0
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.IN_BASKET:
			weight += sim.slimes.size_of(slime_id)
	sim.object_states[Frontier.BASKET]["weight"] = weight


## The species of each slice basket t.basket's pies show (-1: empty), read
## from the colours of the view's pie triangles, when every pie has 10
## slices (QuotaDisplay.PIE_SEGMENTS / 10 rim points a slice).
func _slices(view: FrontierView) -> Array:
	var triangles := view.pie_triangles(Frontier.BASKET)
	var per_slice := ceili(float(QuotaDisplay.PIE_SEGMENTS) / QuotaDisplay.PIE_SLICES) + 2
	var out := []
	var at := 0
	while at < triangles.colors.size() and triangles.colors[at] != QuotaDisplay.OUTLINE_COLOR:
		var color := triangles.colors[at]
		out.append(-1 if color == QuotaDisplay.EMPTY_SLICE_COLOR else Species.COLORS.find(color))
		at += per_slice
		if out.size() % QuotaDisplay.PIE_SLICES == 0:
			at += QuotaDisplay.PIE_SLICES * 4
	return out


# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_platform_and_performance_targets]]
func test_a_basket_slots_are_instanced_draws_in_the_caught_slimes_colours() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	var view: FrontierView = drawn[0]
	_catch(sim, "AB", [1, 1])
	await _redraws_over_frames(drawn[1])
	var slots := view.basket_slots(Frontier.BASKET)
	assert_eq(slots.size(), Species.COUNT + 1, "a disc draw per species, then the outlines")
	var red: ShapeInstances = slots[Species.from_letter("A")]
	var blue: ShapeInstances = slots[Species.from_letter("B")]
	var outlines: ShapeInstances = slots[Species.COUNT]
	var centres := _slot_centres()
	assert_eq(_instances(outlines), centres, "an outline per quota slot")
	assert_eq(_instances(red), [centres[0]], "the first slime caught fills the first slot")
	assert_eq(_instances(blue), [centres[1]], "the second the next, in its own colour")
	assert_eq(red.self_modulate, Species.color(Species.from_letter("A")))
	assert_eq(blue.self_modulate, Species.color(Species.from_letter("B")))
	assert_eq((slots[Species.from_letter("C")] as ShapeInstances).instance_count, 0)
	assert_eq(outlines.self_modulate, QuotaDisplay.OUTLINE_COLOR)
	assert_eq(red.points[0].x, QuotaDisplay.OUTLINE_RADIUS, "draw_circle()'s disc of the outline radius")
	assert_eq(outlines.points.size(), 3 * 2 * FrontierView.OUTLINE_SEGMENTS, "draw_arc()'s antialiased polyline")
	assert_eq(view.get_children().slice(0, Species.COUNT + 1), slots)
	assert_eq(view.get_child(Species.COUNT + 1).name, &"Overlay", "the draws, then the overlay")


# @test-link [[req_switch_basket_gate_set]]
func test_a_fired_basket_empties_its_outlines_with_the_release_then_shows_none() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	var view: FrontierView = drawn[0]
	var caught := _catch(sim, "DDD", [1, 1, 1])
	sim.object_states[Frontier.BASKET]["phase"] = FrontierSets.FIRED
	await _redraws_over_frames(drawn[1])
	var green: ShapeInstances = view.basket_slots(Frontier.BASKET)[Species.from_letter("D")]
	var outlines: ShapeInstances = view.basket_slots(Frontier.BASKET)[Species.COUNT]
	assert_eq(green.instance_count, 3, "fired, before its release: full")
	sim.slimes.set_state(caught[0], SlimeBodies.TRAIN)
	_reweigh(sim)
	await _redraws_over_frames(drawn[1])
	assert_eq(_instances(green), _slot_centres().slice(0, 2), "one released: one slot empties")
	assert_eq(outlines.instance_count, 3)
	sim.slimes.set_state(caught[1], SlimeBodies.TRAIN)
	sim.slimes.set_state(caught[2], SlimeBodies.TRAIN)
	_reweigh(sim)
	await _redraws_over_frames(drawn[1])
	assert_eq(green.instance_count, 0)
	assert_eq(outlines.instance_count, 0, "inert (fired and empty): the outlines are gone")


# @test-link [[req_switch_basket_gate_set]]
# @test-link [[req_platform_and_performance_targets]]
func test_the_reward_pulse_draws_slot_by_slot_once_outlines_reach_the_next_disc() -> void:
	var sim := Frontier.sim()
	var drawn := _drawn_view(sim)
	var view: FrontierView = drawn[0]
	_catch(sim, "BBB", [1, 1, 1])
	sim.object_states[Frontier.BASKET]["phase"] = FrontierSets.REWARD
	sim.object_states[Frontier.BASKET]["since"] = sim.tick
	await _redraws_over_frames(drawn[1])
	var discs: ShapeInstances = view.basket_slots(Frontier.BASKET)[Species.from_letter("B")]
	var outlines: ShapeInstances = view.basket_slots(Frontier.BASKET)[Species.COUNT]
	assert_eq(discs.instance_count, Frontier.QUOTA, "at rest: instanced")
	assert_eq(discs.self_modulate, Species.color(Species.from_letter("B")), "the slimes' colour")
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
	var per_basket := Species.COUNT + 1
	assert_eq(view.get_child_count(), 2 * per_basket + 1, "the draws of each basket, then the overlay")
	assert_eq(view.get_child(2 * per_basket).name, &"Overlay")
	assert_eq(view.basket_slots(Frontier.BASKET_2)[Species.COUNT].instance_count, 1)


## A simulation whose basket t.basket has a quota of 20 (two pies of 10).
func _pie_sim() -> Simulation:
	var sim := Frontier.sim()
	sim.level.baskets[Frontier.BASKET]["quota"] = 20
	return sim


# @test-link [[req_switch_basket_gate_set]]
func test_a_quota_above_10_draws_pies_filling_slice_by_slice_in_the_slimes_colours() -> void:
	var sim := _pie_sim()
	var drawn := _drawn_view(sim)
	var view: FrontierView = drawn[0]
	_catch(sim, "AAAAAAAAC", [1, 1, 1, 1, 1, 1, 1, 1, 3])
	await _redraws_over_frames(drawn[1])
	var red := Species.from_letter("A")
	var yellow := Species.from_letter("C")
	var expected := []
	for k in 20:
		expected.append(red if k < 8 else (yellow if k < 11 else -1))
	assert_eq(_slices(view), expected, "8 red, then the size-3 yellow across both pies")
	var rims: ShapeInstances = view.basket_slots(Frontier.BASKET)[Species.COUNT]
	var centres := QuotaDisplay.centres(Frontier.BASKET_BOX, 20)
	assert_eq(_instances(rims), Array(centres), "a rim per pie")
	assert_almost_eq(rims.reach, QuotaDisplay.PIE_RADIUS + QuotaDisplay.PIE_RIM_WIDTH, 2.0)
	for species in Species.COUNT:
		assert_eq((view.basket_slots(Frontier.BASKET)[species] as ShapeInstances).instance_count, 0,
				"no outline discs")


# @test-link [[req_switch_basket_gate_set]]
func test_the_reward_pulses_every_pie_and_the_release_empties_them_then_they_are_gone() -> void:
	var sim := _pie_sim()
	var drawn := _drawn_view(sim)
	var view: FrontierView = drawn[0]
	var letters := "BBBBBBBBBBBBBBBBBBBB"
	var sizes := []
	sizes.resize(20)
	sizes.fill(1)
	var caught := _catch(sim, letters, sizes)
	sim.object_states[Frontier.BASKET]["phase"] = FrontierSets.REWARD
	sim.object_states[Frontier.BASKET]["since"] = sim.tick
	await _redraws_over_frames(drawn[1])
	var rims: ShapeInstances = view.basket_slots(Frontier.BASKET)[Species.COUNT]
	var at_rest := rims.reach
	sim.tick += 5
	await _redraws_over_frames(drawn[1])
	assert_gt(rims.reach, at_rest + 5.0, "the reward swells the pies")
	assert_eq(rims.instance_count, 2, "both of them")
	# 1 + 0.25 * sin(5 * 0.3): the first slice's rim point from its pie's centre.
	var swollen := QuotaDisplay.PIE_RADIUS * (1.0 + 0.25 * sin(1.5))
	var first_pie := QuotaDisplay.centres(Frontier.BASKET_BOX, 20)[0]
	assert_almost_eq(view.pie_triangles(Frontier.BASKET).points[1].distance_to(first_pie), swollen, 0.01,
			"the slices with them")
	sim.object_states[Frontier.BASKET]["phase"] = FrontierSets.FIRED
	for k in 3:
		sim.slimes.set_state(caught[k], SlimeBodies.TRAIN)
	_reweigh(sim)
	await _redraws_over_frames(drawn[1])
	var shown := _slices(view)
	assert_eq(shown.count(-1), 3, "releasing: a slice empties with each slime")
	assert_eq(shown.slice(17), [-1, -1, -1], "from the end")
	for slime_id in caught:
		sim.slimes.set_state(slime_id, SlimeBodies.TRAIN)
	_reweigh(sim)
	await _redraws_over_frames(drawn[1])
	assert_eq(view.pie_triangles(Frontier.BASKET).points.size(), 0, "inert: the pies are gone")
	assert_eq(rims.instance_count, 0)

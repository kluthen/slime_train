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

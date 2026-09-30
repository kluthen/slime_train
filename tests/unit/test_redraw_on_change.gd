extends GutTest
## Screen-space nodes that redraw only when what they draw changes (chunk
## 22b): the edge buttons (EdgeButtons.refresh()) and test mode's overlay
## (TestModeOverlay.refresh()). A redraw skipped keeps the last picture on
## screen, so each must ask again whenever an input of its drawing changes.
# @test-link [[req_platform_and_performance_targets]]


## A game root as test mode's overlay reads it: just its simulation.
class GameHost:
	extends Node
	var simulation: Simulation


func _edge_buttons(sim: Simulation) -> EdgeButtons:
	var buttons := EdgeButtons.new()
	buttons.simulation = sim
	add_child_autofree(buttons)
	return buttons


func test_the_edge_buttons_redraw_once_then_not_while_nothing_changes() -> void:
	var buttons := _edge_buttons(Simulation.new(7))
	assert_true(buttons.refresh(), "the first frame draws")
	assert_false(buttons.refresh(), "nothing changed")
	assert_false(buttons.refresh(), "still nothing")


func test_the_edge_buttons_redraw_when_the_screen_changes() -> void:
	var sim := Simulation.new(7)
	var buttons := _edge_buttons(sim)
	buttons.refresh()
	sim.view.set_to(sim.view.centre, sim.view.zoom, Vector2(1600, 900))
	assert_true(buttons.refresh(), "the screen's size")
	assert_false(buttons.refresh())
	sim.view.px_per_mm = sim.view.px_per_mm * 2.0
	assert_true(buttons.refresh(), "the parent zone's height (the strips' top)")
	sim.view.set_to(Vector2(5000, 0), 0.7, Vector2(1600, 900))
	assert_false(buttons.refresh(), "panning and zooming don't move the strips")


func test_the_edge_buttons_redraw_when_shown_hidden_or_given_a_simulation() -> void:
	var sim := Simulation.new(7)
	var buttons := _edge_buttons(sim)
	buttons.refresh()
	sim.camera.edge_buttons_visible = false
	assert_true(buttons.refresh(), "hidden")
	assert_false(buttons.visible)
	sim.camera.edge_buttons_visible = true
	assert_true(buttons.refresh(), "shown again")
	assert_true(buttons.visible)
	buttons.simulation = null
	assert_true(buttons.refresh(), "no simulation")
	buttons.simulation = Simulation.new(8)
	assert_true(buttons.refresh(), "a new simulation")
	assert_false(buttons.refresh())


func _overlay() -> TestModeOverlay:
	var host := GameHost.new()
	host.simulation = Simulation.new(11)
	add_child_autofree(host)
	var test_mode := TestMode.new()
	test_mode.game = host
	var overlay := TestModeOverlay.new()
	overlay.test_mode = test_mode
	add_child_autofree(overlay)
	return overlay


func test_the_test_mode_overlay_redraws_once_then_not_while_nothing_changes() -> void:
	var overlay := _overlay()
	assert_true(overlay.refresh(), "the first frame draws")
	assert_false(overlay.refresh(), "nothing changed")
	assert_false(overlay.refresh(), "still nothing")


func test_the_test_mode_overlay_redraws_when_its_banner_changes() -> void:
	var overlay := _overlay()
	var sim: Simulation = overlay.test_mode.game.simulation
	overlay.refresh()
	sim.tick += 1
	assert_true(overlay.refresh(), "the tick")
	assert_false(overlay.refresh())
	overlay.test_mode.time_scale = 4.0
	assert_true(overlay.refresh(), "the time scale")
	assert_string_contains(overlay.banner(sim), "time x4")
	overlay.test_mode.game.simulation = Simulation.new(12)
	assert_true(overlay.refresh(), "another seed")
	assert_false(overlay.refresh())


func test_the_test_mode_overlay_redraws_when_a_finger_changes() -> void:
	var overlay := _overlay()
	var sim: Simulation = overlay.test_mode.game.simulation
	overlay.refresh()
	sim.fingers_down[0] = Vector2(100, 200)
	assert_true(overlay.refresh(), "a finger down")
	assert_false(overlay.refresh())
	sim.fingers_down[0] = Vector2(120, 200)
	assert_true(overlay.refresh(), "the finger moved")
	sim.fingers_down[1] = Vector2(300, 200)
	assert_true(overlay.refresh(), "a second finger")
	sim.fingers_down.erase(0)
	assert_true(overlay.refresh(), "a finger lifted")
	assert_false(overlay.refresh())


func test_the_test_mode_overlay_draws_once_for_an_unchanged_picture() -> void:
	var overlay := _overlay()
	await wait_process_frames(3)
	var drawn := overlay.draw_count
	assert_gt(drawn, 0, "it drew")
	await wait_process_frames(3)
	assert_eq(overlay.draw_count, drawn, "no redraw while nothing changed")
	overlay.test_mode.game.simulation.tick += 1
	await wait_process_frames(2)
	assert_eq(overlay.draw_count, drawn + 1, "one redraw for the new tick")

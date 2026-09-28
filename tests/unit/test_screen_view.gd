extends GutTest
## ScreenView (src/sim/screen_view.gd): the simulation's copy of what the
## player sees. Screen to level and back follow Camera2D's mapping; the
## screen size defaults to the project's 1152 x 648 and test mode is the one
## place a run sets it.

# @test-link [[req_controls_tap_zones]]


func test_defaults_to_the_project_viewport() -> void:
	var view := ScreenView.new()
	assert_eq(view.screen_size, Vector2(1152, 648))
	assert_eq(view.zoom, 1.0)
	assert_eq(view.screen_to_world(Vector2(100, 200)), Vector2(100, 200),
			"centred on the middle of the screen at zoom 1: the identity")


func test_screen_to_world_follows_the_camera() -> void:
	var view := ScreenView.new(Vector2(5000, -300), 1.0)
	assert_eq(view.screen_to_world(Vector2(576, 324)), Vector2(5000, -300), "the middle shows the centre")
	assert_eq(view.screen_to_world(Vector2(0, 0)), Vector2(5000 - 576, -300 - 324))


func test_zoom_shows_more_of_the_level() -> void:
	var view := ScreenView.new(Vector2(1000, 0), 0.5)
	assert_eq(view.screen_to_world(Vector2(1152, 324)), Vector2(1000 + 1152, 0),
			"at zoom 0.5 half a screen is a whole screen of level")
	assert_eq(view.world_width(), 2304.0)


func test_world_to_screen_is_the_inverse() -> void:
	var view := ScreenView.new(Vector2(5900, -400), 0.7, Vector2(1280, 720))
	for at in [Vector2(0, 0), Vector2(640, 360), Vector2(1200, 50)]:
		var back := view.world_to_screen(view.screen_to_world(at))
		assert_almost_eq(back.x, at.x, 0.001)
		assert_almost_eq(back.y, at.y, 0.001)


func test_a_bad_zoom_is_ignored() -> void:
	var view := ScreenView.new(Vector2.ZERO, 0.0)
	assert_eq(view.zoom, 1.0)


func test_test_mode_sets_the_screen_size() -> void:
	assert_eq(TestMode.from_config({"seed": 1}).screen_size, Vector2(1152, 648), "the default")
	var tm := TestMode.from_config({"seed": 1, "screen_size": [1280, 720]})
	assert_eq(tm.errors, PackedStringArray())
	assert_eq(tm.screen_size, Vector2(1280, 720))
	for bad in [[0, 720], [1280], "big", [1280, "720"]]:
		assert_false(TestMode.from_config({"seed": 1, "screen_size": bad}).errors.is_empty(),
				"%s is refused" % [bad])

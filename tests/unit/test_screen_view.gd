extends GutTest
## ScreenView (src/sim/screen_view.gd): the simulation's copy of what the
## player sees. Screen to level and back follow Camera2D's mapping; the
## screen size defaults to the project's 1152 x 648 and test mode is the one
## place a run sets it. Millimetres on the screen convert at the view's
## density, the reference phone's by default (chunk 23B). On a phone that
## density is the panel's physical one when it is plausible against the
## logical one Android reports, else the logical one (chunk 20).

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


# --- Millimetres on the screen (chunk 23B) -------------------------------------

func test_the_default_density_is_the_reference_phones() -> void:
	# The S20 FE: about 405 ppi, 1080 physical px for the viewport's 648.
	var view := ScreenView.new()
	assert_almost_eq(view.px_per_mm, 405.0 / 25.4 / (1080.0 / 648.0), 1e-6)
	assert_almost_eq(view.px_per_mm, 9.567, 0.001)
	assert_eq(view.px_per_mm, ScreenView.REFERENCE_PX_PER_MM)
	assert_eq(ScreenView.REFERENCE_PHONE_SIZE, Vector2(1440, 648),
			"2400 x 1080 at the viewport's 648 px height (aspect expand)")


func test_millimetres_convert_at_the_views_density() -> void:
	var view := ScreenView.new()
	assert_almost_eq(view.mm_to_px(7.0), 7.0 * ScreenView.REFERENCE_PX_PER_MM, 1e-6)
	view.px_per_mm = 4.0
	assert_eq(view.mm_to_px(7.0), 28.0, "a test (or the scene layer) sets the density")
	view.set_to(Vector2(100, 100), 0.5, Vector2(800, 600))
	assert_eq(view.px_per_mm, 4.0, "moving the view keeps the density")
	assert_eq(view.mm_to_px(7.0), 28.0, "screen millimetres ignore the zoom")


func test_the_density_comes_from_the_screens_ppi_and_scale() -> void:
	assert_almost_eq(ScreenView.px_per_mm_for(405.0, 1080.0 / 648.0), ScreenView.REFERENCE_PX_PER_MM, 1e-6)
	assert_almost_eq(ScreenView.px_per_mm_for(96.0, 1.0), 96.0 / 25.4, 1e-6, "a desktop monitor at scale 1")
	assert_almost_eq(ScreenView.px_per_mm_for(254.0, 2.0), 5.0, 1e-6, "more physical px per viewport px, fewer viewport px per mm")


# --- Physical density on the phone (chunk 20) ------------------------------------

# @test-link [[req_parent_gate_and_access]]
func test_a_plausible_physical_density_wins_over_the_logical_one() -> void:
	# The reference phone: about 405 physical ppi, a logical density of 480.
	assert_eq(ScreenView.dpi_for_mm(405.0, 480.0), 405.0, "the panel's own ppi")
	assert_eq(ScreenView.dpi_for_mm(264.0, 320.0), 264.0, "a tablet")
	assert_eq(ScreenView.dpi_for_mm(294.0, 240.0), 294.0, "logical below physical")


# @test-link [[req_parent_gate_and_access]]
func test_a_bogus_physical_density_falls_back_to_the_logical_one() -> void:
	assert_eq(ScreenView.dpi_for_mm(160.0, 480.0), 480.0, "a default 160 on a dense screen")
	assert_eq(ScreenView.dpi_for_mm(1000.0, 480.0), 480.0, "far above")
	assert_false(ScreenView.physical_dpi_plausible(160.0, 480.0))


# @test-link [[req_parent_gate_and_access]]
func test_an_unknown_physical_density_is_the_logical_one() -> void:
	assert_eq(ScreenView.dpi_for_mm(0.0, 480.0), 480.0, "0: unknown (the desktop stub)")
	assert_eq(ScreenView.dpi_for_mm(-3.0, 480.0), 480.0)
	assert_eq(ScreenView.dpi_for_mm(405.0, 0.0), 0.0, "no logical reading: nothing to check against, the caller refuses it")


# @test-link [[req_parent_gate_and_access]]
func test_the_plausibility_bounds_are_inclusive() -> void:
	var logical := 400.0
	assert_true(ScreenView.physical_dpi_plausible(logical * ScreenView.PHYSICAL_DPI_MIN_SHARE, logical))
	assert_true(ScreenView.physical_dpi_plausible(logical * ScreenView.PHYSICAL_DPI_MAX_SHARE, logical))
	assert_false(ScreenView.physical_dpi_plausible(logical * ScreenView.PHYSICAL_DPI_MIN_SHARE - 1.0, logical))
	assert_false(ScreenView.physical_dpi_plausible(logical * ScreenView.PHYSICAL_DPI_MAX_SHARE + 1.0, logical))

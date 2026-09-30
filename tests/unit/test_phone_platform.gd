extends GutTest
## The phone's services (src/platform/phone_platform.gd) as the desktop stub
## every test and desktop run gets: every call does nothing, nothing is
## pinned or secure, a credential prompt answers false on the next idle
## frame, the safe area is the window, the physical density unknown (0). On
## the phone the density for millimetres is the plugin's physical one when
## plausible, else the logical one (chunk 20). And the back gesture's excluded edge
## strips (ScreenPinning.edge_strip_exclusions): full-height bands on the
## window's edges, as wide as the strips shown through the stretch.

# @test-link [[req_screen_pinning]]

## Stands in for the Android plugin singleton: its physical density is `dpi`.
class FakePlugin:
	extends RefCounted
	signal credential_finished(ok: bool)
	var dpi := 0.0

	func getPhysicalDpi() -> float:
		return dpi


## Counts the credential_finished answers.
var answers: Array[bool] = []


func before_each() -> void:
	answers.clear()


func test_this_desktop_build_gets_the_stub() -> void:
	var platform := PhonePlatform.for_this_build()
	assert_false(Engine.has_singleton(PhonePlatform.SINGLETON), "no Android plugin on the desktop")
	assert_false(platform.is_phone())


func test_the_stub_does_nothing_and_is_never_pinned_nor_secure() -> void:
	var platform := PhonePlatform.new()
	platform.request_pinning()
	assert_false(platform.is_pinned(), "asking changes nothing")
	platform.stop_pinning()
	platform.move_to_background()
	var rects: Array[Rect2i] = [Rect2i(0, 0, 10, 10)]
	platform.set_back_gesture_exclusion(rects)
	assert_false(platform.is_pinned())
	assert_false(platform.is_device_secure())


func test_the_stub_answers_a_credential_prompt_false_on_the_next_frame() -> void:
	var platform := PhonePlatform.new()
	platform.credential_finished.connect(func(ok: bool) -> void: answers.append(ok))
	platform.confirm_credential("Parent code", "Confirm it's you")
	assert_eq(answers, [] as Array[bool], "deferred, not at once")
	await wait_physics_frames(2)
	assert_eq(answers, [false] as Array[bool], "once, false")


func test_the_stub_safe_area_is_the_window() -> void:
	var platform := PhonePlatform.new()
	assert_eq(platform.safe_area(), Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()))


# @test-link [[req_parent_gate_and_access]]
func test_the_stub_physical_density_is_unknown_and_its_density_the_logical_one() -> void:
	var platform := PhonePlatform.new()
	assert_eq(platform.physical_dpi(), 0.0, "0: unknown")
	assert_eq(platform.screen_dpi(), float(DisplayServer.screen_get_dpi()), "the display's logical density")


# @test-link [[req_parent_gate_and_access]]
func test_on_the_phone_a_plausible_physical_density_is_used() -> void:
	var plugin := FakePlugin.new()
	var platform := PhonePlatform.new(plugin)
	var logical := float(DisplayServer.screen_get_dpi())
	assert_gt(logical, 0.0, "the headless display reports a density")
	plugin.dpi = logical * 0.85
	assert_eq(platform.physical_dpi(), logical * 0.85, "the plugin's reading")
	assert_eq(platform.screen_dpi(), logical * 0.85, "plausible: the panel's own")
	plugin.dpi = logical * 0.2
	assert_eq(platform.screen_dpi(), logical, "bogus: the logical one")


func test_the_excluded_strips_are_full_height_on_the_window_edges() -> void:
	# canvas_items + expand on a 2400 x 1080 phone: 1152 x 648 grows to
	# 1440 x 648 viewport px, scaled by 1080 / 648 into the window.
	var scale := 1080.0 / 648.0
	var view := Vector2(1440, 648)
	var rects := ScreenPinning.edge_strip_exclusions(view, Transform2D().scaled(Vector2(scale, scale)), Vector2i(2400, 1080))
	assert_eq(rects.size(), 2)
	assert_eq(rects[0], Rect2i(0, 0, 240, 1080), "left: a tenth of the width, top to bottom")
	assert_eq(rects[1], Rect2i(2160, 0, 240, 1080), "right: a tenth of the width, top to bottom")


func test_the_excluded_strips_round_outward_and_reach_the_edges() -> void:
	# A fractional scale, and an offset (letterboxing): the bands still start
	# at the window's edges and cover the strips' last partial pixels.
	var to_window := Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2(3.0, 0.0))
	var rects := ScreenPinning.edge_strip_exclusions(Vector2(1001, 500), to_window, Vector2i(506, 250))
	# Left strip ends at 3 + 100.1 * 0.5 = 53.05 -> 54; right starts at
	# 3 + 900.9 * 0.5 = 453.45 -> 453.
	assert_eq(rects[0], Rect2i(0, 0, 54, 250))
	assert_eq(rects[1], Rect2i(453, 0, 53, 250))


func test_the_identity_transform_keeps_viewport_pixels() -> void:
	var rects := ScreenPinning.edge_strip_exclusions(Vector2(1152, 648), Transform2D.IDENTITY, Vector2i(1152, 648))
	var left := TapDispatcher.edge_button_rect(-1, _view(Vector2(1152, 648)))
	assert_eq(rects[0].size.x, ceili(left.size.x), "as wide as the tap zone's strip")
	assert_eq(rects[0].size.y, 648, "but the full height, parent zone included")
	assert_eq(rects[1].end.x, 1152)


func _view(size: Vector2) -> ScreenView:
	var view := ScreenView.new()
	view.screen_size = size
	return view

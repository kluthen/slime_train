extends GutTest
## The display's safe area in the game's viewport coordinates (chunk 20):
## SafeArea.in_viewport() turns the platform's safe area (screen pixels, the
## window edge to edge on the phone) into a rect of the viewport through the
## stretch's transform, clipped to the viewport; ScreenView keeps it as
## insets from the screen's edges and gives it back as safe_rect(). On the
## reference phone (2400 x 1080 physical px showing 1440 x 648 viewport px) a
## 100 px cut-out is 60 viewport px.

# @test-link [[req_controls_tap_zones]]
# @test-link [[req_parent_gate_and_access]]

## The reference phone's window, its viewport and the stretch between them.
const WINDOW := Rect2i(0, 0, 2400, 1080)
const VIEW := Vector2(1440, 648)
const SCALE := 1080.0 / 648.0


## The stretch's viewport-to-window transform on the reference phone.
func _to_window() -> Transform2D:
	return Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, Vector2.ZERO)


## Asserts `rect` is `expected`, to a thousandth of a pixel.
func _assert_rect(rect: Rect2, expected: Rect2, what: String) -> void:
	assert_almost_eq(rect.position.x, expected.position.x, 0.001, what + ": left")
	assert_almost_eq(rect.position.y, expected.position.y, 0.001, what + ": top")
	assert_almost_eq(rect.end.x, expected.end.x, 0.001, what + ": right")
	assert_almost_eq(rect.end.y, expected.end.y, 0.001, what + ": bottom")


func test_a_cut_out_on_the_left_insets_the_left_edge() -> void:
	var rect := SafeArea.in_viewport(Rect2i(100, 0, 2300, 1080), WINDOW, _to_window(), VIEW)
	_assert_rect(rect, Rect2(60, 0, 1380, 648), "100 px on the left")


func test_a_cut_out_on_the_right_insets_the_right_edge() -> void:
	var rect := SafeArea.in_viewport(Rect2i(0, 0, 2300, 1080), WINDOW, _to_window(), VIEW)
	_assert_rect(rect, Rect2(0, 0, 1380, 648), "100 px on the right")


func test_a_desktop_window_anywhere_on_its_screen_is_all_safe() -> void:
	var window := Rect2i(300, 200, 1152, 648)
	var rect := SafeArea.in_viewport(window, window, Transform2D.IDENTITY, Vector2(1152, 648))
	_assert_rect(rect, Rect2(0, 0, 1152, 648), "the window's own rect")


func test_a_safe_area_past_the_window_is_clipped_to_the_viewport() -> void:
	var rect := SafeArea.in_viewport(Rect2i(-50, -50, 3000, 1200), WINDOW, _to_window(), VIEW)
	_assert_rect(rect, Rect2(Vector2.ZERO, VIEW), "no more than the viewport")


func test_no_usable_safe_area_is_the_whole_viewport() -> void:
	_assert_rect(SafeArea.in_viewport(Rect2i(), WINDOW, _to_window(), VIEW), Rect2(Vector2.ZERO, VIEW),
			"a headless display reports no area")
	_assert_rect(SafeArea.in_viewport(Rect2i(5000, 0, 100, 100), WINDOW, _to_window(), VIEW),
			Rect2(Vector2.ZERO, VIEW), "an area off the window")


func test_the_view_is_all_safe_by_default() -> void:
	var view := ScreenView.new(Vector2.ZERO, 1.0, VIEW)
	assert_eq(view.safe_rect(), Rect2(Vector2.ZERO, VIEW))


func test_the_view_keeps_the_insets_as_its_size_changes() -> void:
	var view := ScreenView.new(Vector2.ZERO, 1.0, VIEW)
	view.set_safe_insets(Vector2(60, 0), Vector2(0, 10))
	assert_eq(view.safe_rect(), Rect2(60, 0, 1380, 638))
	view.set_to(Vector2.ZERO, 1.0, Vector2(1152, 648))
	assert_eq(view.safe_rect(), Rect2(60, 0, 1092, 638), "the same insets on the new size")


func test_insets_wider_than_the_screen_leave_an_empty_rect_inside_it() -> void:
	var view := ScreenView.new(Vector2.ZERO, 1.0, Vector2(100, 100))
	view.set_safe_insets(Vector2(80, 0), Vector2(80, 0))
	var rect := view.safe_rect()
	assert_eq(rect.size.x, 0.0, "nothing left")
	assert_true(Rect2(0, 0, 100, 100).encloses(rect), "still on the screen")


func test_the_insets_from_the_platform_reach_the_view() -> void:
	var insets := SafeArea.insets_of(Rect2(60, 0, 1380, 648), VIEW)
	assert_eq(insets[0], Vector2(60, 0), "left and top")
	assert_eq(insets[1], Vector2(0, 0), "right and bottom")

extends GutTest
## The code pads fit short screens (chunk 20): the pad (ParentPad) keeps its
## preferred keys and gaps while they fit the height it has, else shrinks
## them together, never below the floors (keys 9 x 9 mm, 2 mm apart:
## specs/tuning.md, D109). A surface with a heading row over the pad
## (ParentLayout.rows_over_pad) shrinks the gap under the row, then the row,
## when even the pad at its floors doesn't fit under them.

# @test-link [[req_parent_gate_and_access]]

## The pad's height at its preferred and at its floor sizes, mm.
const PREFERRED_MM := 4.0 * ParentPad.KEY_MM + 3.0 * ParentPad.GAP_MM
const FLOOR_MM := 4.0 * ParentPad.MIN_KEY_MM + 3.0 * ParentPad.MIN_GAP_MM


func test_the_floors_are_the_rules() -> void:
	assert_eq(ParentPad.MIN_KEY_MM, 9.0, "keys at least 9 x 9 mm")
	assert_eq(ParentPad.MIN_GAP_MM, 2.0, "at least 2 mm apart")
	assert_eq(PREFERRED_MM, 47.5)
	assert_eq(FLOOR_MM, 42.0)


func test_the_preferred_sizes_while_they_fit() -> void:
	assert_eq(ParentPad.sizes_mm(INF), Vector2(ParentPad.KEY_MM, ParentPad.GAP_MM), "no limit")
	assert_eq(ParentPad.sizes_mm(PREFERRED_MM), Vector2(ParentPad.KEY_MM, ParentPad.GAP_MM), "just fits")
	assert_eq(ParentPad.sizes_mm(60.0), Vector2(ParentPad.KEY_MM, ParentPad.GAP_MM), "never bigger")


func test_a_shorter_room_shrinks_keys_and_gaps_to_fit_it() -> void:
	var sizes := ParentPad.sizes_mm(45.0)
	assert_almost_eq(4.0 * sizes.x + 3.0 * sizes.y, 45.0, 1e-4, "the pad is as tall as its room")
	assert_between(sizes.x, ParentPad.MIN_KEY_MM, ParentPad.KEY_MM)
	assert_between(sizes.y, ParentPad.MIN_GAP_MM, ParentPad.GAP_MM)


func test_never_below_the_floors() -> void:
	assert_eq(ParentPad.sizes_mm(FLOOR_MM), Vector2(ParentPad.MIN_KEY_MM, ParentPad.MIN_GAP_MM))
	assert_eq(ParentPad.sizes_mm(30.0), Vector2(ParentPad.MIN_KEY_MM, ParentPad.MIN_GAP_MM), "it overflows instead")
	assert_eq(ParentPad.sizes_mm(0.0), Vector2(ParentPad.MIN_KEY_MM, ParentPad.MIN_GAP_MM))


func test_the_pads_size_in_viewport_pixels() -> void:
	var view := ScreenView.new()
	view.px_per_mm = 10.0
	assert_eq(ParentPad.size_px(view), Vector2(350.0, 475.0), "preferred: 3 x 10 + 2 x 2.5 by 47.5 mm")
	assert_eq(ParentPad.size_px(view, 420.0), Vector2(310.0, 420.0), "floors: 3 x 9 + 2 x 2 by 42 mm")
	var fitted := ParentPad.size_px(view, 450.0)
	assert_almost_eq(fitted.y, 450.0, 1e-3, "fits its room")


func test_a_laid_out_pad_keeps_its_fitted_sizes() -> void:
	var view := ScreenView.new()
	view.px_per_mm = 10.0
	var pad: ParentPad = autofree(ParentPad.new())
	pad.lay_out(Vector2(100, 50), view, 420.0)
	assert_eq(pad.key_px, 90.0)
	assert_eq(pad.gap_px, 20.0)
	assert_eq(pad.size, Vector2(310.0, 420.0))
	assert_eq(pad.key_rect("0"), Rect2(Vector2(100 + 110, 50 + 3 * 110), Vector2(90, 90)))
	pad.lay_out(Vector2.ZERO, view)
	assert_eq(pad.key_px, 100.0, "no room given: the preferred sizes")
	assert_eq(pad.gap_px, 25.0)


func test_the_heading_row_keeps_its_size_while_the_pad_fits_under_it() -> void:
	var view := ScreenView.new()
	view.px_per_mm = 10.0
	var rows := ParentLayout.rows_over_pad(0.0, 1000.0, ParentSettings.LINE_MM, view)
	assert_eq(rows, Vector2(view.mm_to_px(ParentSettings.TARGET_MM), view.mm_to_px(ParentSettings.GAP_MM)))
	# 10 + 3 + 42 mm: the pad fits at its floors, the rows stay.
	rows = ParentLayout.rows_over_pad(0.0, 550.0, ParentSettings.LINE_MM, view)
	assert_eq(rows, Vector2(100.0, 30.0))


func test_the_gap_then_the_row_shrink_for_the_pad_at_its_floors() -> void:
	var view := ScreenView.new()
	view.px_per_mm = 10.0
	# 54.5 mm: 0.5 mm short, taken from the gap.
	assert_eq(ParentLayout.rows_over_pad(0.0, 545.0, ParentSettings.LINE_MM, view), Vector2(100.0, 25.0))
	# 52 mm: 3 mm short, the gap at 2 mm, the row 8 mm.
	assert_eq(ParentLayout.rows_over_pad(0.0, 520.0, ParentSettings.LINE_MM, view), Vector2(80.0, 20.0))
	# A row of tap targets stops at 9 mm.
	assert_eq(ParentLayout.rows_over_pad(0.0, 520.0, ParentPad.MIN_KEY_MM, view), Vector2(90.0, 20.0))
	# Nothing left to take: the floors (the pad overflows).
	assert_eq(ParentLayout.rows_over_pad(0.0, 300.0, ParentSettings.LINE_MM, view), Vector2(50.0, 20.0))

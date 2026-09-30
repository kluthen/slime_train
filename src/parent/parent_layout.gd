class_name ParentLayout
extends RefCounted
## Where the parent surfaces sit and how big they are, in viewport pixels,
## from the screen's millimetres (ScreenView.px_per_mm) so the targets have
## the same physical size on every phone. Placeholder look (plain Godot
## controls); the design tokens are ux-writer's, still to come, and will
## replace these constants.
##
## The parent buttons: a row hanging from the top-right corner, one slot per
## button counted from the right (slot 0: settings at the far right, slot 1:
## leave, slot 2: wake early). Every slot keeps its place whether or not its
## button shows, so nothing moves under a finger (ux D6 Q21).
##
## The safe area (chunk 20): the world is drawn edge to edge, but everything
## a parent reads or taps is inside the display's safe area
## (ScreenView.safe_rect(), clear of a cut-out or a rounded corner): the
## buttons' row hangs from the safe area's top-right corner, the code
## prompt's panel is centred in it, and the surfaces that fill the screen lay
## their content out in surface_rect() while their background fills the
## screen. The tap zones that open them (the parent zone) stay on the
## screen's edges. On the desktop the safe area is the whole screen.
##
## Short screens (chunk 20): the code pad (ParentPad) fits the height it has,
## down to its floors; on a surface with a heading row over the pad
## (settings, setup, the new code), when even the pad at its floors doesn't
## fit, the gap under the row and then the row shrink just enough
## (rows_over_pad(), proposed), never below 2 mm and the row's own floor.
# @spec-link [[req_parent_gate_and_access]]

## A parent button's size, mm (at least 9 x 9 mm: specs/tuning.md, D109). Wider
## than tall so its word fits.
const BUTTON_WIDTH_MM := 14.0
const BUTTON_HEIGHT_MM := 10.0
## The space between two parent buttons, mm (at least 2 mm: D109).
const BUTTON_GAP_MM := 3.0
## The row's distance from the safe area's top and right edges, mm.
const EDGE_MM := 1.0
## The text's size on the parent surfaces, mm.
const FONT_MM := 2.0
## The code prompt's panel: its share of the screen's width (ux D6 Q22: about
## two thirds of the width), centred.
const PROMPT_WIDTH_SHARE := 2.0 / 3.0
## The space inside the panel's edges and between its columns, mm.
const PROMPT_MARGIN_MM := 2.5
## The scrim that dims the world under a surface that covers it.
const SCRIM_COLOR := Color(0.0, 0.0, 0.0, 0.5)


## The rect of the parent button in `slot` (0 = far right) on `view`'s
## screen, from the safe area's top-right corner.
static func button_rect(slot: int, view: ScreenView) -> Rect2:
	var safe := view.safe_rect()
	var size := Vector2(view.mm_to_px(BUTTON_WIDTH_MM), view.mm_to_px(BUTTON_HEIGHT_MM))
	var step := size.x + view.mm_to_px(BUTTON_GAP_MM)
	var right := safe.end.x - view.mm_to_px(EDGE_MM)
	return Rect2(Vector2(right - size.x - slot * step, safe.position.y + view.mm_to_px(EDGE_MM)), size)


## The bottom of the parent buttons' row, viewport pixels.
static func row_bottom(view: ScreenView) -> float:
	return button_rect(0, view).end.y


## The parent surfaces' font size, whole viewport pixels.
static func font_px(view: ScreenView) -> int:
	return roundi(view.mm_to_px(FONT_MM))


## The code prompt's panel on `view`'s screen: two thirds of the safe area's
## width, as tall as the pad (ParentPad) and its margins, centred in the safe
## area below the parent zone (which stays the parent zone's: a tap there
## closes the prompt).
static func prompt_rect(view: ScreenView) -> Rect2:
	var safe := view.safe_rect()
	var top := maxf(TapDispatcher.parent_zone_height(view), safe.position.y)
	var below := safe.end.y - top
	var height := minf(ParentPad.size_px(view).y + 2.0 * view.mm_to_px(PROMPT_MARGIN_MM), below)
	var size := Vector2(safe.size.x * PROMPT_WIDTH_SHARE, height)
	return Rect2(Vector2(safe.position.x + (safe.size.x - size.x) * 0.5, top + (below - height) * 0.5), size)


## The heading row's height and the gap under it, viewport pixels, on a
## surface whose content runs from `top` to `bottom` (viewport pixels) with
## a pad (ParentPad) under the row: settings' TARGET_MM and GAP_MM while the
## pad at its floors fits under them; else the gap shrinks first, down to
## ParentPad.MIN_GAP_MM, then the row, down to `row_floor_mm` (9 mm for a
## row of tap targets; a line of text for a heading), just enough for it.
# @spec-link [[req_parent_gate_and_access]]
static func rows_over_pad(top: float, bottom: float, row_floor_mm: float, view: ScreenView) -> Vector2:
	var row := view.mm_to_px(ParentSettings.TARGET_MM)
	var gap := view.mm_to_px(ParentSettings.GAP_MM)
	var short := row + gap + ParentPad.size_px(view, 0.0).y - (bottom - top)
	if short <= 0.0:
		return Vector2(row, gap)
	var gap_cut := minf(short, gap - view.mm_to_px(ParentPad.MIN_GAP_MM))
	var row_cut := minf(short - gap_cut, row - view.mm_to_px(row_floor_mm))
	return Vector2(row - row_cut, gap - gap_cut)


## Where a surface that fills `view`'s screen lays out its content (text,
## keys, buttons), its margins inside it: the safe area. Its background still
## fills the whole screen.
static func surface_rect(view: ScreenView) -> Rect2:
	return view.safe_rect()

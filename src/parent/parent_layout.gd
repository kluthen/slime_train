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
# @spec-link [[req_parent_gate_and_access]]

## A parent button's size, mm (at least 9 x 9 mm: specs/tuning.md, D109). Wider
## than tall so its word fits.
const BUTTON_WIDTH_MM := 14.0
const BUTTON_HEIGHT_MM := 10.0
## The space between two parent buttons, mm (at least 2 mm: D109).
const BUTTON_GAP_MM := 3.0
## The row's distance from the screen's top and right edges, mm.
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


## The rect of the parent button in `slot` (0 = far right) on `view`'s screen.
static func button_rect(slot: int, view: ScreenView) -> Rect2:
	var size := Vector2(view.mm_to_px(BUTTON_WIDTH_MM), view.mm_to_px(BUTTON_HEIGHT_MM))
	var step := size.x + view.mm_to_px(BUTTON_GAP_MM)
	var right := view.screen_size.x - view.mm_to_px(EDGE_MM)
	return Rect2(Vector2(right - size.x - slot * step, view.mm_to_px(EDGE_MM)), size)


## The bottom of the parent buttons' row, viewport pixels.
static func row_bottom(view: ScreenView) -> float:
	return button_rect(0, view).end.y


## The parent surfaces' font size, whole viewport pixels.
static func font_px(view: ScreenView) -> int:
	return roundi(view.mm_to_px(FONT_MM))


## The code prompt's panel on `view`'s screen: two thirds of the width, as
## tall as the pad (ParentPad) and its margins, centred in the space below the
## parent zone (which stays the parent zone's: a tap there closes the prompt).
static func prompt_rect(view: ScreenView) -> Rect2:
	var zone := TapDispatcher.parent_zone_height(view)
	var below := view.screen_size.y - zone
	var height := minf(ParentPad.size_px(view).y + 2.0 * view.mm_to_px(PROMPT_MARGIN_MM), below)
	var size := Vector2(view.screen_size.x * PROMPT_WIDTH_SHARE, height)
	return Rect2(Vector2((view.screen_size.x - size.x) * 0.5, zone + (below - height) * 0.5), size)

class_name QuotaDisplay
extends RefCounted
## How a basket shows its quota (master spec 5.4, item 24.2), as pure
## functions of the quota, the slimes caught and the basket's box, so the
## layout is tested without drawing (tests/unit/test_quota_display.gd);
## FrontierView draws it.
##
## A quota of MAX_OUTLINES or less: one slime outline per unit of weight, in
## a row above the box. Above it: one **quota pie** per PIE_SLICES of weight,
## the last holding the rest (15: a pie of 10 and one of 5; 60: six of 10),
## each with one slice per unit of weight. Both are "groups" here: an outline
## is a group of one unit, a pie a group of its slice count. The units fill
## in order, the first group first, each in the colour of the slime that
## fills it (a size-3 slime fills three, across two pies when it has to), so
## a full pie stays full while the basket fills.
##
## Readable: a pie is PIE_RADIUS across 2, at least 6 mm on the reference
## phone's screen at the test level's `s3.frame.basket` zoom (0.8), and the
## test level's pie rows fit within their baskets' widths (the layout tests
## work both out from ScreenView's reference density and the level).
## Placeholder art until ux-writer draws the pies (ux D4 Q10): a faint disc
## per slice, the filled ones in the species colour, thin dividers between
## slices, the rim drawn by FrontierView as the outlines' antialiased ring.
# @spec-link [[req_switch_basket_gate_set]]

## The largest quota shown as outlines; above it, pies.
const MAX_OUTLINES := 10
## The units of weight a pie holds (the last pie holds the rest).
const PIE_SLICES := 10
## An outline's radius, the gap between two and how far above the basket's
## box the row's centres sit, level pixels.
const OUTLINE_RADIUS := 14.0
const OUTLINE_GAP := 8.0
const OUTLINE_LIFT := 30.0
## A pie's radius, the gap between two and how far above the box the row's
## centres sit, level pixels. 80 px across is 64 viewport px at zoom 0.8,
## 6.7 mm on the reference phone (about 9.57 viewport px per mm), over the
## spec's 6 mm (proposed); six pies take 560 px of basket 3's 668.
const PIE_RADIUS := 40.0
const PIE_GAP := 16.0
const PIE_LIFT := 56.0
## The rim's line width (both outlines and pies), level pixels.
const OUTLINE_WIDTH := 2.0
const PIE_RIM_WIDTH := 3.0
## A divider's width between two slices, level pixels.
const PIE_DIVIDER_WIDTH := 2.0
## Points on a whole pie's rim (spread over its slices, at least 2 a slice).
const PIE_SEGMENTS := 40
## The rim and dividers' colour, and an empty slice's (placeholder art).
const OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const EMPTY_SLICE_COLOR := Color(1.0, 1.0, 1.0, 0.15)


## Whether a quota of `quota` shows as pies (above MAX_OUTLINES).
# @spec-link [[req_switch_basket_gate_set]]
static func uses_pies(quota: int) -> bool:
	return quota > MAX_OUTLINES


## The units each group stands for, left to right: 1 per outline, or each
## pie's slice count (PIE_SLICES, the last the rest).
# @spec-link [[req_switch_basket_gate_set]]
static func groups(quota: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not uses_pies(quota):
		out.resize(maxi(quota, 0))
		out.fill(1)
		return out
	var left := quota
	while left > 0:
		out.append(mini(PIE_SLICES, left))
		left -= PIE_SLICES
	return out


## How many units of each group are filled with `filled` units in the
## basket (clamped to 0 and the quota), the first group first.
# @spec-link [[req_switch_basket_gate_set]]
static func filled_per_group(quota: int, filled: int) -> PackedInt32Array:
	var out := groups(quota)
	var left := clampi(filled, 0, quota)
	for g in out.size():
		var take := mini(out[g], left)
		out[g] = take
		left -= take
	return out


## The species filling each of the quota's units, in order (-1: empty): the
## slimes caught, given as their species and sizes in the order they fill
## (FrontierView: ascending id), each filling as many units as its size, the
## last cut off at the quota.
# @spec-link [[req_switch_basket_gate_set]]
static func unit_species(quota: int, species: PackedInt32Array, sizes: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(maxi(quota, 0))
	out.fill(-1)
	var at := 0
	for k in species.size():
		for _unit in sizes[k]:
			if at >= quota:
				return out
			out[at] = species[k]
			at += 1
	return out


## A group's radius at rest: an outline's or a pie's.
static func radius(quota: int) -> float:
	return PIE_RADIUS if uses_pies(quota) else OUTLINE_RADIUS


## From one group's centre to the next, level pixels.
static func step(quota: int) -> float:
	return radius(quota) * 2.0 + (PIE_GAP if uses_pies(quota) else OUTLINE_GAP)


## The row's width at rest, from the first group's left edge to the last's
## right edge, level pixels.
# @spec-link [[req_switch_basket_gate_set]]
static func row_width(quota: int) -> float:
	var count := groups(quota).size()
	return 0.0 if count == 0 else step(quota) * (count - 1) + radius(quota) * 2.0


## The groups' centres for a basket of box `box`: a row centred over the
## box, OUTLINE_LIFT (outlines) or PIE_LIFT (pies) above its top.
# @spec-link [[req_switch_basket_gate_set]]
static func centres(box: Rect2, quota: int) -> PackedVector2Array:
	var count := groups(quota).size()
	var gap := step(quota)
	var left := box.get_center().x - gap * (count - 1) * 0.5
	var y := box.position.y - (PIE_LIFT if uses_pies(quota) else OUTLINE_LIFT)
	var out := PackedVector2Array()
	for g in count:
		out.append(Vector2(left + gap * g, y))
	return out


## A triangle list with a colour per point, which FrontierView hands to the
## renderer in one call (RenderingServer.canvas_item_add_triangle_array):
## every pie's slices and dividers, in draw order.
class Triangles:
	extends RefCounted
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	## Empties the list, keeping its memory.
	func clear() -> void:
		points.resize(0)
		colors.resize(0)
		indices.resize(0)

	## Adds a pie at `centre` of radius `r` and `slices` slices, slice k
	## filled by species `units[first + k]` (-1: empty): a fan per slice,
	## clockwise from the top, then a divider between each two slices.
	func add_pie(centre: Vector2, r: float, slices: int, units: PackedInt32Array, first: int) -> void:
		var per_slice := maxi(2, ceili(float(PIE_SEGMENTS) / slices))
		for k in slices:
			var unit := units[first + k]
			var color := EMPTY_SLICE_COLOR if unit < 0 else Species.color(unit)
			var base := points.size()
			points.append(centre)
			colors.append(color)
			for i in per_slice + 1:
				points.append(centre + Vector2.from_angle(_angle(slices, k + float(i) / per_slice)) * r)
				colors.append(color)
			for i in per_slice:
				indices.append_array([base, base + 1 + i, base + 2 + i])
		if slices < 2:
			return
		for k in slices:
			var way := Vector2.from_angle(_angle(slices, k))
			var side := way.orthogonal() * (PIE_DIVIDER_WIDTH * 0.5)
			var base := points.size()
			points.append_array([centre - side, centre + side, centre + way * r + side, centre + way * r - side])
			for _corner in 4:
				colors.append(OUTLINE_COLOR)
			indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	## The angle at `at` slices round a pie of `slices`, radians: 0 at the
	## top, growing clockwise on screen (y points down).
	static func _angle(slices: int, at: float) -> float:
		return -PI * 0.5 + TAU * at / slices

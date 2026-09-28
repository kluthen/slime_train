@tool
class_name PlaceholderArt
extends RefCounted
## Greybox drawing shared by the level components until the real art: species
## colours, the size-1 slime radius, labelled boxes and route lines. Drawn in
## the editor too (the components are @tool), so a level can be laid out by
## eye.

## A size-1 slime's radius in level pixels. A placeholder until the slime body
## (chunk 5) settles it.
const SLIME_RADIUS := 24.0
## Placeholder species colours (specs/levels/test/README.md, "Conventions").
const SPECIES_COLORS := {
	"A": Color(0.9, 0.25, 0.25),
	"B": Color(0.3, 0.5, 0.95),
	"C": Color(0.95, 0.85, 0.25),
	"D": Color(0.3, 0.8, 0.35),
	"E": Color(0.65, 0.35, 0.85),
}
const LABEL_SIZE := 14
const LABEL_COLOR := Color(1, 1, 1, 0.8)


static func species_color(species: String) -> Color:
	return SPECIES_COLORS.get(species, Color.WHITE)


## A box of `size` centred on the item's origin, with a label above it.
static func draw_box(item: CanvasItem, size: Vector2, color: Color, label: String, filled := false) -> void:
	var rect := Rect2(-size / 2.0, size)
	if filled:
		item.draw_rect(rect, Color(color, 0.25))
	item.draw_rect(rect, color, false, 2.0)
	draw_label(item, label, rect.position + Vector2(4, -6))


static func draw_label(item: CanvasItem, text: String, at: Vector2) -> void:
	if text.is_empty():
		return
	item.draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_COLOR)


## A route (a Path2D's curve) as a line, with a label at its start.
static func draw_route(item: CanvasItem, curve: Curve2D, color: Color, label: String) -> void:
	if curve == null or curve.point_count < 2:
		return
	var points := curve.tessellate(6, 2.0)
	item.draw_polyline(points, color, 3.0, true)
	item.draw_circle(points[points.size() - 1], 6.0, color)
	draw_label(item, label, points[0] + Vector2(6, -10))


## Whether `offset` (from the item's origin) is inside a box of `size`
## centred on it.
static func box_contains(size: Vector2, offset: Vector2) -> bool:
	return Rect2(-size / 2.0, size).has_point(offset)


## Gives `area` a rectangle collision shape of `size`, made at load (not saved
## with the scene), replacing the previous one.
static func set_area_box(area: Area2D, size: Vector2) -> void:
	var shape_node: CollisionShape2D = area.get_node_or_null("Box")
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "Box"
		area.add_child(shape_node)
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape_node.shape = rectangle

@tool
class_name Terrain
extends Path2D
## A piece of terrain: draw its outline as a closed Path2D curve (clockwise or
## not), and at load it is baked once into collision (a StaticBody2D with a
## CollisionPolygon2D) and visuals (a Polygon2D fill and a Line2D outline),
## all from the same points (docs/dev/spike-vector-look.md). The baked nodes
## are made at load and never saved with the scene. In the editor it rebakes
## as the curve is edited.
##
## The outline must not cross itself. Straight parts stay two points; curves
## are subdivided until each step turns less than `bake_tolerance_degrees`,
## which stays smooth at the closest zoom the game reaches (4x).
# @spec-link [[req_loop_and_world]]

## The fill. Placeholder: black stone.
@export var fill_color := Color.BLACK:
	set(value):
		fill_color = value
		_restyle()
## The thin outline.
@export var outline_color := Color(0.75, 0.85, 0.8):
	set(value):
		outline_color = value
		_restyle()
@export_range(0.0, 16.0, 0.5) var outline_width := 3.0:
	set(value):
		outline_width = value
		_restyle()
## Whether slimes collide with it. Off for background decoration.
@export var has_collision := true:
	set(value):
		has_collision = value
		bake()
## How much a curve may turn between two baked points, in degrees.
@export_range(0.5, 10.0, 0.5) var bake_tolerance_degrees := 2.0:
	set(value):
		bake_tolerance_degrees = value
		bake()

## The baked outline, in this node's local space.
var baked_polygon := PackedVector2Array()
var fill: Polygon2D = null
var outline: Line2D = null
var body: StaticBody2D = null
## Null when has_collision is off.
var collision_polygon: CollisionPolygon2D = null


func _ready() -> void:
	if Engine.is_editor_hint() and curve != null and not curve.changed.is_connected(bake):
		curve.changed.connect(bake)
	bake()


## Bakes the curve into the fill, the outline and the collision polygon.
func bake() -> void:
	if not is_node_ready():
		return
	baked_polygon = bake_polygon(curve, bake_tolerance_degrees)
	if fill == null:
		fill = Polygon2D.new()
		fill.name = "Fill"
		add_child(fill)
		outline = Line2D.new()
		outline.name = "Outline"
		outline.closed = true
		outline.antialiased = true
		outline.joint_mode = Line2D.LINE_JOINT_ROUND
		add_child(outline)
	fill.polygon = baked_polygon
	outline.points = baked_polygon
	_restyle()
	if has_collision:
		if body == null:
			body = StaticBody2D.new()
			body.name = "Body"
			collision_polygon = CollisionPolygon2D.new()
			collision_polygon.name = "Shape"
			body.add_child(collision_polygon)
			add_child(body)
		collision_polygon.polygon = baked_polygon
	elif body != null:
		body.queue_free()
		body = null
		collision_polygon = null


## The closed outline of `curve` as a polygon (the closing point dropped).
static func bake_polygon(curve: Curve2D, tolerance_degrees: float) -> PackedVector2Array:
	if curve == null or curve.point_count < 3:
		return PackedVector2Array()
	var points := curve.tessellate(6, tolerance_degrees)
	if points.size() > 1 and points[0].distance_to(points[points.size() - 1]) < 0.5:
		points.remove_at(points.size() - 1)
	return points


func _restyle() -> void:
	if fill == null:
		return
	fill.color = fill_color
	outline.default_color = outline_color
	outline.width = outline_width
	outline.visible = outline_width > 0.0

@tool
class_name Decoration
extends Path2D
## Decoration: level scenery that is neither terrain nor an object (plants,
## rocks, other art). Draw its outline as a closed Path2D curve (vector art
## as curves, D93); at load it is filled once, like a Terrain's fill.
##
## It builds to O96's proposed default (D123), until the user decides:
## - it never collides: it makes no collision, and SlimeWorld gathers only
##   Terrain;
## - it never takes a tap: it has no stable ID and no tap target (it isn't
##   one of the level's things), so a tap on it is a call (D109);
## - it never hides an interactive object or a hint (rule 9): it draws
##   behind the whole level unless `in_front` is on, and the level-rules
##   checker (tools/check_level.gd) fails a decoration drawn in front that
##   covers an object, a sleeper, the first slime or a signpost.
## The simulation never reads it. Only the look is set here; there are no
## palettes or themes.

## The group every decoration joins, so tools can find them.
const GROUP := &"level_decoration"
## Drawn behind the level (terrain, objects, slimes), or in front of it.
const Z_BEHIND := -1
const Z_IN_FRONT := 1

## The fill.
@export var fill_color := Color(0.18, 0.18, 0.2):
	set(value):
		fill_color = value
		_restyle()
## Drawn in front of the level's things and slimes instead of behind them. A
## decoration in front must not cover an interactive object or a hint.
@export var in_front := false:
	set(value):
		in_front = value
		z_index = Z_IN_FRONT if in_front else Z_BEHIND
## How much a curve may turn between two baked points, in degrees.
@export_range(0.5, 10.0, 0.5) var bake_tolerance_degrees := 2.0:
	set(value):
		bake_tolerance_degrees = value
		bake()

## The baked outline, in this node's local space.
var baked_polygon := PackedVector2Array()
## The fill, made at load and never saved with the scene.
var fill: Polygon2D = null


func _init() -> void:
	add_to_group(GROUP)
	z_index = Z_BEHIND


func _ready() -> void:
	if Engine.is_editor_hint() and curve != null and not curve.changed.is_connected(bake):
		curve.changed.connect(bake)
	bake()


## Bakes the curve into the fill.
func bake() -> void:
	if not is_node_ready():
		return
	baked_polygon = Terrain.bake_polygon(curve, bake_tolerance_degrees)
	if fill == null:
		fill = Polygon2D.new()
		fill.name = "Fill"
		add_child(fill)
	fill.polygon = baked_polygon
	_restyle()


## Its outline in level coordinates (works before it enters the tree).
func level_polygon(level: Level) -> PackedVector2Array:
	var outline := baked_polygon
	if outline.is_empty():
		outline = Terrain.bake_polygon(curve, bake_tolerance_degrees)
	return level.transform_of(self) * outline


func _restyle() -> void:
	if fill != null:
		fill.color = fill_color

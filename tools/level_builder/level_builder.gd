class_name LevelBuilder
extends RefCounted
## Helpers for writing a level by script from the level components
## (src/components/): a builder owns a new Level and places components into
## it, each owned by the level so that save() writes it into the scene.
##
## Units, as in the design documents: x in screens (1 screen = S px), y in
## level pixels (y grows downward). Point lists and boxes given as arrays
## ([x, y], [x0, y0, x1, y1]) use these units; positions and sizes given as
## Vector2 or Rect2 are in level pixels (convert with at()).
##
## Usage: `var b := LevelBuilder.new("01", 1, "Level01")`, place things with
## the helpers, `b.save("res://levels/01/level.tscn")`, then free `b.level`
## (a Node: the builder doesn't free it).
# @spec-link [[req_level_design_rules]]

const COMPONENTS := "res://src/components/%s.tscn"
## One screen, in level pixels.
const S := LevelData.SCREEN
## A size-1 slime's centre sits this far above the ground it rolls on: the
## loop and the routes ride this far above their ground.
const RIDE := 24.0
## frontier_set()'s `gate_at` for a set with no gate (a last section's set).
const NO_GATE := Vector2.INF

## The level being built (the scene's root).
var level: Level


## A new Level named `node_name`, with its ID and version.
func _init(level_id: String, level_version: int, node_name: String) -> void:
	level = Level.new()
	level.name = node_name
	level.level_id = level_id
	level.level_version = level_version


# --- Units -------------------------------------------------------------------

## The level position of `x_screens` screens across, `y` px down.
static func at(x_screens: float, y: float) -> Vector2:
	return Vector2(x_screens * S, y)


## A level box [x0, y0, x1, y1] (x in screens) as a Rect2 relative to
## `origin` (level px): a switch's trapdoor, a gate's entrance lid.
static func box_from(origin: Vector2, box: Array) -> Rect2:
	var from := at(box[0], box[1])
	return Rect2(from - origin, at(box[2], box[3]) - from)


## A Curve2D through `points` ([x, y], x in screens), in level pixels.
static func curve(points: Array) -> Curve2D:
	var result := Curve2D.new()
	for point in points:
		result.add_point(at(point[0], point[1]))
	return result


## The points of `ground` ([x, y], x in screens) raised RIDE px: the route a
## size-1 slime's centre follows over that ground.
static func ride_over(ground: Array) -> Array:
	var route := []
	for point in ground:
		route.append([point[0], point[1] - RIDE])
	return route


## A sleeper's place [x, y, species] resting at `x` (screens) on a straight
## ledge `ledge` = [name, x0, x1, top at x0, top at x1] (x in screens).
static func on_ledge(ledge: Array, x: float, species: String) -> Array:
	var top: float = lerpf(ledge[3], ledge[4], (x - ledge[1]) / (ledge[2] - ledge[1]))
	return [x, top - RIDE, species]


# --- Nodes -------------------------------------------------------------------

## A plain Node2D named `node_name` under `parent`, to group components.
func group(parent: Node, node_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	parent.add_child(node)
	node.owner = level
	return node


## An instance of the component res://src/components/<component>.tscn named
## `node_name` under `parent`.
func add(parent: Node, component: String, node_name: String) -> Node:
	var scene: PackedScene = load(COMPONENTS % component)
	assert(scene != null, "LevelBuilder: no component '%s'" % component)
	var node: Node = scene.instantiate()
	node.name = node_name
	parent.add_child(node)
	node.owner = level
	return node


## A Terrain piece (solid) with the closed outline `outline` ([x, y], x in
## screens; the closing point is added).
func terrain(parent: Node, node_name: String, outline: Array) -> Terrain:
	var piece: Terrain = add(parent, "terrain", node_name)
	piece.curve = curve(_closed(outline))
	return piece


## A Decoration (never collides, never tapped) with the closed outline
## `outline` ([x, y], x in screens), drawn behind the level unless `in_front`.
func decoration(parent: Node, node_name: String, outline: Array, in_front := false) -> Decoration:
	var piece: Decoration = add(parent, "decoration", node_name)
	piece.curve = curve(_closed(outline))
	piece.in_front = in_front
	return piece


# --- The loop ----------------------------------------------------------------

## The level's Loop (`start.loop`), at the level's root. Its segments go
## under it, in loop order.
func loop() -> Loop:
	var node: Loop = add(level, "loop", "Loop")
	node.stable_id = "start.loop"
	return node


## A LoopSegment of `loop`, through `points` ([x, y], x in screens) in the
## direction of travel: section `section`, `kind` LoopData.OUTGOING or
## LoopData.RETURN, `gate_id` the gate that retires a return route ("" for
## none). Its node name is made from the ID ("s1.loop": S1Loop) unless given.
func segment(loop_node: Loop, id: String, points: Array, section: int, kind: String, gate_id: String,
		node_name := "") -> LoopSegment:
	assert(kind in [LoopData.OUTGOING, LoopData.RETURN], "LevelBuilder: bad segment kind '%s'" % kind)
	var node: LoopSegment = add(loop_node, "loop_segment", node_name if node_name else _pascal(id))
	node.stable_id = id
	node.section = section
	node.curve = curve(points)
	node.kind = kind
	node.gate_id = gate_id
	return node


# --- The start ---------------------------------------------------------------

## The SplitZone `stable_id`: a box of `size` px centred at `centre` (px).
func split_zone(parent: Node, stable_id: String, centre: Vector2, size: Vector2) -> SplitZone:
	var node: SplitZone = add(parent, "split_zone", "SplitZone")
	node.stable_id = stable_id
	node.position = centre
	node.size = size
	return node


## The FirstSlime (`start.first-slime`) of `species` at `position` (px).
func first_slime(parent: Node, species: String, position: Vector2) -> FirstSlime:
	var node: FirstSlime = add(parent, "first_slime", "FirstSlime")
	node.species = species
	node.position = position
	return node


# --- Sleepers ----------------------------------------------------------------

## A Sleeper `stable_id` of `species` at `position` (px).
func sleeper(parent: Node, node_name: String, stable_id: String, species: String,
		position: Vector2) -> Sleeper:
	var node: Sleeper = add(parent, "sleeper", node_name)
	node.stable_id = stable_id
	node.species = species
	node.position = position
	return node


## The sleepers of place `place` (`s1`, `s2`...): `placed` holds their
## places [x, y, species] (x in screens), in any order. They are numbered left
## to right (top to bottom on the same x), from 01: nodes SleeperNN, IDs
## `<place>.sleeper.NN` (two digits, three past 99).
func sleeper_row(parent: Node, place: String, placed: Array) -> Array[Sleeper]:
	var sorted := placed.duplicate()
	sorted.sort_custom(func(a, b):
		var ax := roundi(a[0] * 100000.0)
		var bx := roundi(b[0] * 100000.0)
		return ax < bx or (ax == bx and a[1] < b[1]))
	var sleepers: Array[Sleeper] = []
	for i in sorted.size():
		sleepers.append(sleeper(parent, "Sleeper%02d" % (i + 1), "%s.sleeper.%02d" % [place, i + 1],
				sorted[i][2], at(sorted[i][0], sorted[i][1])))
	return sleepers


# --- Branches and framing ----------------------------------------------------

## The ExplorationBranch `<place>.branch.<name_part>` covering `box` (px).
func branch(parent: Node, place: String, name_part: String, box: Rect2) -> ExplorationBranch:
	var node: ExplorationBranch = add(parent, "exploration_branch", "Branch")
	node.stable_id = "%s.branch.%s" % [place, name_part]
	node.position = box.get_center()
	node.size = box.size
	return node


## The RouteBack `<place>.route-back.<name_part>`, serving the branch
## `<place>.branch.<name_part>`, through `points` ([x, y], x in screens).
func route_back(parent: Node, place: String, name_part: String, points: Array) -> RouteBack:
	var node: RouteBack = add(parent, "route_back", "RouteBack")
	node.stable_id = "%s.route-back.%s" % [place, name_part]
	node.serves = "%s.branch.%s" % [place, name_part]
	node.curve = curve(points)
	return node


## The FramingZone `<place>.frame.<name_part>`: a box of `size` px centred at
## `centre` (px), with its camera `zoom` and `offset` (px).
func frame(parent: Node, place: String, name_part: String, centre: Vector2, size: Vector2, zoom: float,
		offset: Vector2) -> FramingZone:
	var node: FramingZone = add(parent, "framing_zone", "Frame")
	node.stable_id = "%s.frame.%s" % [place, name_part]
	node.position = centre
	node.size = size
	node.zoom = zoom
	node.offset = offset
	return node


# --- Frontier sets -----------------------------------------------------------

## One frontier set's nodes, as placed by frontier_set().
class FrontierSet:
	var signpost: Signpost
	var switch: Switch
	var basket: Basket
	## Null for a set with no gate.
	var gate: Gate


## The frontier set of place `place`, under `parent`: the Signpost
## `<place>.signpost` at `signpost_at`; the Switch `<place>.switch` (80 x 80
## px) at `switch_at` with its trapdoor `trapdoor` (a level box [x0, y0, x1,
## y1], x in screens); the Basket `<place>.basket` (a box of `basket_size` px
## centred at `basket_at`) with its `quota`; and, unless `gate_at` is
## NO_GATE, the Gate `<place>.gate` (40 x 160 px) at `gate_at` with its
## `entrance_lid` (a level box), which the basket opens when full. With no
## gate the basket has no target (a last set's: the celebration). Positions
## in px.
func frontier_set(parent: Node, place: String, signpost_at: Vector2, switch_at: Vector2, trapdoor: Array,
		basket_at: Vector2, basket_size: Vector2, quota: int, gate_at := NO_GATE,
		entrance_lid: Array = []) -> FrontierSet:
	var has_gate := gate_at != NO_GATE
	assert(has_gate or entrance_lid.is_empty(), "LevelBuilder: an entrance lid with no gate")
	var fs := FrontierSet.new()
	fs.signpost = add(parent, "signpost", "Signpost")
	fs.signpost.stable_id = "%s.signpost" % place
	fs.signpost.switch_id = "%s.switch" % place
	fs.signpost.position = signpost_at
	fs.switch = add(parent, "switch", "Switch")
	fs.switch.stable_id = "%s.switch" % place
	fs.switch.basket_id = "%s.basket" % place
	fs.switch.position = switch_at
	fs.switch.size = Vector2(80, 80)
	fs.switch.trapdoor = box_from(switch_at, trapdoor)
	fs.basket = add(parent, "basket", "Basket")
	fs.basket.stable_id = "%s.basket" % place
	fs.basket.quota = quota
	fs.basket.on_full_object = "%s.gate" % place if has_gate else ""
	fs.basket.on_full_action = "open"
	fs.basket.position = basket_at
	fs.basket.size = basket_size
	if has_gate:
		fs.gate = add(parent, "gate", "Gate")
		fs.gate.stable_id = "%s.gate" % place
		fs.gate.position = gate_at
		fs.gate.size = Vector2(40, 160)
		fs.gate.entrance_lid = box_from(gate_at, entrance_lid) if entrance_lid else Rect2()
	return fs


## Makes `basket` release its slimes at `point` (px) instead of onto the
## onward route (its outlet "point").
static func outlet_at(basket: Basket, point: Vector2) -> void:
	basket.outlet = "point"
	basket.outlet_point = point - basket.position


# --- Saving ------------------------------------------------------------------

## Packs the level and saves it as a scene at `path` (res:// or user://).
func save(path: String) -> Error:
	var packed := PackedScene.new()
	var error := packed.pack(level)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	return error


## `outline` with its first point appended, closing it.
static func _closed(outline: Array) -> Array:
	var closed := outline.duplicate()
	closed.append(outline[0])
	return closed


## "s1.loop" -> "S1Loop": each dot- or dash-separated part capitalised.
static func _pascal(id: String) -> String:
	var out := ""
	for part in id.replace("-", ".").split(".", false):
		out += part.left(1).to_upper() + part.substr(1)
	return out

class_name Level
extends Node2D
## The root of a level scene. A level is built only from components (no
## per-level scripts, D6): this script is the same for every level.
##
## At load it builds the registry (stable ID -> node) from every component in
## the scene, checks it and reports each problem with push_error: a missing or
## malformed stable ID, a duplicated one, a reference to an ID that isn't in
## the level, a rule whose ends don't exist or don't understand it, a level
## with no loop or a loop whose segments don't join. It then builds `data`,
## the level as plain data for the simulation (LevelData: the loop, the
## exploration branches and their routes back, the split zones, the tap
## targets and the first slime's spot, in level pixels).
##
## Components register themselves by joining THINGS_GROUP; each has a
## `stable_id` property. Optional methods a component may have:
## `references()` (property name -> stable ID it points at),
## `rule_events()`, `rule_actions()` and `rules()` (see Rule), and
## `tap_target()` ({"kind": a TapDispatcher.KIND_*, "size": the drawn box,
## centred on the component}) for what a tap can land on.

## The group every level component joins, to be found by the registry.
const THINGS_GROUP := &"level_things"

## The level's ID: "test" for the test level, "01" for the first real level.
@export var level_id := ""
## The level's version, recorded in saves. Bump it on any change to a
## released level, which then needs a save migration (D72).
# @spec-link [[rule_released_level_stable_with_migration]]
@export_range(1, 1000) var level_version := 1
## Extra rules held by the level itself. Most rules are held by the object
## that triggers them (a Basket's on_full_* properties).
@export var rules: Array[Rule] = []

## Stable ID -> component node. Built by build().
var registry: Dictionary = {}
## The problems found by the last build(); empty when the level is sound.
var load_errors := PackedStringArray()
## The level as plain data, for the simulation. Built by build().
var data: LevelData = null
## The Loop component.
# @spec-link [[req_loop_and_world]]
var loop: Loop = null


func _ready() -> void:
	for error in build():
		push_error("Level %s: %s" % [level_id, error])


## Builds the registry and the plain data, and checks them. Returns the
## problems found (also kept in load_errors). Doesn't need the scene tree.
# @spec-link [[req_level_design_rules]]
func build() -> PackedStringArray:
	var errors := PackedStringArray()
	registry = {}
	loop = null
	if level_id.is_empty():
		errors.append("the level has no level_id")
	if level_version < 1:
		errors.append("level_version must be 1 or more (it is %d)" % level_version)
	for node in find_children("*", "", true, false):
		if not node.is_in_group(THINGS_GROUP):
			continue
		var id: String = node.stable_id
		if not StableId.is_valid(id):
			errors.append("%s: stable id '%s' doesn't follow <place>.<kind>.<name>" % [get_path_to(node), id])
			continue
		if registry.has(id):
			errors.append("duplicate stable id '%s' (%s and %s)"
					% [id, get_path_to(registry[id]), get_path_to(node)])
			continue
		registry[id] = node
		if node is Loop:
			if loop != null:
				errors.append("more than one loop (%s and %s)" % [loop.stable_id, id])
			else:
				loop = node
	for id in ids():
		var node: Node = registry[id]
		if not node.has_method("references"):
			continue
		var references: Dictionary = node.references()
		for property in references:
			var target: String = references[property]
			if not target.is_empty() and not registry.has(target):
				errors.append("%s: %s refers to '%s', which isn't in the level" % [id, property, target])
	for rule in all_rules():
		errors.append_array(rule.validate(registry))
	data = LevelData.new(level_id, level_version)
	if loop == null:
		errors.append("the level has no loop (a Loop component)")
	else:
		data.loop = loop.build_data(self)
		errors.append_array(data.loop.validate())
	for id in ids():
		var node: Node = registry[id]
		if node is RouteBack:
			data.add_route_back(id, node.serves, node.level_points(self))
		elif node is SplitZone:
			data.add_split_zone(id, box_of(node, node.size))
		elif node is ExplorationBranch:
			data.add_branch(id, box_of(node, node.size))
		elif node is FramingZone:
			data.add_framing_zone(id, box_of(node, node.size), node.zoom, node.offset, node.exit_hold)
		elif node is FirstSlime:
			data.first_slime = {"id": id, "species": node.species, "position": position_of(node)}
		elif node is Sleeper:
			data.add_sleeper(id, node.species, position_of(node))
		elif node is Switch:
			data.add_switch(id, box_of(node, node.size), node.basket_id, rect_of(node, node.trapdoor))
		elif node is Basket:
			data.add_basket(id, box_of(node, node.size), node.quota, _outlet_of(node))
		elif node is Gate:
			data.add_gate(id, box_of(node, node.size), rect_of(node, node.entrance_lid))
		elif node is Signpost:
			data.add_signpost(id, position_of(node), node.switch_id)
		if node.has_method("tap_target"):
			var target: Dictionary = node.tap_target()
			data.add_tap_target(id, target["kind"], box_of(node, target["size"]))
	for rule in all_rules():
		data.rules.append(rule.to_dict())
	load_errors = errors
	return errors


## The component with this stable ID, or null.
func find(id: String) -> Node:
	return registry.get(id)


## Every stable ID in the level, sorted.
func ids() -> PackedStringArray:
	var out := PackedStringArray(registry.keys())
	out.sort()
	return out


## Every rule: the level's own and those its components hold.
# @spec-link [[req_interactive_objects_general]]
func all_rules() -> Array[Rule]:
	var out: Array[Rule] = []
	out.append_array(rules)
	for id in ids():
		if registry[id].has_method("rules"):
			out.append_array(registry[id].rules())
	return out


## Where a camera aimed at the component with stable ID `id` looks, in
## level coordinates: its position, or for a route (a loop segment, a route
## back, placed by its curve, not its node) its first point. Null when the
## level has no such component. Test mode's "at" and a fixture's "camera"
## name things this way.
func point_of(id: String) -> Variant:
	var thing := find(id)
	if thing == null:
		return null
	if thing is Path2D and thing.curve != null and thing.curve.point_count > 0:
		return transform_of(thing) * thing.curve.get_point_position(0)
	return position_of(thing)


## Where `node` is, in level coordinates (this node's local space).
func position_of(node: Node) -> Vector2:
	return transform_of(node).origin


## The transform from `node`'s local space to level coordinates. Works
## without the scene tree.
func transform_of(node: Node) -> Transform2D:
	var result := Transform2D.IDENTITY
	var current := node
	while current != null and current != self:
		if current is Node2D:
			result = current.transform * result
		current = current.get_parent()
	return result


## The level-coordinate bounds of a box of `size` centred on `node` (the
## box components: split zones, and so on).
func box_of(node: Node, size: Vector2) -> Rect2:
	var to_level := transform_of(node)
	var half := size * 0.5
	var box := Rect2(to_level * -half, Vector2.ZERO)
	for corner in [Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		box = box.expand(to_level * corner)
	return box


## The level-coordinate bounds of `local`, a box in `node`'s local space
## (a switch's trapdoor, a gate's lid). An empty box stays empty.
func rect_of(node: Node, local: Rect2) -> Rect2:
	if not local.has_area():
		return Rect2()
	var to_level := transform_of(node)
	var box := Rect2(to_level * local.position, Vector2.ZERO)
	for corner in [Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		box = box.expand(to_level * corner)
	return box


## Where basket `basket` releases its slimes (its `outlet` property), in
## level pixels: a point, or the onward route before the slide entrance
## (FrontierSets.onward_outlet).
# @spec-link [[req_switch_basket_gate_set]]
func _outlet_of(basket: Basket) -> Vector2:
	if basket.outlet == "point":
		return transform_of(basket) * basket.outlet_point
	return FrontierSets.onward_outlet(data.loop, basket.on_full_object, basket.outlet_before,
			position_of(basket))


## Where the game starts the view: the first slime's spawn, or the start of
## the loop.
func start_position() -> Vector2:
	for id in ids():
		if registry[id] is FirstSlime:
			return position_of(registry[id])
	if data != null and data.loop != null:
		return data.loop.position_at(0.0)
	return Vector2.ZERO

class_name SlimeWorld
extends RefCounted
## Glue between level scenes and the slime bodies: gathers the terrain the
## slimes collide with.


## The collision terrain under `root` for the slime bodies (O78): the baked
## outline of every Terrain component with has_collision, in `root`'s
## coordinates (level pixels), in tree order. Built once per level.
static func terrain_from(root: Node) -> TerrainSegments:
	var polygons: Array = []
	_gather(root, root, polygons)
	return TerrainSegments.new(polygons)


static func _gather(node: Node, root: Node, polygons: Array) -> void:
	if node is Terrain and node.has_collision:
		var outline: PackedVector2Array = node.baked_polygon
		if outline.is_empty() and node.curve != null:
			outline = Terrain.bake_polygon(node.curve, node.bake_tolerance_degrees)
		if outline.size() >= 3:
			polygons.append(_transform_to(node, root) * outline)
	for child in node.get_children():
		_gather(child, root, polygons)


## The transform from `node`'s coordinates to `root`'s, walking the parents
## (works before the nodes enter the tree).
static func _transform_to(node: Node, root: Node) -> Transform2D:
	var result := Transform2D.IDENTITY
	var current := node
	while current != null and current != root:
		if current is Node2D:
			result = current.transform * result
		current = current.get_parent()
	return result

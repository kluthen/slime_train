class_name SplitZones
extends RefCounted
## The split zones at work (master spec §5.4): every slime whose centre is
## inside a split zone is split at once into base slimes of its species and
## state (SlimeBodies.split). Nothing else in the game splits a slime. Plain
## data over SlimeBodies; the zones come from the level (LevelData).
# @spec-link [[rule_split_zone_only_splitter]]
# @spec-link [[rule_start_carries_split_zone]]

## Stable ID -> the box it covers (Rect2, level pixels).
var zones: Dictionary = {}

var _boxes: Array[Rect2] = []


func _init(split_zones: Dictionary = {}) -> void:
	zones = split_zones.duplicate()
	var ids := zones.keys()
	ids.sort()
	for zone_id in ids:
		_boxes.append(zones[zone_id])


## Whether `point` is inside a split zone.
func covers(point: Vector2) -> bool:
	for box in _boxes:
		if box.has_point(point):
			return true
	return false


## Splits every slime bigger than a base slime whose centre is in a split
## zone. Returns the splits, in slime id order: each the parts' ids, the
## original id first (SlimeBodies.split).
func apply(bodies: SlimeBodies) -> Array:
	var out := []
	if _boxes.is_empty():
		return out
	for slime_id in bodies.ids():
		var s := bodies.index_of(slime_id)
		if bodies.size[s] > 1 and covers(bodies.centre_of(slime_id)):
			out.append(bodies.split(slime_id))
	return out

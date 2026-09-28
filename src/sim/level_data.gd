class_name LevelData
extends RefCounted
## A level as plain data for the simulation core: its ID and version, the
## loop, the routes back, the split zones and the first awake slime's spot.
## Built at load by the Level component
## (src/components/level.gd); nothing here refers to a scene node.
# @spec-link [[req_loop_and_world]]
# @spec-link [[rule_released_level_stable_with_migration]]

## One screen, in level pixels: the width of the view at normal zoom (the
## project's viewport is 1152 x 648). Level layouts are given in screens
## (specs/levels/test/README.md, "Conventions").
const SCREEN := 1152.0

## The level's ID, "test" for the test level.
var level_id := ""
## The level's version. A released level that changes gets a new version and
## a save migration (D72).
var level_version := 0
## The loop.
var loop: LoopData = null
## The routes back of the exploration branches: stable ID -> {"serves": the
## branch's stable ID, "points": PackedVector2Array in level pixels, "lengths":
## PackedFloat64Array, cumulative}.
var route_backs: Dictionary = {}
## The split zones: stable ID -> the box it covers (Rect2, level pixels).
var split_zones: Dictionary = {}
## Where the game wakes the first slime (the FirstSlime component): {"id",
## "species" (its letter), "position" (level pixels, a base slime's centre)},
## or {} when the level has none.
var first_slime: Dictionary = {}


func _init(id := "", version := 0) -> void:
	level_id = id
	level_version = version


## Adds a route back serving the exploration branch `serves`.
func add_route_back(id: String, serves: String, points: PackedVector2Array) -> void:
	route_backs[id] = {"serves": serves, "points": points, "lengths": Polyline.cumulative_lengths(points)}


## Adds a split zone covering `box` (level pixels).
func add_split_zone(id: String, box: Rect2) -> void:
	split_zones[id] = box


## The ID and version, as the simulation's dump carries them.
func header() -> Dictionary:
	return {"id": level_id, "version": level_version}

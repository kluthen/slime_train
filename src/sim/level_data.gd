class_name LevelData
extends RefCounted
## A level as plain data for the simulation core: its ID and version, the
## loop, the exploration branches and their routes back, the split zones, the
## framing zones, the tap targets, the first awake slime's spot, the
## sleepers, and the frontier sets (switches, baskets, gates, signposts) with
## the level's rules.
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
## The exploration branches: stable ID -> the box it covers (Rect2, level
## pixels). A free slime heading back from inside one follows its route back.
# @spec-link [[rule_exploration_branch_has_route_back]]
var branches: Dictionary = {}
## What a tap can land on (TapDispatcher, zone 3): stable ID -> {"kind"
## (TapDispatcher.KIND_*), "box" (Rect2, level pixels, the drawn object; the
## hit area adds a margin)}.
# @spec-link [[req_controls_tap_zones]]
var tap_targets: Dictionary = {}
## The framing zones (the camera's, Camera): stable ID -> {"box" (Rect2,
## level pixels), "zoom" (as ScreenView.zoom: below 1 shows more), "offset"
## (Vector2, level pixels: how far the view shifts from the rails' place),
## "exit_hold" (seconds of holding an edge button to leave it; -1 for the
## camera's default, Camera.EXIT_HOLD)}.
# @spec-link [[req_camera_rails_and_framing]]
# @spec-link [[rule_framing_zone_wherever_wider_view_needed]]
var framing_zones: Dictionary = {}
## Where the game wakes the first slime (the FirstSlime component): {"id",
## "species" (its letter), "position" (level pixels, a base slime's centre)},
## or {} when the level has none.
var first_slime: Dictionary = {}
## The sleepers placed in the level (the Sleeper components): stable ID ->
## {"species" (its letter), "position" (level pixels, a base slime's centre
## resting on its ledge)}. Simulation.load_level puts them in a fresh game.
# @spec-link [[req_waking_sleepers]]
var sleepers: Dictionary = {}
## The frontier sets (FrontierSets, chunk 14), in level pixels. Switches:
## stable ID -> {"box" (Rect2), "basket" (its basket's stable ID),
## "trapdoor" (Rect2: the piece of the onward path that opens into the
## basket while the switch is flipped; an empty rect for none)}.
# @spec-link [[req_switch_basket_gate_set]]
var switches: Dictionary = {}
## Baskets: stable ID -> {"box" (Rect2: a slime whose centre is inside is
## in the basket), "quota" (the weight that fills it), "outlet" (Vector2:
## where it releases its slimes, a base slime's centre)}.
var baskets: Dictionary = {}
## Gates: stable ID -> {"box" (Rect2: solid while closed), "lid" (Rect2:
## the old slide entrance, shut once the gate is open; empty for none)}.
var gates: Dictionary = {}
## Signposts: stable ID -> {"position" (Vector2), "switch" (the switch it
## explains)}. Not interactive.
# @spec-link [[rule_signpost_at_every_fork]]
var signposts: Dictionary = {}
## Every rule of the level, in the shared format (Rule.to_dict), in the
## order Level.all_rules() gives.
# @spec-link [[req_interactive_objects_general]]
var rules: Array[Dictionary] = []


func _init(id := "", version := 0) -> void:
	level_id = id
	level_version = version


## Adds a route back serving the exploration branch `serves`.
func add_route_back(id: String, serves: String, points: PackedVector2Array) -> void:
	route_backs[id] = {"serves": serves, "points": points, "lengths": Polyline.cumulative_lengths(points)}


## Adds a split zone covering `box` (level pixels).
func add_split_zone(id: String, box: Rect2) -> void:
	split_zones[id] = box


## Adds an exploration branch covering `box` (level pixels).
func add_branch(id: String, box: Rect2) -> void:
	branches[id] = box


## Adds a framing zone covering `box` (level pixels): the camera's `zoom`
## and `offset` inside it, and the hold it takes to leave it (`exit_hold`
## seconds, -1 for the camera's default).
func add_framing_zone(id: String, box: Rect2, zoom: float, offset: Vector2, exit_hold := -1.0) -> void:
	framing_zones[id] = {"box": box, "zoom": zoom, "offset": offset, "exit_hold": exit_hold}


## Adds a sleeper: a base slime of species `species` (its letter), asleep,
## centred at `position` (level pixels).
func add_sleeper(id: String, species: String, position: Vector2) -> void:
	sleepers[id] = {"species": species, "position": position}


## Adds a switch covering `box`, sending the flow into basket `basket` when
## flipped by opening its `trapdoor` (level pixels; empty: none).
func add_switch(id: String, box: Rect2, basket: String, trapdoor := Rect2()) -> void:
	switches[id] = {"box": box, "basket": basket, "trapdoor": trapdoor}


## Adds a basket: `box` holds the slimes in it, `quota` is the weight that
## fills it, `outlet` where it releases them (level pixels).
func add_basket(id: String, box: Rect2, quota: int, outlet: Vector2) -> void:
	baskets[id] = {"box": box, "quota": quota, "outlet": outlet}


## Adds a gate blocking `box` while closed; `lid` shuts the old slide
## entrance once it is open (empty: none).
func add_gate(id: String, box: Rect2, lid := Rect2()) -> void:
	gates[id] = {"box": box, "lid": lid}


## Adds a signpost at `position`, explaining switch `switch`.
func add_signpost(id: String, position: Vector2, switch: String) -> void:
	signposts[id] = {"position": position, "switch": switch}


## Adds something a tap can land on: `kind` is a TapDispatcher.KIND_*, `box`
## the drawn object in level pixels.
func add_tap_target(id: String, kind: String, box: Rect2) -> void:
	tap_targets[id] = {"kind": kind, "box": box}


## The stable ID of the route back serving branch `branch_id`, or "" (the
## smaller ID when several do; the level rules want exactly one).
func route_back_for(branch_id: String) -> String:
	var ids := route_backs.keys()
	ids.sort()
	for id in ids:
		if route_backs[id]["serves"] == branch_id:
			return id
	return ""


## The stable ID of the exploration branch whose box holds `point`, or ""
## (the smaller ID when boxes overlap).
func branch_at(point: Vector2) -> String:
	var ids := branches.keys()
	ids.sort()
	for id in ids:
		if (branches[id] as Rect2).has_point(point):
			return id
	return ""


## The ID and version, as the simulation's dump carries them.
func header() -> Dictionary:
	return {"id": level_id, "version": level_version}

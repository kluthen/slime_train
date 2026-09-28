extends SceneTree
## Generates the greybox of the test level, levels/test/level.tscn, from the
## layout tables below, using only the level components (src/components/).
## The layout follows specs/levels/test/README.md; x is in screens (1 screen
## = LevelData.SCREEN px), y in level pixels (y grows downward, the hilltops
## are near y = 0).
##
## Run from the project root:
##   godot --headless -s res://tools/greybox_test_level.gd
##
## The scene it writes is a normal scene: open it in the editor and move
## things by hand if you like, but a later run of this script overwrites the
## hand edits. Once the level is edited by hand for real, delete this script.
# @spec-link [[req_test_level_and_test_mode]]
# @spec-link [[req_level_design_rules]]

const OUT := "res://levels/test/level.tscn"
const COMPONENTS := "res://src/components/%s.tscn"
const S := LevelData.SCREEN
## A size-1 slime's centre sits this far above the ground it rolls on.
const RIDE := 24.0

# --- Terrain (closed outlines, x in screens, y in px) ------------------------

## The top of the ground along section 1, from the lip over the start basin to
## the slide entrance. The loop rides RIDE px above it.
const SURFACE := [
	[0.64, 390], [0.66, 368], [0.75, 300], [0.9, 180], [1.05, 80], [1.15, 50],
	# 1.2 Hills.
	[1.3, 20], [1.45, 40], [1.6, 0], [1.75, 30], [1.9, -10], [2.05, 20],
	[2.2, -20], [2.35, 10], [2.5, 0],
	# 1.3 Fusion dip.
	[2.62, 60], [2.75, 170], [2.9, 230], [3.0, 240], [3.1, 230], [3.25, 170],
	[3.38, 60], [3.5, -40],
	# 1.4 High step, 1.5 the tree, then up to frontier set 1.
	[3.6, -50], [4.0, -50], [4.5, -50], [4.8, -60], [5.2, -70], [5.6, -80],
	[6.0, -100], [6.49, -100],
]
## Basket 1's pit, under the onward path, then the ground up to the slide
## entrance, the chute's near wall and the slide tunnel's roof back to the lip
## (it slopes down to the lip's nose, over the hump in the tunnel's floor).
const CRUST_REST := [
	[6.7, 100], [7.2, 100], [7.3, -100], [7.5, -100],
	[7.25, 300], [7.0, 320], [5.0, 350], [3.0, 375], [1.5, 385], [0.78, 352],
]
## The bedrock: the level's left wall, the start basin's floor, the slide
## tunnel's floor rising to the chute, and the ground past gate 1. Just
## inside the tunnel's mouth, under the lip, its floor has a hump that slopes
## down into the basin, so a slime that falls short of the lip rolls back out
## instead of getting lost in the tunnel.
const BEDROCK := [
	[0.0, -800], [0.08, -800], [0.1, 200], [0.14, 440], [0.2, 500], [0.62, 500], [0.78, 462],
	[1.5, 495], [3.0, 485], [5.0, 460], [7.0, 430], [7.3, 390], [7.5, 150],
	[7.66, 30], [7.66, -100], [8.0, -100], [8.0, 1200], [0.0, 1200],
]
## Floating greybox pieces: name -> outline.
const PIECES := {
	"FirstLedge": [[0.44, 400], [0.52, 400], [0.52, 420], [0.44, 420]],
	"DipHollow": [[3.3, -170], [3.32, -150], [3.44, -150], [3.46, -170], [3.46, -130], [3.3, -130]],
	"HighStep": [[3.7, -330], [4.15, -330], [4.41, -210], [3.7, -210]],
	"TreeClimb": [[4.72, -238], [4.9, -360], [4.9, -330], [4.72, -208]],
	"TreePlatform": [[4.9, -360], [5.5, -360], [5.5, -320], [4.9, -320]],
	"TreeBough": [[5.3, -640], [5.48, -640], [5.48, -615], [5.3, -615]],
	"TreeBack": [[5.5, -360], [5.85, -230], [5.85, -200], [5.5, -330]],
	"Bridge": [[6.5, -100], [7.29, -100], [7.29, -75], [6.5, -75]],
	"LedgeB": [[6.2, -320], [6.4, -320], [6.4, -295], [6.2, -295]],
	"LedgeC": [[6.5, -360], [6.75, -360], [6.75, -335], [6.5, -335]],
}
## Decoration: no collision, drawn behind.
const TRUNK := [[5.15, -615], [5.3, -615], [5.3, -60], [5.15, -60]]
## The hills' side bumps: centre x, and which way the top slopes.
const HILL_BUMPS := [[1.2, 1], [1.45, -1], [1.7, 1], [1.95, -1], [2.2, 1], [2.45, -1]]
const BUMP_TOP := -170.0
const BUMP_HALF_WIDTH := 0.08
const BUMP_TILT := 12.0

# --- Routes (x in screens, y in px) ------------------------------------------

## The loop out: from the start of the loop across the basin, up over the
## lip's nose (the rise is in the open, clear of the first sleeper's ledge and
## of the nose), then RIDE above SURFACE, over the bridge to the slide
## entrance.
const LOOP_START := [[0.3, 476], [0.58, 476], [0.59, 356], [0.66, 344]]
const LOOP_END := [[7.6, -124]]
## Slide 1, the section's return route: down the chute and back under the
## surface to the start of the loop.
const SLIDE := [
	[7.6, -124], [7.54, 0], [7.43, 150], [7.31, 300], [7.0, 406], [5.0, 436],
	[3.0, 461], [1.5, 471], [0.78, 438], [0.62, 476], [0.3, 476],
]
const ROUTE_BACK_HIGH_STEP := [
	[3.8, -354], [4.15, -354], [4.41, -234], [4.5, -194], [4.56, -120], [4.58, -76],
]
const ROUTE_BACK_TREE := [[4.95, -384], [5.5, -384], [5.85, -254], [5.95, -121]]

# --- Placed things -----------------------------------------------------------

## Sleepers other than the hills', left to right: [x, y, species].
const SLEEPERS_BEFORE_HILLS := [[0.48, 376, "B"]]
const SLEEPERS_AFTER_HILLS := [
	# 1.3 Fusion dip: the hollow on the rim.
	[3.34, -174, "C"], [3.42, -174, "C"],
	# 1.5 Tree: lower platform, then the high bough.
	[4.96, -384, "A"], [5.02, -384, "A"], [5.08, -384, "B"], [5.14, -384, "B"],
	[5.2, -384, "C"], [5.26, -384, "C"],
	[5.33, -664, "A"], [5.39, -664, "A"], [5.45, -664, "A"],
	# 1.6 Frontier set 1: the ledges above the switch.
	[6.25, -344, "B"], [6.33, -344, "B"], [6.55, -384, "C"], [6.62, -384, "C"], [6.69, -384, "C"],
]
const HILL_SPECIES := ["A", "B", "C"]


func _init() -> void:
	var level := _build()
	var packed := PackedScene.new()
	var error := packed.pack(level)
	if error == OK:
		error = ResourceSaver.save(packed, OUT)
	level.free()
	if error != OK:
		printerr("greybox_test_level: failed (error %d)" % error)
		quit(1)
		return
	print("greybox_test_level: wrote %s" % OUT)
	quit(0)


func _build() -> Level:
	var level := Level.new()
	level.name = "TestLevel"
	level.level_id = "test"
	level.level_version = 1

	var terrain := _group(level, level, "Terrain")
	var surface_rest: Array = SURFACE.duplicate()
	surface_rest.append_array(CRUST_REST)
	_terrain(level, terrain, "Crust", surface_rest)
	_terrain(level, terrain, "Bedrock", BEDROCK)
	for piece in PIECES:
		_terrain(level, terrain, piece, PIECES[piece])
	for i in HILL_BUMPS.size():
		var x: float = HILL_BUMPS[i][0]
		var tilt: float = BUMP_TILT * HILL_BUMPS[i][1]
		_terrain(level, terrain, "HillBump%d" % (i + 1), [
			[x - BUMP_HALF_WIDTH, BUMP_TOP - tilt], [x + BUMP_HALF_WIDTH, BUMP_TOP + tilt],
			[x + BUMP_HALF_WIDTH, BUMP_TOP + tilt + 25], [x - BUMP_HALF_WIDTH, BUMP_TOP - tilt + 25],
		])
	var trunk := _terrain(level, terrain, "TreeTrunk", TRUNK)
	trunk.has_collision = false
	trunk.fill_color = Color(0.18, 0.18, 0.2)
	trunk.outline_width = 0.0
	trunk.z_index = -1

	var loop: Loop = _add(level, level, "loop", "Loop")
	loop.stable_id = "start.loop"
	var outgoing: Array = LOOP_START.duplicate()
	for point in SURFACE.slice(2):
		outgoing.append([point[0], point[1] - RIDE])
	outgoing.append_array(LOOP_END)
	var s1_loop: LoopSegment = _add(level, loop, "loop_segment", "S1Loop")
	_set_route(s1_loop, "s1.loop", outgoing)
	var s1_slide: LoopSegment = _add(level, loop, "loop_segment", "S1Slide")
	_set_route(s1_slide, "s1.slide", SLIDE)
	s1_slide.kind = LoopData.RETURN
	s1_slide.gate_id = "s1.gate"

	var start := _group(level, level, "Start")
	var split_zone: SplitZone = _add(level, start, "split_zone", "SplitZone")
	split_zone.stable_id = "start.split-zone"
	split_zone.position = _at(0.26, 450)
	split_zone.size = Vector2(0.28 * S, 100)
	var first_slime: FirstSlime = _add(level, start, "first_slime", "FirstSlime")
	first_slime.species = "A"
	first_slime.position = _at(0.3, 476)

	var section := _group(level, level, "Section1")
	var sleepers := _group(level, section, "Sleepers")
	var placed: Array = SLEEPERS_BEFORE_HILLS.duplicate()
	var n := 0
	for bump in HILL_BUMPS:
		for side in [-1, 1]:
			var x: float = bump[0] + 0.04 * side
			var top: float = BUMP_TOP + BUMP_TILT * bump[1] * (x - bump[0]) / BUMP_HALF_WIDTH
			placed.append([x, top - RIDE, HILL_SPECIES[n % 3]])
			n += 1
	placed.append_array(SLEEPERS_AFTER_HILLS)
	for i in placed.size():
		var sleeper: Sleeper = _add(level, sleepers, "sleeper", "Sleeper%02d" % (i + 1))
		sleeper.stable_id = "s1.sleeper.%02d" % (i + 1)
		sleeper.species = placed[i][2]
		sleeper.position = _at(placed[i][0], placed[i][1])

	var high_step := _group(level, section, "HighStep")
	_branch(level, high_step, "high-step", Rect2(3.68 * S, -560, 0.82 * S, 390))
	_route_back(level, high_step, "high-step", ROUTE_BACK_HIGH_STEP)
	_frame(level, high_step, "high-step", _at(4.0, -250), Vector2(S, 600), 0.85, Vector2(0, -120))

	var tree := _group(level, section, "Tree")
	_branch(level, tree, "tree", Rect2(4.6 * S, -900, 1.3 * S, 790))
	_route_back(level, tree, "tree", ROUTE_BACK_TREE)
	_frame(level, tree, "tree", _at(5.0, -300), Vector2(S, 700), 0.7, Vector2(0, -250))

	var frontier := _group(level, section, "FrontierSet")
	var signpost: Signpost = _add(level, frontier, "signpost", "Signpost")
	signpost.stable_id = "s1.signpost"
	signpost.switch_id = "s1.switch"
	signpost.position = _at(6.4, -100)
	var switch: Switch = _add(level, frontier, "switch", "Switch")
	switch.stable_id = "s1.switch"
	switch.basket_id = "s1.basket"
	switch.position = _at(6.47, -124)
	switch.size = Vector2(80, 80)
	var basket: Basket = _add(level, frontier, "basket", "Basket")
	basket.stable_id = "s1.basket"
	basket.quota = 6
	basket.on_full_object = "s1.gate"
	basket.on_full_action = "open"
	basket.position = _at(6.95, 20)
	basket.size = Vector2(560, 150)
	var gate: Gate = _add(level, frontier, "gate", "Gate")
	gate.stable_id = "s1.gate"
	gate.position = _at(7.8, -180)
	gate.size = Vector2(40, 160)
	return level


func _at(x_screens: float, y: float) -> Vector2:
	return Vector2(x_screens * S, y)


func _group(level: Level, parent: Node, node_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	parent.add_child(node)
	node.owner = level
	return node


func _add(level: Level, parent: Node, component: String, node_name: String) -> Node:
	var node: Node = load(COMPONENTS % component).instantiate()
	node.name = node_name
	parent.add_child(node)
	node.owner = level
	return node


func _curve(points: Array) -> Curve2D:
	var curve := Curve2D.new()
	for point in points:
		curve.add_point(_at(point[0], point[1]))
	return curve


func _terrain(level: Level, parent: Node, node_name: String, outline: Array) -> Terrain:
	var piece: Terrain = _add(level, parent, "terrain", node_name)
	var closed := outline.duplicate()
	closed.append(outline[0])
	piece.curve = _curve(closed)
	return piece


func _set_route(segment: LoopSegment, id: String, points: Array) -> void:
	segment.stable_id = id
	segment.section = 1
	segment.curve = _curve(points)


func _branch(level: Level, parent: Node, name_part: String, box: Rect2) -> void:
	var branch: ExplorationBranch = _add(level, parent, "exploration_branch", "Branch")
	branch.stable_id = "s1.branch.%s" % name_part
	branch.position = box.get_center()
	branch.size = box.size


func _route_back(level: Level, parent: Node, name_part: String, points: Array) -> void:
	var route_back: RouteBack = _add(level, parent, "route_back", "RouteBack")
	route_back.stable_id = "s1.route-back.%s" % name_part
	route_back.serves = "s1.branch.%s" % name_part
	route_back.curve = _curve(points)


func _frame(level: Level, parent: Node, name_part: String, at: Vector2, size: Vector2,
		zoom: float, offset: Vector2) -> void:
	var frame: FramingZone = _add(level, parent, "framing_zone", "Frame")
	frame.stable_id = "s1.frame.%s" % name_part
	frame.position = at
	frame.size = size
	frame.zoom = zoom
	frame.offset = offset

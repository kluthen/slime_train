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
## tunnel's floor running on under the pillar and section 2 (chunk 15) to
## section 3's shaft, the ground past the shaft and the level's right wall
## (a stub of section 3, for chunk 16). The tunnel's floor falls gently all
## the way back to the basin, so the slides carry the slimes home. Just
## inside the tunnel's mouth, under the lip, its floor has a hump that slopes
## down into the basin, so a slime that falls short of the lip rolls back out
## instead of getting lost in the tunnel.
const BEDROCK := [
	[0.0, -800], [0.08, -800], [0.1, 200], [0.14, 440], [0.2, 500], [0.62, 500], [0.78, 462],
	[1.5, 495], [3.0, 485], [5.0, 460], [7.0, 430], [7.3, 390], [8.0, 375], [8.5, 360],
	[10.5, 338], [12.5, 312], [12.62, 308], [13.3, 300], [13.4, 280], [13.4, -20], [13.55, -20],
	[13.55, -800], [13.65, -800], [13.65, 1200], [0.0, 1200],
]
## Section 2's crust (chunk 15): the ground from the pillar down the descent
## (2.1), along the parade (2.2), through the second dip (2.3), under the
## cave (2.4) to basket 2's pit and slide 2's chute (2.5), then back along
## the tunnel's roof. Its top is y -20 on the flat; the loop rides RIDE above.
const S2_CRUST := [
	[8.5, -100], [8.6, -100], [8.75, -65], [8.9, -30], [9.0, -20],
	# 2.3 Second dip.
	[10.0, -20], [10.05, 0], [10.15, 70], [10.25, 100], [10.35, 70], [10.45, 0], [10.5, -20],
	# 2.5 Basket 2's pit, then the chute's near wall.
	[12.2, -20], [12.2, 150], [12.55, 150], [12.55, -20], [12.6, -20],
	[12.6, 190], [10.5, 188], [8.5, 180],
]
## Section 2's floating pieces: name -> outline.
const S2_PIECES := {
	# 2.1 Descent: the D ledges.
	"DescentLedge1": [[8.55, -330], [8.72, -330], [8.72, -305], [8.55, -305]],
	"DescentLedge2": [[8.78, -250], [8.95, -250], [8.95, -225], [8.78, -225]],
	# 2.2 Parade: the overhang ledges.
	"ParadeLedge1": [[9.15, -240], [9.36, -240], [9.36, -215], [9.15, -215]],
	"ParadeLedge2": [[9.6, -240], [9.81, -240], [9.81, -215], [9.6, -215]],
	# 2.3 The hollow on the second dip's rim.
	"Dip2Hollow": [[9.93, -170], [9.95, -150], [10.07, -150], [10.09, -170], [10.09, -130], [9.93, -130]],
	# 2.4 The cave: the stepped climb, the pocket, then the tunnel's two
	# shelves (each with a lip where the way turns) down to the loop.
	"CaveStep1": [[10.5, -180], [10.62, -180], [10.62, -155], [10.5, -155]],
	"CaveStep2": [[10.62, -310], [10.74, -310], [10.74, -285], [10.62, -285]],
	"CaveStep3": [[10.74, -440], [10.86, -440], [10.86, -415], [10.74, -415]],
	"CaveStep4": [[10.86, -570], [10.95, -570], [10.95, -545], [10.86, -545]],
	"CavePocket": [[10.95, -700], [11.65, -700], [11.65, -675], [10.95, -675]],
	"CaveShelfA": [[11.02, -500], [11.9, -550], [11.9, -620], [11.93, -620], [11.93, -525], [11.02, -475]],
	"CaveShelfB": [[10.93, -430], [10.95, -430], [10.95, -360], [11.88, -310], [11.88, -285], [10.93, -335]],
	# 2.5 Frontier set 2: the ledges by the switch and before the pit.
	"Set2Ledge1": [[10.755, -230], [10.925, -230], [10.925, -205], [10.755, -205]],
	"Set2Ledge2": [[12.0, -260], [12.265, -260], [12.265, -235], [12.0, -235]],
	# Past slide 2's chute: gate 2's ground, over the tunnel, to section 3's
	# shaft (a stub).
	"Pillar2": [[12.72, -20], [13.3, -20], [13.3, 190], [12.72, 190]],
}
## Floating greybox pieces: name -> outline.
const PIECES := {
	"FirstLedge": [[0.44, 400], [0.52, 400], [0.52, 420], [0.44, 420]],
	"DipHollow": [[3.3, -170], [3.32, -150], [3.44, -150], [3.46, -170], [3.46, -130], [3.3, -130]],
	"HighStep": [[3.7, -330], [4.15, -330], [4.41, -210], [3.7, -210]],
	"TreeClimb": [[4.72, -238], [4.9, -360], [4.9, -330], [4.72, -208]],
	"TreePlatform": [[4.9, -360], [5.5, -360], [5.5, -320], [4.9, -320]],
	"TreeBough": [[5.3, -640], [5.48, -640], [5.48, -615], [5.3, -615]],
	"TreeBack": [[5.5, -360], [5.85, -230], [5.85, -200], [5.5, -330]],
	# The chute's far wall and the ground past gate 1, over the tunnel.
	"Pillar": [[7.66, -100], [8.5, -100], [8.5, 180], [7.6, 180], [7.5, 150], [7.66, 30]],
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
## Section 2 (chunk 15): on from the slide entrance over the pillar and
## gate 1, RIDE above S2_CRUST (over basket 2's trapdoor) to slide 2's
## entrance; then slide 2, its return route (while gate 2 is closed), down
## the chute and back along the tunnel to slide 1's tail.
const S2_LOOP := [
	[7.6, -124], [8.0, -124], [8.5, -124], [8.6, -124], [8.75, -89], [8.9, -54], [9.0, -44],
	[10.0, -44], [10.05, -24], [10.15, 46], [10.25, 76], [10.35, 46], [10.45, -24], [10.5, -44],
	[12.2, -44], [12.66, -44],
]
const S2_SLIDE := [
	[12.66, -44], [12.66, 120], [12.64, 250], [12.55, 285], [10.5, 314], [8.5, 336],
	[8.3, 345], [8.0, 351], [7.3, 366], [7.0, 406],
]
## Section 3 (a stub for chunk 16): on through gate 2 over Pillar2, then its
## return route down the shaft and back under the pillar to slide 2's tunnel.
const S3_LOOP := [[12.66, -44], [13.0, -44], [13.35, -44]]
const S3_SLIDE := [[13.35, -44], [13.35, 150], [13.3, 276], [13.0, 279], [12.66, 283], [12.55, 285]]
## Frontier set 2's doors (chunk 15), as TRAPDOOR and ENTRANCE_LID: switch
## 2's trapdoor over basket 2's pit, and gate 2's lid over slide 2's chute.
const TRAPDOOR_2 := [12.2, -20, 12.55, 5]
const ENTRANCE_LID_2 := [12.59, -20, 12.73, 12]
## The cave's route back (2.4): along the pocket, down onto shelf A and back
## along it, down onto shelf B and along it, then down onto the loop at 11.92
## (about 2400 px from the pocket's edge: some 36 s for a size-1 slime).
const ROUTE_BACK_CAVE := [
	[10.98, -724], [11.63, -724], [11.7, -562], [11.05, -526], [10.99, -382], [11.86, -335],
	[11.92, -44],
]
## Frontier set 1's doors (chunk 14), level boxes [x0, y0, x1, y1] (x in
## screens): the switch's trapdoor over basket 1's pit (solid while the flow
## goes onward), and gate 1's lid over slide 1's entrance (shut once the gate
## is open).
const TRAPDOOR := [6.5, -100, 7.29, -75]
const ENTRANCE_LID := [7.49, -100, 7.67, -68]
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
## Section 2's sleepers (chunk 15), numbered left to right when placed: [x,
## y, species] (README population: A 7, B 7, C 7, D 19).
const S2_SLEEPERS := [
	# 2.1 Descent: 6 D on the side ledges.
	[8.58, -354, "D"], [8.635, -354, "D"], [8.69, -354, "D"],
	[8.81, -274, "D"], [8.865, -274, "D"], [8.92, -274, "D"],
	# 2.2 Parade: A, B, C and D, 2 of each, on the overhang ledges.
	[9.18, -264, "A"], [9.23, -264, "B"], [9.28, -264, "C"], [9.33, -264, "D"],
	[9.63, -264, "A"], [9.68, -264, "B"], [9.73, -264, "C"], [9.78, -264, "D"],
	# 2.3 Second dip: 2 D in the hollow on its rim.
	[9.97, -174, "D"], [10.05, -174, "D"],
	# 2.5 Frontier set 2, the ledge by the switch.
	[10.775, -254, "A"], [10.818, -254, "B"], [10.861, -254, "C"], [10.904, -254, "D"],
	# 2.4 The cave pocket: A 3, B 3, C 3, D 5.
	[10.98, -724, "A"], [11.028, -724, "B"], [11.076, -724, "C"], [11.124, -724, "D"],
	[11.172, -724, "A"], [11.22, -724, "B"], [11.268, -724, "C"], [11.316, -724, "D"],
	[11.364, -724, "A"], [11.412, -724, "B"], [11.46, -724, "C"], [11.508, -724, "D"],
	[11.556, -724, "D"], [11.604, -724, "D"],
	# 2.5 Frontier set 2, the ledge before the pit.
	[12.025, -284, "A"], [12.068, -284, "B"], [12.111, -284, "C"], [12.154, -284, "D"],
	[12.197, -284, "D"], [12.24, -284, "D"],
]


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
	_terrain(level, terrain, "S2Crust", S2_CRUST)
	for piece in S2_PIECES:
		_terrain(level, terrain, piece, S2_PIECES[piece])
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
	var s2_loop: LoopSegment = _add(level, loop, "loop_segment", "S2Loop")
	_set_route(s2_loop, "s2.loop", S2_LOOP, 2)
	var s2_slide: LoopSegment = _add(level, loop, "loop_segment", "S2Slide")
	var s2_return: Array = S2_SLIDE.duplicate()
	s2_return.append_array(SLIDE.slice(5))
	_set_route(s2_slide, "s2.slide", s2_return, 2)
	s2_slide.kind = LoopData.RETURN
	s2_slide.gate_id = "s2.gate"
	var s3_loop: LoopSegment = _add(level, loop, "loop_segment", "S3Loop")
	_set_route(s3_loop, "s3.loop", S3_LOOP, 3)
	var s3_slide: LoopSegment = _add(level, loop, "loop_segment", "S3Slide")
	var s3_return: Array = S3_SLIDE.duplicate()
	s3_return.append_array(S2_SLIDE.slice(4))
	s3_return.append_array(SLIDE.slice(5))
	_set_route(s3_slide, "s3.slide", s3_return, 3)
	s3_slide.kind = LoopData.RETURN

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
	switch.trapdoor = _box_from(switch.position, TRAPDOOR)
	var basket: Basket = _add(level, frontier, "basket", "Basket")
	basket.stable_id = "s1.basket"
	basket.quota = 6
	basket.on_full_object = "s1.gate"
	basket.on_full_action = "open"
	# The pit under the trapdoor, from its rim down to its floor.
	basket.position = _at(6.895, 0)
	basket.size = Vector2(0.81 * S, 200)
	var gate: Gate = _add(level, frontier, "gate", "Gate")
	gate.stable_id = "s1.gate"
	gate.position = _at(7.8, -180)
	gate.size = Vector2(40, 160)
	gate.entrance_lid = _box_from(gate.position, ENTRANCE_LID)
	_build_section_2(level)
	return level


## Section 2, "Caves" (chunk 15; README "Section 2"): its sleepers, the cave
## branch with its route back, the framing zones and frontier set 2, whose
## basket is 1.5 screens from its switch.
func _build_section_2(level: Level) -> void:
	var section := _group(level, level, "Section2")
	var sleepers := _group(level, section, "Sleepers")
	var placed: Array = S2_SLEEPERS.duplicate()
	placed.sort_custom(func(a, b): return a[0] < b[0])
	for i in placed.size():
		var sleeper: Sleeper = _add(level, sleepers, "sleeper", "Sleeper%02d" % (i + 1))
		sleeper.stable_id = "s2.sleeper.%02d" % (i + 1)
		sleeper.species = placed[i][2]
		sleeper.position = _at(placed[i][0], placed[i][1])

	var parade := _group(level, section, "Parade")
	_frame(level, parade, "parade", _at(9.5, -150), Vector2(S, 500), 0.85, Vector2(0, -100), "s2")

	var cave := _group(level, section, "Cave")
	_branch(level, cave, "cave", Rect2(10.94 * S, -820, 1.01 * S, 540), "s2")
	_route_back(level, cave, "cave", ROUTE_BACK_CAVE, "s2")

	var frontier := _group(level, section, "FrontierSet")
	var signpost: Signpost = _add(level, frontier, "signpost", "Signpost")
	signpost.stable_id = "s2.signpost"
	signpost.switch_id = "s2.switch"
	signpost.position = _at(10.9, -20)
	var switch: Switch = _add(level, frontier, "switch", "Switch")
	switch.stable_id = "s2.switch"
	switch.basket_id = "s2.basket"
	switch.position = _at(10.97, -44)
	switch.size = Vector2(80, 80)
	switch.trapdoor = _box_from(switch.position, TRAPDOOR_2)
	var basket: Basket = _add(level, frontier, "basket", "Basket")
	basket.stable_id = "s2.basket"
	basket.quota = 15
	basket.on_full_object = "s2.gate"
	basket.on_full_action = "open"
	# The pit under the trapdoor, from its rim down to its floor.
	basket.position = _at(12.375, 65)
	basket.size = Vector2(0.35 * S, 170)
	var gate: Gate = _add(level, frontier, "gate", "Gate")
	gate.stable_id = "s2.gate"
	gate.position = _at(12.8, -100)
	gate.size = Vector2(40, 160)
	gate.entrance_lid = _box_from(gate.position, ENTRANCE_LID_2)
	_frame(level, frontier, "gate", _at(12.6, -100), Vector2(0.8 * S, 600), 0.9, Vector2(0, -40), "s2")


## A level box [x0, y0, x1, y1] (x in screens) relative to `origin`.
func _box_from(origin: Vector2, box: Array) -> Rect2:
	var from := _at(box[0], box[1])
	return Rect2(from - origin, _at(box[2], box[3]) - from)


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


func _set_route(segment: LoopSegment, id: String, points: Array, section := 1) -> void:
	segment.stable_id = id
	segment.section = section
	segment.curve = _curve(points)


func _branch(level: Level, parent: Node, name_part: String, box: Rect2, place := "s1") -> void:
	var branch: ExplorationBranch = _add(level, parent, "exploration_branch", "Branch")
	branch.stable_id = "%s.branch.%s" % [place, name_part]
	branch.position = box.get_center()
	branch.size = box.size


func _route_back(level: Level, parent: Node, name_part: String, points: Array, place := "s1") -> void:
	var route_back: RouteBack = _add(level, parent, "route_back", "RouteBack")
	route_back.stable_id = "%s.route-back.%s" % [place, name_part]
	route_back.serves = "%s.branch.%s" % [place, name_part]
	route_back.curve = _curve(points)


func _frame(level: Level, parent: Node, name_part: String, at: Vector2, size: Vector2,
		zoom: float, offset: Vector2, place := "s1") -> void:
	var frame: FramingZone = _add(level, parent, "framing_zone", "Frame")
	frame.stable_id = "%s.frame.%s" % [place, name_part]
	frame.position = at
	frame.size = size
	frame.zoom = zoom
	frame.offset = offset

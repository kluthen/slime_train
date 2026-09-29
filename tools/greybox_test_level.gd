extends SceneTree
## Generates the greybox of the test level, levels/test/level.tscn, from the
## layout tables below, using only the level components (src/components/),
## placed with the builder helpers (LevelBuilder, tools/level_builder/).
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
# @spec-link [[rule_first_section_species_count]]
# @spec-link [[rule_hints_visible_from_loop]]

const OUT := "res://levels/test/level.tscn"
## The builder's static helpers (at, ride_over, on_ledge, outlet_at).
const B := preload("res://tools/level_builder/level_builder.gd")
const S := LevelBuilder.S
## A size-1 slime's centre sits this far above the ground it rolls on.
const RIDE := LevelBuilder.RIDE

# --- Terrain (closed outlines, x in screens, y in px) ------------------------

## The top of the ground along section 1, from the start basin's terrace (the
## loop's first stretch, over the slides' lane) up out of the basin, to the
## slide entrance. The loop rides RIDE px above it.
const SURFACE := [
	# 1.1 Start basin: the terrace (flat past the first sleeper's ledge, so
	# no hop takes off steeply from under it), then the climb out (35-38°).
	[0.26, 460], [0.6, 460], [0.66, 410], [0.75, 330], [0.9, 200],
	[1.05, 80], [1.15, 50],
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
## entrance, the chute's near wall and the slide tunnel's roof back to the
## start basin, where it is the terrace's underside (the lane's roof), 40 px
## under its top.
const CRUST_REST := [
	[6.7, 100], [7.2, 100], [7.3, -100], [7.5, -100],
	[7.25, 300], [7.0, 320], [5.0, 350], [3.0, 375], [1.5, 385], [0.78, 420],
	[0.66, 470], [0.6, 500], [0.26, 500],
]
## The bedrock: the level's left wall, the start basin's pocket (behind the
## loop's start) and the ramp down from it into the slides' lane, the lane's
## floor under the terrace, the slide tunnel's floor running on under the
## pillar, section 2 (chunk 15) and section 3's bowl (chunk 16) to slide 3's
## chute, and the chute's far wall, the level's right wall. The tunnel's
## floor falls gently all the way back to the basin, so the slides carry the
## slimes home, under the terrace (the lane is about 100 px high), then up
## the ramp (60° at the top, so the train hops only 0.05 screens across it
## onto the terrace) into the pocket (chunk 16e).
const BEDROCK := [
	[0.0, -800], [0.03, -800], [0.03, 440], [0.04, 490], [0.05, 500], [0.21, 500], [0.255, 590],
	[0.28, 610], [0.64, 600], [0.78, 585],
	[1.5, 495], [3.0, 485], [5.0, 460], [7.0, 430], [7.3, 390], [8.0, 375], [8.5, 360],
	[10.5, 338], [12.5, 312], [12.62, 308], [13.3, 300], [14.5, 286], [16.3, 271], [16.55, 268],
	[16.55, -800], [16.65, -800], [16.65, 1200], [0.0, 1200],
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
}
## Section 3's crust (chunk 16; README "Section 3"): past slide 2's chute,
## gate 2's ground, then the entry ramp (3.1) down into the bowl (3.2), its
## floor (y 100), the far wall up to the plateau (3.4, y -120). The loop
## rides RIDE above S3_SURFACE. S3_CRUST_REST: basket 3's pit (floor 100),
## slide 3's chute's near wall, and back along the tunnel's roof.
const S3_SURFACE := [
	[12.72, -20], [13.0, -20],
	# 3.1 Entry ramp.
	[13.1, -12], [13.2, 8], [13.3, 38], [13.4, 68], [13.5, 90], [13.6, 100],
	# 3.2 The bowl's floor, then its far wall (gentler than section 1's lip).
	[15.05, 100], [15.15, 90], [15.25, 62], [15.35, 20], [15.45, -32], [15.55, -88], [15.62, -120],
	# 3.4 The plateau before basket 3's pit.
	[15.72, -120],
]
const S3_CRUST_REST := [
	[15.72, 100], [16.3, 100], [16.3, -120], [16.4, -120],
	[16.4, 160], [14.5, 176], [12.72, 190],
]
## Section 3's ledges: [name, x0, x1, top at x0, top at x1] (x in screens),
## 25 px thick. The entry ramp's two side ledges are flat; the bowl's shelves
## tilt inward (down toward the bowl's middle), in three tiers on each side,
## each tier's inner end past the one above, so a woken slime rolls off into
## the bowl, which is the loop (rules 7, 8). The rim tilts down toward the
## bowl too.
const S3_RAMP_LEDGES := [
	["RampLedge1", 12.96, 13.18, -210, -210],
	["RampLedge2", 13.22, 13.42, -160, -160],
]
const S3_SHELVES := [
	["ShelfL1", 13.56, 14.18, -105, -90],
	["ShelfL2", 13.49, 14.11, -265, -250],
	["ShelfL3", 13.42, 14.04, -425, -410],
	["ShelfR1", 14.28, 14.9, -90, -105],
	["ShelfR2", 14.34, 14.96, -250, -265],
	["ShelfR3", 14.4, 15.02, -410, -425],
]
const S3_RIM := ["Rim", 15.05, 16.192, -300, -310]
const S3_LEDGE_THICKNESS := 25.0
## Floating greybox pieces: name -> outline.
const PIECES := {
	"FirstLedge": [[0.42, 335], [0.5, 335], [0.5, 355], [0.42, 355]],
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

## The loop out: from the start of the loop, at the top of the ramp out of
## the slides' lane, up over the ramp (60 px above the loop's start, so the
## train's hops clear a slime sitting in the ramp, and that slime, off the
## loop, is carried back up by the slide) and down onto the terrace, then
## RIDE above SURFACE (after its first point, the terrace's corner), out of
## the basin and over the bridge to the slide entrance.
const LOOP_START := [[0.21, 476], [0.25, 416]]
const LOOP_END := [[7.6, -124]]
## Slide 1, the section's return route: down the chute and back under the
## surface, along the lane under the start basin's terrace and up the ramp to
## the start of the loop, so a slime coming home joins the train behind its
## start, never along its first stretch (chunk 16e).
const SLIDE := [
	[7.6, -124], [7.54, 0], [7.43, 150], [7.31, 300], [7.0, 406], [5.0, 436],
	[3.0, 461], [1.5, 471], [0.78, 561], [0.64, 576], [0.28, 586], [0.255, 566], [0.21, 476],
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
## Section 3 (chunk 16): on from slide 2's entrance through gate 2, RIDE
## above S3_SURFACE (down the ramp, across the bowl, up the far wall, over
## basket 3's trapdoor) to slide 3's entrance at 16.4; then slide 3, the
## level's last return route (no gate), down the chute and back along the
## tunnel to slide 2's.
const S3_LOOP_END := [[16.4, -144]]
const S3_SLIDE := [
	[16.4, -144], [16.475, -60], [16.475, 150], [16.45, 240], [16.3, 247], [14.5, 262],
	[13.3, 276], [12.66, 283], [12.55, 285],
]
## Frontier set 3's trapdoor (as TRAPDOOR): over basket 3's pit, on the
## plateau. Set 3 has no gate: its target is the celebration (D77).
const TRAPDOOR_3 := [15.72, -120, 16.3, -95]
## The bowl's routes back: down the tiers of shelves from their inner ends
## to the bowl's floor (the loop), and along the rim to its left end, then
## down to the floor.
const ROUTE_BACK_LEFT_SHELVES := [
	[13.44, -449], [14.04, -434], [14.07, -275], [14.11, -274], [14.14, -115], [14.18, -114],
	[14.23, 76],
]
const ROUTE_BACK_RIGHT_SHELVES := [
	[15.0, -449], [14.4, -434], [14.37, -275], [14.34, -274], [14.31, -115], [14.28, -114],
	[14.23, 76],
]
const ROUTE_BACK_RIM := [[16.17, -334], [15.07, -324], [15.02, 76]]
## Section 3's sleepers: 5 E on each ramp ledge; 15 on each shelf and 30 on
## the rim, their species taken in turn from S3_SPECIES_CYCLE (README
## population: shelves A, B, C, D 15 each and E 30; rim A, B, C, D 5 each
## and E 10). Spacing along a ledge, in screens.
const S3_SPECIES_CYCLE := ["A", "E", "B", "E", "C", "D"]
const S3_SLEEPERS_PER_RAMP_LEDGE := 5
const S3_SLEEPERS_PER_SHELF := 15
const S3_SLEEPERS_ON_RIM := 30
const S3_SLEEPER_STEP := 0.04
const S3_RIM_STEP := 0.038
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
const SLEEPERS_BEFORE_HILLS := [[0.46, 311, "B"]]
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
	var builder := _build()
	var error := builder.save(OUT)
	builder.level.free()
	if error != OK:
		printerr("greybox_test_level: failed (error %d)" % error)
		quit(1)
		return
	print("greybox_test_level: wrote %s" % OUT)
	quit(0)


func _build() -> LevelBuilder:
	var b := LevelBuilder.new("test", 1, "TestLevel")
	var level := b.level

	var terrain := b.group(level, "Terrain")
	var surface_rest: Array = SURFACE.duplicate()
	surface_rest.append_array(CRUST_REST)
	b.terrain(terrain, "Crust", surface_rest)
	b.terrain(terrain, "Bedrock", BEDROCK)
	for piece in PIECES:
		b.terrain(terrain, piece, PIECES[piece])
	b.terrain(terrain, "S2Crust", S2_CRUST)
	for piece in S2_PIECES:
		b.terrain(terrain, piece, S2_PIECES[piece])
	var s3_crust: Array = S3_SURFACE.duplicate()
	s3_crust.append_array(S3_CRUST_REST)
	b.terrain(terrain, "S3Crust", s3_crust)
	for ledge in S3_RAMP_LEDGES + S3_SHELVES + [S3_RIM]:
		b.terrain(terrain, ledge[0], [
			[ledge[1], ledge[3]], [ledge[2], ledge[4]],
			[ledge[2], ledge[4] + S3_LEDGE_THICKNESS], [ledge[1], ledge[3] + S3_LEDGE_THICKNESS],
		])
	for i in HILL_BUMPS.size():
		var x: float = HILL_BUMPS[i][0]
		var tilt: float = BUMP_TILT * HILL_BUMPS[i][1]
		b.terrain(terrain, "HillBump%d" % (i + 1), [
			[x - BUMP_HALF_WIDTH, BUMP_TOP - tilt], [x + BUMP_HALF_WIDTH, BUMP_TOP + tilt],
			[x + BUMP_HALF_WIDTH, BUMP_TOP + tilt + 25], [x - BUMP_HALF_WIDTH, BUMP_TOP - tilt + 25],
		])
	# A Terrain with no collision (it predates the Decoration component).
	var trunk := b.terrain(terrain, "TreeTrunk", TRUNK)
	trunk.has_collision = false
	trunk.fill_color = Color(0.18, 0.18, 0.2)
	trunk.outline_width = 0.0
	trunk.z_index = -1

	var loop := b.loop()
	var outgoing: Array = LOOP_START.duplicate()
	outgoing.append_array(B.ride_over(SURFACE.slice(1)))
	outgoing.append_array(LOOP_END)
	b.segment(loop, "s1.loop", outgoing, 1, LoopData.OUTGOING, "")
	b.segment(loop, "s1.slide", SLIDE, 1, LoopData.RETURN, "s1.gate")
	b.segment(loop, "s2.loop", S2_LOOP, 2, LoopData.OUTGOING, "")
	var s2_return: Array = S2_SLIDE.duplicate()
	s2_return.append_array(SLIDE.slice(5))
	b.segment(loop, "s2.slide", s2_return, 2, LoopData.RETURN, "s2.gate")
	var s3_outgoing: Array = [S2_LOOP[-1]]
	s3_outgoing.append_array(B.ride_over(S3_SURFACE.slice(1)))
	s3_outgoing.append_array(S3_LOOP_END)
	b.segment(loop, "s3.loop", s3_outgoing, 3, LoopData.OUTGOING, "")
	var s3_return: Array = S3_SLIDE.duplicate()
	s3_return.append_array(S2_SLIDE.slice(4))
	s3_return.append_array(SLIDE.slice(5))
	b.segment(loop, "s3.slide", s3_return, 3, LoopData.RETURN, "")

	var start := b.group(level, "Start")
	# The pocket, the ramp's top and the terrace up to past the first
	# sleeper's ledge (x 0.03 to 0.54): only base slimes pass under the
	# ledge, low enough for a called base slime to hop onto (rules 2, 18).
	b.split_zone(start, "start.split-zone", B.at(0.285, 465), Vector2(0.51 * S, 190))
	b.first_slime(start, "A", B.at(0.19, 476))

	var section := b.group(level, "Section1")
	var sleepers := b.group(section, "Sleepers")
	var placed: Array = SLEEPERS_BEFORE_HILLS.duplicate()
	var n := 0
	for bump in HILL_BUMPS:
		for side in [-1, 1]:
			var x: float = bump[0] + 0.04 * side
			var top: float = BUMP_TOP + BUMP_TILT * bump[1] * (x - bump[0]) / BUMP_HALF_WIDTH
			placed.append([x, top - RIDE, HILL_SPECIES[n % 3]])
			n += 1
	placed.append_array(SLEEPERS_AFTER_HILLS)
	b.sleeper_row(sleepers, "s1", placed)

	var high_step := b.group(section, "HighStep")
	b.branch(high_step, "s1", "high-step", Rect2(3.68 * S, -560, 0.82 * S, 390))
	b.route_back(high_step, "s1", "high-step", ROUTE_BACK_HIGH_STEP)
	b.frame(high_step, "s1", "high-step", B.at(4.0, -250), Vector2(S, 600), 0.85, Vector2(0, -120))

	var tree := b.group(section, "Tree")
	b.branch(tree, "s1", "tree", Rect2(4.6 * S, -900, 1.3 * S, 790))
	b.route_back(tree, "s1", "tree", ROUTE_BACK_TREE)
	b.frame(tree, "s1", "tree", B.at(5.0, -300), Vector2(S, 700), 0.7, Vector2(0, -250))

	var frontier := b.group(section, "FrontierSet")
	# Basket 1 is the pit under the trapdoor, from its rim down to its floor.
	b.frontier_set(frontier, "s1", B.at(6.4, -100), B.at(6.47, -124), TRAPDOOR,
			B.at(6.895, 0), Vector2(0.81 * S, 200), 6, B.at(7.8, -180), ENTRANCE_LID)
	_build_section_2(b)
	_build_section_3(b)
	return b


## Section 2, "Caves" (chunk 15; README "Section 2"): its sleepers, the cave
## branch with its route back and framing zone (chunk 16d), the other
## framing zones and frontier set 2, whose basket is 1.5 screens from its
## switch.
func _build_section_2(b: LevelBuilder) -> void:
	var section := b.group(b.level, "Section2")
	var sleepers := b.group(section, "Sleepers")
	b.sleeper_row(sleepers, "s2", S2_SLEEPERS)

	var parade := b.group(section, "Parade")
	b.frame(parade, "s2", "parade", B.at(9.5, -150), Vector2(S, 500), 0.85, Vector2(0, -100))

	var cave := b.group(section, "Cave")
	b.branch(cave, "s2", "cave", Rect2(10.94 * S, -820, 1.01 * S, 540))
	b.route_back(cave, "s2", "cave", ROUTE_BACK_CAVE)
	# Rule 9 (chunk 16d): along the cave's entrance stretch of the loop, the
	# view zooms out and shifts up until the pocket's sleepers (y -724) are
	# in it with the loop: settled, it spans y -767 to 159.
	b.frame(cave, "s2", "cave", B.at(11.25, -150), Vector2(1.3 * S, 500), 0.7, Vector2(0, -140))

	var frontier := b.group(section, "FrontierSet")
	# Basket 2 is the pit under the trapdoor, from its rim down to its floor.
	b.frontier_set(frontier, "s2", B.at(10.9, -20), B.at(10.97, -44), TRAPDOOR_2,
			B.at(12.375, 65), Vector2(0.35 * S, 170), 15, B.at(12.8, -100), ENTRANCE_LID_2)
	b.frame(frontier, "s2", "gate", B.at(12.6, -100), Vector2(0.8 * S, 600), 0.9, Vector2(0, -40))


## Section 3, "Big bowl" (chunk 16; README "Section 3"): its 130 sleepers on
## the ramp's ledges, the bowl's shelves and the rim, numbered left to right
## (then top to bottom); the shelves' and the rim's branches with their
## routes back; the framing zones; and frontier set 3, whose basket's target
## is the level-complete celebration (no gate, no rule: the celebration
## plays once every basket has fired).
func _build_section_3(b: LevelBuilder) -> void:
	var section := b.group(b.level, "Section3")
	var sleepers := b.group(section, "Sleepers")
	var placed: Array = []
	for ledge in S3_RAMP_LEDGES:
		for i in S3_SLEEPERS_PER_RAMP_LEDGE:
			placed.append(B.on_ledge(ledge, ledge[1] + 0.02 + S3_SLEEPER_STEP * i, "E"))
	var n := 0
	for shelf in S3_SHELVES:
		for i in S3_SLEEPERS_PER_SHELF:
			placed.append(B.on_ledge(shelf, shelf[1] + 0.02 + S3_SLEEPER_STEP * i,
					S3_SPECIES_CYCLE[n % S3_SPECIES_CYCLE.size()]))
			n += 1
	for i in S3_SLEEPERS_ON_RIM:
		placed.append(B.on_ledge(S3_RIM, S3_RIM[1] + 0.02 + S3_RIM_STEP * i,
				S3_SPECIES_CYCLE[i % S3_SPECIES_CYCLE.size()]))
	b.sleeper_row(sleepers, "s3", placed)

	var bowl := b.group(section, "Bowl")
	b.frame(bowl, "s3", "bowl", B.at(14.375, -150), Vector2(1.85 * S, 500), 0.5, Vector2(0, -200))
	var left := b.group(bowl, "LeftShelves")
	b.branch(left, "s3", "left-shelves", Rect2(13.41 * S, -520, 0.83 * S, 440))
	b.route_back(left, "s3", "left-shelves", ROUTE_BACK_LEFT_SHELVES)
	var right := b.group(bowl, "RightShelves")
	b.branch(right, "s3", "right-shelves", Rect2(14.26 * S, -520, 0.77 * S, 440))
	b.route_back(right, "s3", "right-shelves", ROUTE_BACK_RIGHT_SHELVES)

	var rim := b.group(section, "Rim")
	b.branch(rim, "s3", "rim", Rect2(15.04 * S, -400, 1.18 * S, 115))
	b.route_back(rim, "s3", "rim", ROUTE_BACK_RIM)

	var frontier := b.group(section, "FrontierSet")
	# No gate and no target object: the celebration (D77) is the level's,
	# once every basket has fired. Basket 3 is the pit under the trapdoor,
	# from its rim down to its floor.
	var set_3 := b.frontier_set(frontier, "s3", B.at(15.62, -120), B.at(15.67, -144), TRAPDOOR_3,
			B.at(16.01, -10), Vector2(0.58 * S, 220), 60)
	# It releases onto the loop 200 px before slide 3's entrance (with no
	# gate, "onward_route" has no slide entrance to find).
	B.outlet_at(set_3.basket, B.at(S3_LOOP_END[0][0], S3_LOOP_END[0][1])
			- Vector2(set_3.basket.outlet_before, 0))
	b.frame(frontier, "s3", "basket", B.at(15.875, -150), Vector2(1.15 * S, 400), 0.8, Vector2(0, 40))

extends SceneTree
## The new-level scaffolder (chunk LD1): writes a new level's skeleton, its
## fresh fixture and its own test, once, then never touches them again. From
## there the level is edited by hand in the Godot editor
## (docs/dev/level-tooling.md).
##
## Run from the project root:
##   tools/level.sh new --id=<id> [--sections=N]
## (tools/level.sh imports the project first; the raw command is
##   godot --headless --no-header --path . -s res://tools/new_level.gd -- --id=<id> [--sections=N])
##
##   --id=<id>       the new level's ID (LevelCatalog: lowercase letters and
##                   digits, words joined by hyphens; not "test")
##   --sections=N    how many sections, 1 to Species.COUNT - 2 (default 1)
##
## It writes:
##   levels/<id>/level.tscn                  the skeleton (below)
##   levels/<id>/fixtures/fresh.fixture.json the level as new (no save)
##   tests/e2e/levels/test_level_<id>.gd     the level's test, from
##                                           tools/new_level/test_level.gd.template
## and refuses (writing nothing) when the ID is invalid or "test", or when
## levels/<id>/ or that test already exists. Exit code: 0 written, 1 refused
## (something is already there), 2 bad arguments, 3 a write failed (what this
## run wrote is removed).
##
## The skeleton already follows every level rule the checker
## (tools/check_level.gd) can verify on it. It reuses geometry proven in the
## test level (tools/greybox_test_level.gd): the start basin (the pocket
## behind the loop's start, the ramp, the terrace, the first sleeper's
## ledge, the split zone reaching past it, the lane under the terrace where
## the return routes come home, rule 22) and, per section, frontier set 1's
## geometry (the trapdoor over the pit basket, the chute down to the tunnel,
## the pillar carrying the loop on through the gate, whose lid shuts the
## chute once open). Before each set, a dip in the loop with a hollow on
## each rim holds the section's sleepers (the test level's DipHollow, chunk
## LD3): a called base slime on the rim hops across into the hollow, and no
## ledge a base slime is called up to overhangs the loop where larger
## slimes pass (rule 22), since the ground under a hollow is the dip's
## slope, too far down to hop up from. So every sleeper can be woken from
## the start and each basket's quota is met by then (the level report's
## progress estimate, and the level's own test plays section 1). Each
## section repeats it SECTION_WIDTH screens to the right and SECTION_RISE px
## higher, so the shared tunnel under them always falls toward the start.
## x is in screens, y in level px (y grows downward), as in the builder
## (LevelBuilder).
# @spec-link [[req_level_design_rules]]
# @spec-link [[rule_start_carries_split_zone]]
# @spec-link [[rule_loop_travelable_with_no_input]]
# @spec-link [[rule_return_route_per_section]]

const USAGE := "usage: tools/level.sh new --id=<id> [--sections=N]"
const TEMPLATE := "res://tools/new_level/test_level.gd.template"
## The template's placeholder for the level's ID.
const ID_PLACEHOLDER := "{{LEVEL_ID}}"
const TESTS_DIR := "res://tests/e2e/levels/"
## The fresh fixture: make_fixture's generic one (one description for both).
const LEVEL_FIXTURES := preload("res://tools/make_fixture/level_fixtures.gd")
const FRESH_FIXTURE := {"description": LEVEL_FIXTURES.FRESH_DESCRIPTION, "save": false}
## The builder's static helpers (at, ride_over, on_ledge, outlet_at).
const B := preload("res://tools/level_builder/level_builder.gd")
const S := LevelBuilder.S
const RIDE := LevelBuilder.RIDE
## Section 1 has 3 species, each later one adds one (rule 11): at most this
## many sections.
const MAX_SECTIONS := Species.COUNT - 2

# --- The start basin (the test level's, chunk 16e) -----------------------------

## The terrace (the loop's first stretch) and the climb out of the basin.
const BASIN_SURFACE := [[0.26, 460], [0.6, 460], [0.66, 410], [0.75, 330], [0.9, 200], [1.05, 80], [1.15, 50]]
## On up to section 1's ground (SECTION_1_GROUND).
const SECTION_1_RISE := [[1.3, 20], [1.6, -20], [1.9, -70], [2.2, -100]]
## The terrace's underside back from the tunnel's roof: the lane's roof.
const BASIN_UNDERSIDE := [[1.5, 385], [0.78, 420], [0.66, 470], [0.6, 500], [0.26, 500]]
## The bedrock under the basin: the left wall, the pocket, the ramp down into
## the lane, the lane's floor; the tunnel's floor goes on from its last point.
const BASIN_BEDROCK := [
	[0.0, -800], [0.03, -800], [0.03, 440], [0.04, 490], [0.05, 500], [0.21, 500], [0.255, 590],
	[0.28, 610], [0.64, 600], [0.78, 585], [1.5, 495],
]
## The loop's start, at the top of the ramp, and its rise over the ramp.
const LOOP_START := [[0.21, 476], [0.25, 416]]
## Every return route's tail: along the lane and up the ramp to the loop's
## start, behind the train (rule 22).
const RETURN_TAIL := [[1.5, 471], [0.78, 561], [0.64, 576], [0.28, 586], [0.255, 566], [0.21, 476]]
const FIRST_LEDGE := [[0.42, 335], [0.5, 335], [0.5, 355], [0.42, 355]]
const FIRST_SLIME_AT := [0.19, 476]
const FIRST_SLEEPER := [0.46, 311, "B"]
## The split zone: x 0.03 to 0.54, y 370 to 560 (past the first ledge).
const SPLIT_ZONE_CENTRE := [0.285, 465]
const SPLIT_ZONE_SIZE := Vector2(0.51 * S, 190)

# --- The sections ---------------------------------------------------------------

## Section 1's frontier set's origin (the test level's set 1 is at 6.0), and
## how far apart the sections' sets are, screens.
const SECTION_1_SET := 3.0
const SECTION_WIDTH := 3.7
## Section 1's ground, and how much higher each later section's is, px.
const SECTION_1_GROUND := -100.0
const SECTION_RISE := 100.0
## Each basket's quota (weight): the section's own slimes can fill it.
const QUOTA := 4
## A section's dip, on its flat ground before the set: its left rim from
## the set's origin, screens, and its ground, [x from the left rim
## (screens), px below the section's ground], its right rim last. Its upper
## slopes fall 100 px in 0.1 screens (the test level's first dip: 0.12), so
## the ground is at least 40 px down under a hollow: its underside clears a
## size-3 hop (130 px) and its top is out of a called hop's reach from there.
const DIP_AT := -0.65
const DIP := [[0.0, 0], [0.1, 100], [0.22, 150], [0.4, 165], [0.58, 150], [0.7, 100], [0.8, 0]]
## The hollow on each of the dip's rims (the test level's DipHollow): over
## the dip's slope, from HOLLOW_SPAN[0] to HOLLOW_SPAN[1] screens from its
## rim, its floor HOLLOW_FLOOR px above the section's ground (110, as
## DipHollow's over its rim: a called base slime on the rim hops up 110 px
## and across), with lips HOLLOW_LIP px higher at both ends so its sleepers
## stay in, HOLLOW_THICKNESS px thick. Its two sleepers rest ON_HOLLOW
## screens from the rim, within a called base slime's hop sideways
## (Train.hop_reach, 150 px = 0.13 screens).
const HOLLOW_SPAN := [0.04, 0.16]
const HOLLOW_FLOOR := 110.0
const HOLLOW_LIP := 20.0
const HOLLOW_THICKNESS := 20.0
const ON_HOLLOW := [0.075, 0.12]
## The dip's rims: "left" (its hollow lies rightward, over the dip) and
## "right" (leftward).
const RIMS := ["left", "right"]


var _id := ""
var _sections := 1
## The files and folders this run created, to undo a failed write.
var _written: Array[String] = []


## Parses the arguments, refuses or writes the level, and quits with the
## exit code.
func _init() -> void:
	var code := _parse()
	if code == 0:
		code = _refusal()
	if code == 0:
		code = _write()
	quit(code)


# --- Arguments --------------------------------------------------------------------

## Reads the arguments. Returns 0, or 2 on a bad one.
func _parse() -> int:
	var has_id := false
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"--id":
				_id = value
				has_id = true
			"--sections":
				if not value.is_valid_int() or value.to_int() < 1 or value.to_int() > MAX_SECTIONS:
					return _fail(2, "--sections wants a number from 1 to %d (got '%s'): section 1 has 3 species "
							% [MAX_SECTIONS, value] + "and each later one adds one, of the game's %d" % Species.COUNT)
				_sections = value.to_int()
			_:
				return _fail(2, "unknown argument '%s'" % arg)
	if not has_id:
		return _fail(2, "give the new level's ID with --id=<id>")
	if not LevelCatalog.is_valid_id(_id):
		return _fail(2, "invalid level ID '%s': use lowercase letters and digits, words joined by hyphens "
				% _id + "(for example 01 or my-level)")
	if _id == LevelCatalog.DEFAULT_ID:
		return _fail(2, "'%s' is the test level (tools/greybox_test_level.gd makes it): pick another ID" % _id)
	return 0


## 1 when the level's folder or its test is already there (nothing is ever
## overwritten), else 0.
func _refusal() -> int:
	var folder := LevelCatalog.dir_of(_id)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)) \
			or FileAccess.file_exists(folder.trim_suffix("/")):
		return _fail(1, "%s already exists: the scaffolder never overwrites a level. Pick another ID, " % folder
				+ "or delete that folder first if you really mean to start it again")
	if FileAccess.file_exists(test_path(_id)):
		return _fail(1, "%s already exists: the scaffolder never overwrites a level's test. Pick another ID, "
				% test_path(_id) + "or delete that file first if you really mean to start the level again")
	return 0


## Prints `message` and the usage as an error; returns `code`.
static func _fail(code: int, message: String) -> int:
	printerr("new_level: %s" % message)
	printerr(USAGE)
	return code


## The level's test script.
static func test_path(id: String) -> String:
	return TESTS_DIR + "test_level_%s.gd" % id


# --- Writing ------------------------------------------------------------------------

## Writes the three files. Returns 0, or 3 when a write failed (after
## removing what this run wrote).
func _write() -> int:
	var fixture := LevelCatalog.fixtures_dir(_id) + "fresh" + TestMode.SIDECAR_EXTENSION
	var test := test_path(_id)
	var problem := _make_dir(LevelCatalog.fixtures_dir(_id))
	if problem.is_empty():
		problem = _make_dir(TESTS_DIR)
	if problem.is_empty():
		var builder := build(_id, _sections)
		var error := builder.save(LevelCatalog.scene_path(_id))
		builder.level.free()
		_written.append(LevelCatalog.scene_path(_id))
		if error != OK:
			problem = "couldn't save %s (error %d)" % [LevelCatalog.scene_path(_id), error]
	if problem.is_empty():
		problem = _write_text(fixture, JSON.stringify(FRESH_FIXTURE, "\t") + "\n")
	if problem.is_empty():
		problem = _write_text(test, _test_script())
	if not problem.is_empty():
		_undo()
		printerr("new_level: %s; nothing was kept" % problem)
		return 3
	print("new_level: wrote level %s (%d section%s):" % [_id, _sections, "s" if _sections > 1 else ""])
	for path in [LevelCatalog.scene_path(_id), fixture, test]:
		print("  " + path)
	print("Next steps:")
	print("  1. Open %s in the Godot editor and make it your level: the skeleton is a start, " % LevelCatalog.scene_path(_id)
			+ "not the level's design. Don't run this tool on it again.")
	print("  2. Check the level rules:  tools/level.sh check --level=%s" % _id)
	print("     and read its report:    tools/level.sh report --level=%s" % _id)
	print("  3. Run the level's test:   tools/test.sh -gdisable_colors -gselect=test_level_%s" % _id)
	print("  4. Play it:                godot --path . -- --test-mode --level=%s --seed=1" % _id)
	return 0


## The level's test: the template with the level's ID filled in.
func _test_script() -> String:
	var text := FileAccess.get_file_as_string(TEMPLATE)
	assert(ID_PLACEHOLDER in text, "new_level: %s has no %s" % [TEMPLATE, ID_PLACEHOLDER])
	return text.replace(ID_PLACEHOLDER, _id)


## Makes folder `dir` (res://) and those above it, noting the ones it made.
## Returns "" or the problem.
func _make_dir(dir: String) -> String:
	var missing: Array[String] = []
	var path := dir.trim_suffix("/")
	while not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		missing.push_front(path)
		path = path.get_base_dir()
	for each in missing:
		if DirAccess.make_dir_absolute(ProjectSettings.globalize_path(each)) != OK:
			return "couldn't make the folder %s" % each
		_written.append(each + "/")
	return ""


## Writes `text` to `path`. Returns "" or the problem.
func _write_text(path: String, text: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "couldn't write %s (error %d)" % [path, FileAccess.get_open_error()]
	_written.append(path)
	file.store_string(text)
	file.close()
	return ""


## Removes what this run wrote, files then folders, the newest first.
func _undo() -> void:
	for k in range(_written.size() - 1, -1, -1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_written[k].trim_suffix("/")))


# --- The skeleton -------------------------------------------------------------------

## Section `n`'s frontier set's origin, screens (the test level's set 1 at
## 6.0 has its pit from 6.49, its chute at 7.6 and its pillar to 8.5).
static func set_at(n: int) -> float:
	return SECTION_1_SET + SECTION_WIDTH * (n - 1)


## Section `n`'s ground, y px.
static func ground(n: int) -> float:
	return SECTION_1_GROUND - SECTION_RISE * (n - 1)


## The level `id` with `sections` sections, in a builder (free its level).
static func build(id: String, sections: int) -> LevelBuilder:
	var b := LevelBuilder.new(id, 1, "Level" + _pascal(id))
	var terrain := b.group(b.level, "Terrain")
	_build_terrain(b, terrain, sections)
	_build_loop(b, sections)
	_build_start(b)
	for n in range(1, sections + 1):
		_build_section(b, n, n == sections)
	return b


## The terrain: section 1's crust (the basin's terrace and the ground up to
## set 1), each later section's crust, the pillars, the hollows, the first
## ledge and the bedrock under it all (the tunnel's floor).
static func _build_terrain(b: LevelBuilder, parent: Node, sections: int) -> void:
	var crust: Array = BASIN_SURFACE + SECTION_1_RISE + _dip(1) + _set_ground(1)
	crust.append_array(BASIN_UNDERSIDE)
	b.terrain(parent, "S1Crust", crust)
	b.terrain(parent, "FirstLedge", FIRST_LEDGE)
	var bedrock: Array = BASIN_BEDROCK.duplicate()
	for n in range(1, sections + 1):
		var o := set_at(n)
		var g := ground(n)
		if n > 1:
			var back := set_at(n - 1) + 2.5
			var before := ground(n - 1)
			var piece: Array = [[back, before], [back + 0.4, g]]
			piece.append_array(_dip(n))
			piece.append_array(_set_ground(n))
			piece.append([back, before + 280])
			b.terrain(parent, "S%dCrust" % n, piece)
		# The chute's far wall, carrying the loop on to the gate.
		b.terrain(parent, "S%dPillar" % n, [[o + 1.66, g], [o + 2.5, g], [o + 2.5, g + 280], [o + 1.6, g + 280],
				[o + 1.5, g + 250], [o + 1.66, g + 130]])
		for side in RIMS:
			b.terrain(parent, "S%dHollow%s" % [n, side.capitalize()], _hollow(n, side))
		# The tunnel's floor where the chute lands, then rising under the pillar.
		bedrock.append_array([[o + 1.0, g + 530], [o + 1.3, g + 490]])
	var end := set_at(sections) + 2.5
	var top := ground(sections) - 700
	bedrock.append_array([[end, ground(sections) + 470], [end, top], [end + 0.1, top], [end + 0.1, 1200], [0.0, 1200]])
	b.terrain(parent, "Bedrock", bedrock)


## Section `n`'s dip's ground, left to right (DIP).
static func _dip(n: int) -> Array:
	var out := []
	for point in DIP:
		out.append([set_at(n) + DIP_AT + point[0], ground(n) + point[1]])
	return out


## Where section `n`'s dip's rim `side` is (x, screens), and which way its
## hollow lies from it (1: rightward, -1: leftward).
static func _rim(n: int, side: String) -> Array:
	var left := set_at(n) + DIP_AT
	return [left, 1] if side == "left" else [left + DIP[DIP.size() - 1][0], -1]


## The outline of section `n`'s hollow on rim `side`: a cup, lips at both
## ends, floor between, left to right along the top, then its underside.
## It hangs over the dip's slope, not over the loop where larger slimes hop
## at a called base slime's reach (rule 22 (b)): see HOLLOW_SPAN and DIP.
# @spec-link [[rule_no_called_ledge_over_loop]]
static func _hollow(n: int, side: String) -> Array:
	var rim: Array = _rim(n, side)
	var ends := [rim[0] + rim[1] * HOLLOW_SPAN[0], rim[0] + rim[1] * HOLLOW_SPAN[1]]
	var x0: float = ends.min()
	var x1: float = ends.max()
	var floor_y := ground(n) - HOLLOW_FLOOR
	var lip := floor_y - HOLLOW_LIP
	var under := floor_y + HOLLOW_THICKNESS
	return [[x0, lip], [x0 + 0.02, floor_y], [x1 - 0.02, floor_y], [x1, lip], [x1, under], [x0, under]]


## Section `n`'s ground from its set's pit on (test level set 1's crust):
## the pit under the trapdoor, the ground before the chute, the chute's near
## wall and the start of the tunnel's roof.
static func _set_ground(n: int) -> Array:
	var o := set_at(n)
	var g := ground(n)
	return [[o + 0.49, g], [o + 0.7, g + 200], [o + 1.2, g + 200], [o + 1.3, g], [o + 1.5, g],
			[o + 1.25, g + 400], [o + 1.0, g + 420]]


## The loop: per section, its outgoing segment `s<n>.loop` along the
## ground to the chute's top (the frontier while the gate is closed), then
## its return route `s<n>.slide` down the chute and home along the tunnel
## under the earlier sections, into the start behind the loop's start (rule
## 22). A return route names its section's gate, none for the last.
# @spec-link [[rule_loop_travelable_with_no_input]]
# @spec-link [[rule_return_route_per_section]]
static func _build_loop(b: LevelBuilder, sections: int) -> void:
	var loop := b.loop()
	for n in range(1, sections + 1):
		var o := set_at(n)
		var g := ground(n)
		var outgoing: Array
		if n == 1:
			outgoing = LOOP_START + B.ride_over(BASIN_SURFACE.slice(1) + SECTION_1_RISE + _dip(1) + [[o + 0.49, g]])
		else:
			var back := set_at(n - 1)
			outgoing = [[back + 1.6, ground(n - 1) - RIDE]]
			outgoing.append_array(B.ride_over([[back + 2.5, ground(n - 1)], [back + 2.9, g]] + _dip(n)
					+ [[o + 0.49, g]]))
		outgoing.append([o + 1.6, g - RIDE])
		b.segment(loop, "s%d.loop" % n, outgoing, n, LoopData.OUTGOING, "")
		var slide: Array = [[o + 1.6, g - RIDE], [o + 1.54, g + 100], [o + 1.43, g + 250], [o + 1.31, g + 400],
				[o + 1.0, g + 506]]
		for k in range(n - 1, 0, -1):
			slide.append_array([[set_at(k) + 1.3, ground(k) + 466], [set_at(k) + 1.0, ground(k) + 506]])
		slide.append_array(RETURN_TAIL)
		b.segment(loop, "s%d.slide" % n, slide, n, LoopData.RETURN, "s%d.gate" % n if n < sections else "")


## The start: the split zone over the loop's start, the pocket, the ramp's
## top and the terrace past the first ledge (rules 4, 22), and the first
## slime (A) in the pocket.
# @spec-link [[rule_start_carries_split_zone]]
static func _build_start(b: LevelBuilder) -> void:
	var start := b.group(b.level, "Start")
	b.split_zone(start, "start.split-zone", B.at(SPLIT_ZONE_CENTRE[0], SPLIT_ZONE_CENTRE[1]), SPLIT_ZONE_SIZE)
	b.first_slime(start, "A", B.at(FIRST_SLIME_AT[0], FIRST_SLIME_AT[1]))


## Section `n`: its sleepers (section 1: the first sleeper, B, on the first
## ledge, then C, C in the dip's left hollow and A, B in its right one, so
## every species can pair up; later sections: three of the species the
## section adds and one earlier one, rule 11) and its frontier set. The
## last section's set has no gate: its basket's target is the celebration
## (D77), and it releases 200 px before the chute.
static func _build_section(b: LevelBuilder, n: int, last: bool) -> void:
	var o := set_at(n)
	var g := ground(n)
	var section := b.group(b.level, "Section%d" % n)
	var species: Array = ["C", "C", "A", "B"]
	if n > 1:
		var added := Species.letter(n + 1)
		species = [added, added, added, Species.letter((n - 2) % 3)]
	var placed: Array = [FIRST_SLEEPER] if n == 1 else []
	var spots := []
	for side in RIMS:
		var rim: Array = _rim(n, side)
		for along in ON_HOLLOW:
			spots.append(rim[0] + rim[1] * along)
	spots.sort()
	for k in spots.size():
		placed.append([spots[k], g - HOLLOW_FLOOR - RIDE, species[k]])
	b.sleeper_row(b.group(section, "Sleepers"), "s%d" % n, placed)
	var frontier := b.group(section, "FrontierSet")
	var place := "s%d" % n
	var trapdoor := [o + 0.5, g, o + 1.29, g + 25]
	var basket_at := B.at(o + 0.895, g + 100)
	var basket_size := Vector2(0.81 * S, 200)
	if last:
		var set_n := b.frontier_set(frontier, place, B.at(o + 0.4, g), B.at(o + 0.47, g - RIDE), trapdoor,
				basket_at, basket_size, QUOTA)
		B.outlet_at(set_n.basket, B.at(o + 1.6, g - RIDE) - Vector2(set_n.basket.outlet_before, 0))
	else:
		b.frontier_set(frontier, place, B.at(o + 0.4, g), B.at(o + 0.47, g - RIDE), trapdoor, basket_at,
				basket_size, QUOTA, B.at(o + 1.8, g - 80), [o + 1.49, g, o + 1.67, g + 32])


## "my-level" -> "MyLevel", "01" -> "01": the level root's node name part.
static func _pascal(id: String) -> String:
	var out := ""
	for part in id.split("-", false):
		out += part.left(1).to_upper() + part.substr(1)
	return out

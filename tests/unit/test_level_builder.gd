extends GutTest
## Chunk LD1: the level builder's helpers (tools/level_builder/) place the
## level components with the stable-ID conventions, in the design's units (x
## in screens, y in level pixels), and a level built with them loads with no
## errors and saves and loads back the same.

# @test-link [[req_level_design_rules]]

const B := preload("res://tools/level_builder/level_builder.gd")
const TEMP_DIR := "user://test_level_builder"
const TEMP_SCENE := TEMP_DIR + "/level.tscn"
## The sleepers' places, out of order; two share an x.
const SLEEPERS := [[1.5, -100, "C"], [0.5, -100, "A"], [1.0, -60, "B"], [1.0, -120, "D"]]


func after_each() -> void:
	var dir := DirAccess.open(TEMP_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(TEMP_DIR)


## A small level: ground, a loop (an outgoing segment and its return route),
## the start (split zone, first slime), a sleeper row, a branch with its
## route back and framing zone, a frontier set with its gate, a decoration.
func _small_level() -> LevelBuilder:
	var b := LevelBuilder.new("unit", 3, "UnitLevel")
	var terrain := b.group(b.level, "Terrain")
	b.terrain(terrain, "Ground", [[0.0, 0], [2.2, 0], [2.2, 400], [0.0, 400]])
	b.decoration(terrain, "Bush", [[0.3, 0], [0.4, -50], [0.5, 0]])
	b.decoration(terrain, "Vine", [[0.6, 0], [0.7, -50], [0.8, 0]], true)
	var loop := b.loop()
	b.segment(loop, "s1.loop", B.ride_over([[0.2, 0], [1.0, 0], [2.0, 0]]), 1, LoopData.OUTGOING, "")
	b.segment(loop, "s1.slide", [[2.0, -24], [2.1, 300], [0.1, 300], [0.2, -24]], 1, LoopData.RETURN,
			"s1.gate")
	var start := b.group(b.level, "Start")
	b.split_zone(start, "start.split-zone", B.at(0.25, -24), Vector2(0.2 * B.S, 100))
	b.first_slime(start, "B", B.at(0.18, -24))
	var section := b.group(b.level, "Section1")
	b.sleeper_row(b.group(section, "Sleepers"), "s1", SLEEPERS)
	var hill := b.group(section, "Hill")
	b.branch(hill, "s1", "hill", Rect2(0.9 * B.S, -300, 0.3 * B.S, 200))
	b.route_back(hill, "s1", "hill", [[1.0, -200], [1.1, -24]])
	b.frame(hill, "s1", "hill", B.at(1.0, -150), Vector2(B.S, 400), 0.8, Vector2(0, -60))
	b.frontier_set(b.group(section, "FrontierSet"), "s1", B.at(1.6, 0), B.at(1.7, -24), [1.65, 0, 1.8, 25],
			B.at(1.725, 100), Vector2(0.15 * B.S, 150), 4, B.at(1.9, -80), [1.95, 0, 2.05, 20])
	autofree(b.level)
	return b


func test_a_level_built_with_the_helpers_has_no_load_errors() -> void:
	var level := _small_level().level
	assert_eq(level.build(), PackedStringArray())
	var expected := PackedStringArray([
		"s1.basket", "s1.branch.hill", "s1.frame.hill", "s1.gate", "s1.loop", "s1.route-back.hill",
		"s1.signpost", "s1.slide", "s1.sleeper.01", "s1.sleeper.02", "s1.sleeper.03", "s1.sleeper.04",
		"s1.switch", "start.first-slime", "start.loop", "start.split-zone",
	])
	expected.sort()
	assert_eq(level.ids(), expected)
	assert_eq(level.name, &"UnitLevel")
	assert_eq(level.level_id, "unit")
	assert_eq(level.level_version, 3)
	assert_eq(level.data.loop.validate(), PackedStringArray())


func test_units_are_screens_across_and_pixels_down() -> void:
	assert_eq(B.at(1.5, -40), Vector2(1.5 * LevelData.SCREEN, -40))
	assert_eq(B.box_from(B.at(1.0, 0), [1.0, -10, 1.5, 30]), Rect2(0, -10, 0.5 * LevelData.SCREEN, 40))
	assert_eq(B.ride_over([[1.0, 0], [2.0, -10]]), [[1.0, -24.0], [2.0, -34.0]])
	assert_eq(B.on_ledge(["Ledge", 1.0, 2.0, -100, -200], 1.5, "A"), [1.5, -174.0, "A"])
	var curve := B.curve([[0.5, 10], [1.0, 20]])
	assert_eq(curve.point_count, 2)
	assert_eq(curve.get_point_position(1), Vector2(LevelData.SCREEN, 20))


func test_the_things_are_where_and_what_was_asked() -> void:
	var level := _small_level().level
	level.build()
	var ground: Terrain = level.get_node("Terrain/Ground")
	assert_eq(ground.curve.point_count, 5, "the outline is closed")
	assert_eq(ground.curve.get_point_position(4), ground.curve.get_point_position(0))
	var bush: Decoration = level.get_node("Terrain/Bush")
	assert_eq(bush.curve.point_count, 4)
	assert_false(bush.in_front)
	assert_eq(bush.z_index, Decoration.Z_BEHIND)
	assert_true((level.get_node("Terrain/Vine") as Decoration).in_front)
	var outgoing: LoopSegment = level.get_node("Loop/S1Loop")
	assert_eq(outgoing, level.find("s1.loop"))
	assert_eq([outgoing.section, outgoing.kind, outgoing.gate_id], [1, LoopData.OUTGOING, ""])
	assert_eq(outgoing.curve.get_point_position(0), B.at(0.2, -24))
	var slide: LoopSegment = level.get_node("Loop/S1Slide")
	assert_eq([slide.stable_id, slide.kind, slide.gate_id], ["s1.slide", LoopData.RETURN, "s1.gate"])
	assert_eq(level.find("start.split-zone").position, B.at(0.25, -24))
	assert_eq(level.find("start.first-slime").species, "B")
	assert_eq(level.start_position(), B.at(0.18, -24))
	var branch: ExplorationBranch = level.find("s1.branch.hill")
	assert_true(level.box_of(branch, branch.size).is_equal_approx(Rect2(0.9 * B.S, -300, 0.3 * B.S, 200)))
	assert_eq(level.find("s1.route-back.hill").serves, "s1.branch.hill")
	var frame: FramingZone = level.find("s1.frame.hill")
	assert_eq([frame.position, frame.size, frame.zoom, frame.offset],
			[B.at(1.0, -150), Vector2(B.S, 400), 0.8, Vector2(0, -60)])


func test_the_sleepers_are_numbered_left_to_right() -> void:
	var level := _small_level().level
	var names := []
	var places := []
	for sleeper in level.get_node("Section1/Sleepers").get_children():
		names.append([sleeper.name, sleeper.stable_id, sleeper.species])
		places.append(sleeper.position)
	assert_eq(names, [
		[&"Sleeper01", "s1.sleeper.01", "A"], [&"Sleeper02", "s1.sleeper.02", "D"],
		[&"Sleeper03", "s1.sleeper.03", "B"], [&"Sleeper04", "s1.sleeper.04", "C"],
	], "left to right, top to bottom on the same x")
	assert_eq(places, [B.at(0.5, -100), B.at(1.0, -120), B.at(1.0, -60), B.at(1.5, -100)])
	assert_eq(SLEEPERS[0], [1.5, -100, "C"], "the caller's places are left as they were")


func test_sleeper_numbers_take_three_digits_past_99() -> void:
	var b := LevelBuilder.new("unit", 1, "UnitLevel")
	autofree(b.level)
	var placed := []
	for i in 101:
		placed.append([0.01 * i, -100, "A"])
	var sleepers := b.sleeper_row(b.level, "s2", placed)
	assert_eq(sleepers.size(), 101)
	assert_eq([sleepers[8].name, sleepers[8].stable_id], [&"Sleeper09", "s2.sleeper.09"])
	assert_eq([sleepers[99].name, sleepers[99].stable_id], [&"Sleeper100", "s2.sleeper.100"])
	assert_eq(sleepers[100].stable_id, "s2.sleeper.101")


func test_a_frontier_set_with_its_gate() -> void:
	var level := _small_level().level
	level.build()
	var switch: Switch = level.find("s1.switch")
	assert_eq([switch.position, switch.size, switch.basket_id], [B.at(1.7, -24), Vector2(80, 80), "s1.basket"])
	assert_true(level.rect_of(switch, switch.trapdoor).is_equal_approx(Rect2(B.at(1.65, 0), B.at(0.15, 25))),
			"the trapdoor, a level box")
	assert_eq(level.find("s1.signpost").switch_id, "s1.switch")
	assert_eq(level.find("s1.signpost").position, B.at(1.6, 0))
	var basket: Basket = level.find("s1.basket")
	assert_eq([basket.position, basket.size, basket.quota], [B.at(1.725, 100), Vector2(0.15 * B.S, 150), 4])
	assert_eq(level.data.rules, [
		{"when": {"object": "s1.basket", "event": "full"}, "then": {"object": "s1.gate", "action": "open"}},
	])
	var gate: Gate = level.find("s1.gate")
	assert_eq([gate.position, gate.size], [B.at(1.9, -80), Vector2(40, 160)])
	assert_true(level.rect_of(gate, gate.entrance_lid).is_equal_approx(Rect2(B.at(1.95, 0), B.at(0.1, 20))),
			"the entrance lid, a level box")


func test_a_frontier_set_with_no_gate_and_its_outlet() -> void:
	var b := LevelBuilder.new("unit", 1, "UnitLevel")
	autofree(b.level)
	var set_3 := b.frontier_set(b.level, "s3", B.at(1.0, 0), B.at(1.1, -24), [1.1, 0, 1.3, 25],
			B.at(1.2, 100), Vector2(100, 100), 9)
	assert_null(set_3.gate)
	assert_null(b.level.get_node_or_null("Gate"))
	assert_eq(set_3.basket.on_full_object, "", "no target: the celebration's")
	assert_true(set_3.basket.rules().is_empty())
	B.outlet_at(set_3.basket, B.at(1.4, -24))
	assert_eq(set_3.basket.outlet, "point")
	assert_true((set_3.basket.position + set_3.basket.outlet_point).is_equal_approx(B.at(1.4, -24)))


func test_it_saves_and_loads_back_the_same() -> void:
	var b := _small_level()
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	assert_eq(b.save(TEMP_SCENE), OK)
	var packed: PackedScene = ResourceLoader.load(TEMP_SCENE, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_not_null(packed)
	var loaded: Level = autofree(packed.instantiate())
	assert_eq(loaded.build(), PackedStringArray())
	assert_eq(_describe(loaded), _describe(b.level))


## Every node the level owns (and the root): its path, its script and its
## saved properties (a curve as its points).
func _describe(level: Level) -> Array:
	var out := []
	for node: Node in [level] + level.find_children("*", "", true, false):
		if node != level and node.owner != level:
			continue
		var properties := {"position": node.get("position"), "z_index": node.get("z_index")}
		for property in node.get_property_list():
			if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and property["usage"] & PROPERTY_USAGE_STORAGE:
				properties[property["name"]] = node.get(property["name"])
		if node is Path2D:
			var points := []
			for i in node.curve.point_count:
				points.append(node.curve.get_point_position(i))
			properties["curve"] = points
		out.append([str(level.get_path_to(node)), node.get_script(), properties])
	return out

extends GutTest
## Chunk LD3: the progress estimate (tools/level_check/level_progress.gd),
## on small levels built in code: whether each section's basket can be
## filled by the base slimes a called slime can wake by then, and rule 12's
## warning when it can't. The scaffolder's first skeleton put its sleepers
## on plates a called base slime couldn't reach, so section 1 couldn't fill
## its basket, and nothing said so; this is the check that would have
## caught it (the generated level test plays section 1 to prove it in play).
##
## The level: a floor (its top at FLOOR_Y), the loop a base slime's centre
## above it, with a drop of DROP px at DROP_X (x in screens), the start's
## split zone, the first slime (A), sleepers on ledges placed per test, and
## one frontier set whose basket has the quota the test gives.

# @test-link [[rule_gate_opens_via_switch_basket_set]]
# @test-link [[rule_sleepers_never_on_loop]]

const S := LevelData.SCREEN
const FLOOR_Y := 600.0
const LOOP_Y := FLOOR_Y - LevelBuilder.RIDE
## Where the loop drops, screens, and by how much, px.
const DROP_X := 1.5
const DROP := 200.0
const FRONTIER_X := 3.0


## The small level, built (out of the tree), with `sleepers` ([x, rise
## above the loop to the sleeper's centre (px), species]) and its basket's
## `quota`; freed after the test.
func _level(sleepers: Array, quota: int) -> Level:
	var b := LevelBuilder.new("progress", 1, "Progress")
	var terrain := b.group(b.level, "Terrain")
	var low := FLOOR_Y + DROP
	b.terrain(terrain, "Floor", [[-0.5, FLOOR_Y], [DROP_X, FLOOR_Y], [DROP_X + 0.05, low], [FRONTIER_X + 1.0, low],
			[FRONTIER_X + 1.0, low + 300], [-0.5, low + 300]])
	var loop := b.loop()
	b.segment(loop, "s1.loop", [[0.2, LOOP_Y], [DROP_X, LOOP_Y], [DROP_X + 0.05, low - LevelBuilder.RIDE],
			[FRONTIER_X, low - LevelBuilder.RIDE]], 1, LoopData.OUTGOING, "")
	b.segment(loop, "s1.slide", [[FRONTIER_X, low - LevelBuilder.RIDE], [FRONTIER_X, 300], [0.2, 300],
			[0.2, LOOP_Y]], 1, LoopData.RETURN, "")
	var start := b.group(b.level, "Start")
	b.split_zone(start, "start.split-zone", LevelBuilder.at(0.3, LOOP_Y), Vector2(0.3 * S, 150))
	b.first_slime(start, "A", LevelBuilder.at(0.25, LOOP_Y))
	var one := b.group(b.level, "Section1")
	var placed := []
	for each in sleepers:
		var ground: float = LOOP_Y if each[0] < DROP_X else low - LevelBuilder.RIDE
		placed.append([each[0], ground - each[1], each[2]])
	b.sleeper_row(one, "s1", placed)
	var set_y := low - LevelBuilder.RIDE
	var last := b.frontier_set(one, "s1", LevelBuilder.at(2.5, set_y), LevelBuilder.at(2.6, set_y),
			[2.62, low, 2.8, low + 25], LevelBuilder.at(2.7, low + 100), Vector2(0.2 * S, 150), quota)
	LevelBuilder.outlet_at(last.basket, LevelBuilder.at(2.9, set_y))
	autofree(b.level)
	assert_eq(b.level.build(), PackedStringArray(), "the small level builds")
	return b.level


func _estimate(level: Level) -> Dictionary:
	return LevelProgress.estimate(LevelChecker.new(level))[0]


func test_a_sleeper_out_of_a_called_hop_leaves_the_section_short_and_rule_12_warns() -> void:
	# The first skeleton's case: the only sleeper 170 px over the loop.
	var level := _level([[1.0, 170.0, "B"]], 2)
	var plan := _estimate(level)
	assert_eq(plan["woken"], [])
	assert_eq(plan["unreached"], ["s1.sleeper.01"])
	assert_eq(plan["available"], 1, "the first slime alone")
	assert_false(plan["progresses"])
	var result := LevelChecker.new(level).check(12, true)
	assert_eq(result["status"], LevelChecker.PASS, "a warning, not a FAIL: the estimate is static")
	assert_eq(result["warnings"].size(), 1)
	if result["warnings"].size() == 1:
		assert_eq(result["warnings"][0]["id"], "s1.basket")
		assert_string_contains(result["warnings"][0]["text"], "section 1 may not progress: its basket's quota is 2")
		assert_string_contains(result["warnings"][0]["text"], "s1.sleeper.01")
	var text := LevelChecker.format([result])
	assert_true(text.contains("         warn: s1.basket (x "), text)
	assert_eq(LevelChecker.warning_count([result]), 1)
	var json = JSON.parse_string(JSON.stringify(LevelChecker.to_json_data([result])))
	assert_not_null(json, "valid JSON")


func test_a_sleeper_within_a_called_hop_is_counted_and_nothing_warns() -> void:
	var level := _level([[1.0, 110.0, "B"]], 2)
	var plan := _estimate(level)
	assert_eq(plan["woken"], ["s1.sleeper.01"])
	assert_eq(plan["species"], {"A": 1, "B": 1})
	assert_true(plan["progresses"])
	assert_eq(LevelChecker.new(level).check(12, true)["warnings"], [])


func test_a_same_species_pair_reaches_higher_than_a_base_slime() -> void:
	# 150 px is beyond a called base slime (about 133) but within a size 2
	# (about 168): reached once a second A is awake to fuse with the first.
	var paired := _estimate(_level([[0.8, 110.0, "A"], [1.1, 150.0, "C"]], 3))
	assert_eq(paired["woken"], ["s1.sleeper.01", "s1.sleeper.02"])
	assert_eq(paired["largest"], 2)
	assert_true(paired["progresses"])
	var unpaired := _estimate(_level([[0.8, 110.0, "B"], [1.1, 150.0, "C"]], 3))
	assert_eq(unpaired["woken"], ["s1.sleeper.01"], "A and B don't fuse: size 1 only")
	assert_eq(unpaired["unreached"], ["s1.sleeper.02"])
	assert_false(unpaired["progresses"])


func test_the_take_off_is_the_loop_point_least_below_within_a_hop_sideways() -> void:
	# A hollow over the drop, 110 px above the upper loop (310 above the
	# lower): reached from the drop's rim, 0.08 screens away, not from under
	# it; 0.3 screens past the rim is too far sideways for any size's hop.
	var level := _level([], 2)
	var checker := LevelChecker.new(level)
	var near := Vector2((DROP_X + 0.08) * S, LOOP_Y - 110.0)
	var take_off := LevelProgress.take_off(checker, 1, near)
	assert_true(take_off["reaches"], str(take_off))
	assert_almost_eq(take_off["rise"], 110.0, 0.5)
	assert_almost_eq((take_off["from"] as Vector2).y, LOOP_Y, 0.5, "from the rim, not the ground under it")
	assert_eq(LevelProgress.smallest_size(checker, 1, near), 1)
	var far := Vector2((DROP_X + 0.3) * S, LOOP_Y - 110.0)
	assert_false(LevelProgress.take_off(checker, 1, far)["reaches"])
	assert_eq(LevelProgress.smallest_size(checker, 1, far), 0, "310 px up from under it: beyond every size")

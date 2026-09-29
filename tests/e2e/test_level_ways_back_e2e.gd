extends GutTest
## Chunk 16: rules 7 and 8 (specs/level-design.md) on the whole test level,
## by behaviour. Every spot a sleeper sits on is a spot a free slime reaches;
## from it, a woken slime heading back must get back to the loop with no
## input: by gravity and its own hops, along its branch's route back inside
## an exploration branch. test_test_level.gd checks the routes back as
## data (they start in their branch, only go down, end on the loop).
##
## For each section, the level as the loop first reaches it
## (LevelChecker.start_state: fresh, with the gates before it open as after
## their baskets fired), with every other slime taken out so nothing but the
## terrain is in the way: the sleeper's slime is made free, heading back, and
## simulated (the core runs with every slime simulated: off-screen projection
## off, so the terrain decides) until it rejoins the train, at most the time
## a free slime off screen takes to be left alone and then lost (70 s).
## Sleepers sit in rows (ledges, shelves, the rim, bumps); a row's middle is
## between its ends, so the two ends of every row are tried. The rows, the
## start states and the runs are the level-rules checker's (LevelChecker,
## chunk LD1; its rule 7 does the same).

# @test-link [[rule_gravity_leads_back_to_loop]]
# @test-link [[rule_exploration_branch_has_route_back]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
const SEED := 909
## The longest a slime may take to get back: left alone, then lost (D10).
const DEADLINE := Offscreen.LEFT_ALONE_TICKS + Offscreen.LOST_TICKS
## Known breaks of rule 7 in the built level, reported rather than hidden:
## sleeper ID -> why its slime doesn't get back. Each is still run, checked
## to still be stuck (so a fixed one can't linger here), and marked pending
## instead of failing. None since chunk 16d: the seven that chunk 16c found
## (the dip hollows, `s1.sleeper.14`, `.15`, `s2.sleeper.15`, `.16`; the
## hills' bumps 2, 4 and 6, `s1.sleeper.04`, `.08`, `.13`) were ring points
## pulled onto sharp terrain corners (TerrainSegments' vertex normals).
const KNOWN_STUCK := {}

var level: Level
var checker: LevelChecker


func before_all() -> void:
	level = load(LEVEL_SCENE).instantiate()
	add_child(level)
	checker = LevelChecker.new(level)


func after_all() -> void:
	level.free()


## The stable IDs of section `section`'s sleepers.
func _sleepers_of(section: int) -> Array:
	return level.data.sleepers.keys().filter(func(id): return id.begins_with("s%d." % section))


## Rules 7 and 8 from both ends of every row of section `section`'s sleepers.
func _check_section(section: int) -> void:
	var slowest := 0
	var stuck := []
	var tried := checker.row_ends(section)
	for stable_id in tried:
		assert_has(_sleepers_of(section), stable_id, "%s is asleep in the level" % stable_id)
		var ticks := checker.way_back_ticks(section, stable_id, SEED, DEADLINE)
		slowest = maxi(slowest, ticks)
		if ticks < 0:
			stuck.append(stable_id)
		if KNOWN_STUCK.has(stable_id):
			assert_lt(ticks, 0, "%s now gets back: take it out of KNOWN_STUCK" % stable_id)
		else:
			assert_gt(ticks, 0, "a slime woken at %s gets back to the loop within %d s" % [stable_id,
					DEADLINE / Simulation.TICK_RATE])
	gut.p("section %d: %d spots tried, slowest back in %.1f s, stuck: %s" % [section, tried.size(),
			slowest / float(Simulation.TICK_RATE), stuck])
	var known_by_reason := {}
	for stable_id in stuck:
		if KNOWN_STUCK.has(stable_id):
			var reason: String = KNOWN_STUCK[stable_id]
			if not known_by_reason.has(reason):
				known_by_reason[reason] = []
			known_by_reason[reason].append(stable_id)
	for reason in known_by_reason:
		pending("rule 7 broken at %s: %s" % [", ".join(known_by_reason[reason]), reason])


func test_every_sleeper_is_in_a_row_and_the_rows_are_on_one_ledge() -> void:
	assert_eq(Array(checker.sections()), [1, 2, 3])
	for section in checker.sections():
		var count := 0
		for row in checker.sleeper_rows(section):
			count += row.size()
			var first: Vector2 = level.data.sleepers[row[0]]["position"]
			var last: Vector2 = level.data.sleepers[row[row.size() - 1]]["position"]
			assert_lt(absf(last.y - first.y), 60.0, "%s to %s: one ledge" % [row[0], row[row.size() - 1]])
		assert_eq(count, _sleepers_of(section).size())
	assert_eq(checker.sleeper_rows(3).size(), 8,
			"section 3: the ramp's shelf, 5 shelves and the rim's two parts (chunk TL1; was 2 ramp ledges, 6 shelves "
			+ "and the rim)")


func test_section_1_every_sleepers_spot_leads_back_to_the_loop() -> void:
	_check_section(1)


func test_section_2_every_sleepers_spot_leads_back_to_the_loop() -> void:
	_check_section(2)


func test_section_3_every_sleepers_spot_leads_back_to_the_loop() -> void:
	_check_section(3)

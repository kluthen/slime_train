extends GutTest
## The slime census (src/debug/slime_census.gd): a census of a known fixture
## (its header, one line per slime, its footer, the key fields, every line
## under logcat's cut), its --census-every / --census-until arguments and
## schedule (the census ticks), the game root taking them only in a debug
## build and handing the schedule every tick, the hold and nudge it reports
## matching the decision code's records, and the census changing no state
## (the same state hash with and without it, on both ticks). perf.sh's
## --census check is here too.

# @test-link [[req_platform_and_performance_targets]]

const MAIN_SCENE := "res://src/main.tscn"
const PERF_SH := "res://tools/android/perf.sh"
const FIXTURE := "bump"
const SEED := 909
## The keys every slime line carries, and those a train slime's adds.
const SLIME_KEYS: PackedStringArray = ["id", "sid", "species", "size", "state", "calm", "detail", "held",
		"supported", "still", "pile", "pos", "vel", "hop_timer", "on_screen", "in_range", "fusion_view", "section",
		"loop_segment", "route", "loop_gap", "zones", "door", "hold", "touch", "touch_held", "contact", "stuck", "due"]
const TRAIN_KEYS: PackedStringArray = ["dist", "laps", "progress", "rank", "ahead", "gap_ahead", "to_frontier",
		"on_slide", "mark_age", "stall_in", "steer_from", "off_route", "slope", "grip", "dip_floor", "nudge",
		"hop_due", "reach", "in_air"]
const HEADER_KEYS: PackedStringArray = ["tick", "time", "slimes", "tick_kind", "fixture", "reason"]


## The test level's fixture `name` loaded as tools/bench_level.gd loads it
## (the camera where the fixture puts it, off-screen simulation on), on the
## native tick or not; null with a failure.
func _fixture_sim(name: String, native: bool) -> Simulation:
	var level: Level = autofree(load(LevelCatalog.scene_path(LevelCatalog.DEFAULT_ID)).instantiate())
	assert_eq(level.build(), PackedStringArray(), "the test level builds")
	var loaded := TestMode.load_fixture(name)
	assert_true(loaded["ok"], "fixture %s loads" % name)
	var sim := Simulation.from_save(loaded["save"], level.data, SlimeWorld.terrain_from(level), SEED)
	assert_not_null(sim)
	assert_true(sim.slimes.use_native(native), "the tick asked for")
	var camera: Variant = loaded["camera"]
	if camera is String:
		camera = level.point_of(camera)
	if camera != null:
		sim.camera.start(level.data.loop, sim.train.open_gates, camera)
	sim.offscreen.enabled = true
	sim.hint.world_shown(sim.tick)
	return sim


func _step(sim: Simulation) -> void:
	sim.camera.apply_to(sim.view, ScreenView.DEFAULT_SIZE)
	sim.step()


## A census line's key=value tokens (after its two-word tag) as a dictionary.
func _fields(line: String) -> Dictionary:
	var out := {}
	var tokens := line.split(" ")
	for k in range(2, tokens.size()):
		var key := tokens[k].get_slice("=", 0)
		out[key] = tokens[k].substr(key.length() + 1)
	return out


func _has_native() -> bool:
	return ClassDB.class_exists(TickChoice.SOLVER_CLASS)


# --- One census -------------------------------------------------------------------

func test_a_census_has_its_header_one_line_per_slime_and_its_footer() -> void:
	var sim := _fixture_sim(FIXTURE, false)
	for t in 60:
		_step(sim)
	var lines := SlimeCensus.lines(sim, SlimeCensus.BUTTON, FIXTURE)
	var ids := sim.slimes.ids()
	assert_eq(lines.size(), ids.size() + 2, "a header, a line per slime, a footer")
	assert_true(lines[0].begins_with("CENSUS begin tick=60 time=1.00 slimes=%d " % ids.size()), lines[0])
	var header := _fields(lines[0])
	for key in HEADER_KEYS:
		assert_true(header.has(key), "the header has %s" % key)
	assert_eq(header["tick_kind"], "gdscript")
	assert_eq(header["fixture"], FIXTURE)
	assert_eq(header["reason"], SlimeCensus.BUTTON)
	var footer := lines[lines.size() - 1]
	assert_true(footer.begins_with("CENSUS end tick=60 lines=%d ms=" % ids.size()), footer)
	var trains := 0
	var ranks := {}
	for k in ids.size():
		var line := lines[k + 1]
		assert_true(line.begins_with("CENSUS slime id=%d " % ids[k]), "slime lines in id order: %s" % line)
		assert_lt(line.to_utf8_buffer().size(), 3500, "under logcat's cut")
		assert_false(line.contains("  ") or line.contains("\t"), "single spaces only")
		var fields := _fields(line)
		for key in SLIME_KEYS:
			assert_true(fields.has(key), "slime %d's line has %s" % [ids[k], key])
		assert_eq(fields["state"], SlimeBodies.STATE_NAMES[sim.slimes.state_of(ids[k])])
		assert_eq(fields["size"], str(sim.slimes.size_of(ids[k])))
		if fields["state"] == "train":
			trains += 1
			for key in TRAIN_KEYS:
				assert_true(fields.has(key), "train slime %d's line has %s" % [ids[k], key])
			ranks[int(fields["rank"])] = ids[k]
	assert_gt(trains, 0, "the fixture has train slimes")
	assert_eq(ranks.size(), trains, "one rank each")
	assert_eq(ranks.keys().min(), 1)
	assert_eq(ranks.keys().max(), trains, "ranks 1 to the train's size")


func test_the_front_is_the_furthest_along_the_loop_and_the_gap_is_to_the_one_ahead() -> void:
	var sim := _fixture_sim(FIXTURE, false)
	for t in 30:
		_step(sim)
	var by_rank := {}
	for line in SlimeCensus.lines(sim, SlimeCensus.TIMER):
		var fields := _fields(line)
		if fields.get("state", "") == "train":
			by_rank[int(fields["rank"])] = fields
	for rank: int in by_rank:
		var fields: Dictionary = by_rank[rank]
		if rank == 1:
			assert_eq(fields["ahead"], "-", "nobody ahead of the front")
			continue
		var ahead: Dictionary = by_rank[rank - 1]
		assert_eq(fields["ahead"], ahead["id"])
		assert_almost_eq(float(fields["gap_ahead"]), float(ahead["dist"]) - float(fields["dist"]), 0.11)
		assert_gte(float(ahead["dist"]), float(fields["dist"]), "front first")


func test_the_hold_and_the_hop_decision_match_the_decision_records() -> void:
	var sim := _fixture_sim(FIXTURE, false)
	var nudged_seen := false
	var hops_seen := false
	for t in 240:
		_step(sim)
		if t % 20 != 19:
			continue
		for line in SlimeCensus.lines(sim, SlimeCensus.TIMER):
			var fields := _fields(line)
			if fields.get("state", "") != "train":
				continue
			var slime_id := int(fields["id"])
			var why: String = sim.fusion.nudged.get(slime_id, "")
			assert_eq(fields["nudge"], why if why != "" else "-", "slime %d's nudge" % slime_id)
			if why != "":
				nudged_seen = true
				assert_true(fields["hold"].contains("dip_" + why), "the hold names the nudge")
			assert_eq(fields["in_air"], "1" if sim.train.hop_log.in_air(slime_id) else "0")
			var last: Dictionary = sim.train.hop_log.last_hops.get(slime_id, {})
			if not last.is_empty():
				hops_seen = true
				assert_eq(fields["last_hop"], str(last["tick"]))
				assert_true(last["kind"] in [Train.TARGET_AHEAD, Train.TARGET_STEP_FOOT, Train.TARGET_STEP_OVER,
						Train.TARGET_DROP, Train.UNAIMED], "a known kind: %s" % last["kind"])
			if fields.has("next_kind"):
				assert_true(fields["next_kind"] in [Train.TARGET_AHEAD, Train.TARGET_STEP_FOOT,
						Train.TARGET_STEP_OVER, Train.TARGET_DROP], fields["next_kind"])
	assert_true(nudged_seen, "bump's slimes on the dip's floor get nudged")
	assert_true(hops_seen, "train hops recorded")


func test_a_door_against_a_slime_shows_in_its_line() -> void:
	var sim := _fixture_sim(FIXTURE, false)
	var shut := SlimeCensus.shut_doors(sim)
	assert_false(shut.is_empty(), "the fresh frontier sets have shut doors")
	var door_id: String = shut.keys()[0]
	var box: Rect2 = shut[door_id]
	var on_top := sim.slimes.create(0, 1, Vector2(box.get_center().x, box.position.y - 21.0), SlimeBodies.FREE)
	var doors := SlimeCensus.doors_against(sim, on_top, shut)
	assert_eq(doors, PackedStringArray([door_id + ":floor"]), "standing on it")
	assert_eq(SlimeCensus.hold_of(sim, on_top, doors), "-", "a floor holds nothing back")
	var beside := sim.slimes.create(0, 1, Vector2(box.position.x - 21.0, box.get_center().y), SlimeBodies.FREE)
	doors = SlimeCensus.doors_against(sim, beside, shut)
	assert_eq(doors, PackedStringArray([door_id + ":wall"]), "beside it")
	assert_eq(SlimeCensus.hold_of(sim, beside, doors), "door")
	var far := sim.slimes.create(0, 1, box.get_center() + Vector2(0, -1000), SlimeBodies.FREE)
	assert_eq(SlimeCensus.doors_against(sim, far, shut), PackedStringArray())


func test_a_long_list_is_cut_to_keep_the_line_under_the_cut() -> void:
	var items := PackedStringArray()
	for k in 2000:
		items.append(str(100000 + k))
	var tokens := PackedStringArray(["CENSUS", "slime", "id=1", "touch=" + ",".join(items)])
	var line := SlimeCensus._fit(tokens)
	assert_lt(line.to_utf8_buffer().size(), SlimeCensus.MAX_LINE)
	assert_true(line.begins_with("CENSUS slime id=1 touch=100000,100001,"), line.left(60))
	assert_true(RegEx.create_from_string(",\\+\\d+$").search(line) != null, "ends with how many were cut")


# --- No state change --------------------------------------------------------------

func test_the_census_changes_no_state_on_the_gdscript_tick() -> void:
	_check_no_state_change(false)


func test_the_census_changes_no_state_on_the_native_tick() -> void:
	if not _has_native():
		pending("the slime_native extension isn't loaded")
		return
	_check_no_state_change(true)


## Two runs of the fixture, one taking a census after every tick: the same
## state hash all along, and the census's lines the same for the same state.
func _check_no_state_change(native: bool) -> void:
	var plain := _fixture_sim(FIXTURE, native)
	var counted := _fixture_sim(FIXTURE, native)
	for t in 180:
		_step(plain)
		_step(counted)
		var first := SlimeCensus.lines(counted, SlimeCensus.TIMER)
		var again := SlimeCensus.lines(counted, SlimeCensus.TIMER)
		if t % 30 == 29:
			assert_eq(counted.state_hash(), plain.state_hash(), "tick %d: same state" % counted.tick)
			first.remove_at(first.size() - 1)
			again.remove_at(again.size() - 1)
			assert_eq(again, first, "tick %d: a census is the same twice (no footer: its time)" % counted.tick)


# --- The schedule and the arguments -----------------------------------------------

func test_the_schedule_fires_every_n_seconds_until_t() -> void:
	var census := SlimeCensus.new(10.0, 60.0)
	var fired := PackedInt32Array()
	for tick in 5000:
		if census.due(tick):
			fired.append(tick)
	assert_eq(fired, PackedInt32Array([600, 1200, 1800, 2400, 3000, 3600]), "10 s to 60 s, not at tick 0")
	var open := SlimeCensus.new(0.5)
	assert_true(open.due(30) and open.due(30 * 1000), "no end")
	assert_false(open.due(0) or open.due(31))
	assert_eq(SlimeCensus.new(0.001).every_ticks, 1, "at least a tick")


func test_after_tick_takes_and_prints_a_census_when_due() -> void:
	var sim := _fixture_sim(FIXTURE, false)
	var census := SlimeCensus.new(0.5, 1.0)
	var ticks := PackedInt32Array()
	for t in 100:
		_step(sim)
		if census.after_tick(sim, FIXTURE):
			ticks.append(sim.tick)
	assert_eq(ticks, PackedInt32Array([30, 60]))
	assert_eq(census.taken, 2)


func test_parse_args() -> void:
	var none := SlimeCensus.parse_args(PackedStringArray(["--test-mode", "--perf-log=1"]))
	assert_false(none["requested"])
	assert_eq(none["errors"], PackedStringArray())
	var both := SlimeCensus.parse_args(PackedStringArray(["--census-every=10", "--census-until=60"]))
	assert_true(both["requested"])
	assert_eq([both["every"], both["until"]], [10.0, 60.0])
	assert_eq(both["errors"], PackedStringArray())
	var every := SlimeCensus.parse_args(PackedStringArray(["--census-every=2.5"]))
	assert_eq([every["every"], every["until"]], [2.5, -1.0], "no end")
	for bad in [["--census-until=60"], ["--census-every=0"], ["--census-every=x"], ["--census-every"],
			["--census-every=1", "--census-every=2"], ["--census-every=1", "--census-until=-3"]]:
		var parsed := SlimeCensus.parse_args(PackedStringArray(bad))
		assert_true(parsed["requested"], str(bad))
		assert_eq(parsed["errors"].size(), 1, "%s: one error (%s)" % [str(bad), str(parsed["errors"])])


func test_test_mode_leaves_the_census_flags_to_the_game_root() -> void:
	var parsed := TestMode.config_from_args(PackedStringArray(["--test-mode", "--census-every=10",
			"--census-until=60"]))
	assert_eq(parsed["errors"], PackedStringArray())


# --- The game root ----------------------------------------------------------------

func _game_with_guard(is_debug_build: bool) -> Node:
	var game: Node = load(MAIN_SCENE).instantiate()
	game.test_mode_guard = TestModeGuard.new(is_debug_build)
	game.launch_args = PackedStringArray()
	add_child_autofree(game)
	return game


func test_the_game_root_takes_the_census_flags_in_a_debug_build_only() -> void:
	var args := PackedStringArray(["--census-every=10", "--census-until=60"])
	var release := _game_with_guard(false)
	assert_eq(release.use_census(args), {"line": load("res://src/main.gd").CENSUS_IGNORED, "errors": PackedStringArray()})
	assert_null(release.census, "a release build ignores them")
	var debug := _game_with_guard(true)
	assert_eq(debug.use_census(PackedStringArray()), {"line": "", "errors": PackedStringArray()})
	assert_null(debug.census, "not asked")
	var bad: Dictionary = debug.use_census(PackedStringArray(["--census-until=60"]))
	assert_eq(bad["errors"].size(), 1)
	assert_null(debug.census, "a bad flag turns nothing on")
	var used: Dictionary = debug.use_census(args)
	assert_eq(used["errors"], PackedStringArray())
	assert_eq(used["line"], "Census: every 10.0 s of game time, until 60.0 s.")
	assert_not_null(debug.census)
	assert_eq([debug.census.every_ticks, debug.census.until_ticks], [600, 3600])


func test_the_game_root_hands_the_schedule_every_tick() -> void:
	var game := _game_with_guard(true)
	assert_eq(game.enable_test_mode({"seed": SEED, "time_scale": 0, "fixture": FIXTURE}), PackedStringArray())
	assert_eq(game.use_census(PackedStringArray(["--census-every=0.5", "--census-until=1"]))["errors"],
			PackedStringArray())
	game.test_mode.run_ticks(100)
	assert_eq(game.census.taken, 2, "at ticks 30 and 60")


## The debug wiring loads the census by path, in one place; the game root
## reaches it only after the guard (test_debug_overlay.gd checks main.gd's
## _debug_wiring()).
func test_the_game_root_loads_the_census_only_after_the_guard() -> void:
	var text := FileAccess.get_file_as_string("res://src/debug/debug_wiring.gd")
	assert_eq(text.count("load(CENSUS_SCRIPT)"), 1, "one place loads it")
	var body := FileAccess.get_file_as_string("res://src/main.gd").get_slice(
			"func use_census(", 1).get_slice("\nfunc ", 0)
	assert_true(body.find("_debug_wiring()") >= 0, "use_census() goes through the guarded wiring")


# --- perf.sh ----------------------------------------------------------------------

## perf.sh checks --census before it looks for a device: a bad value is exit 2.
func test_perf_sh_refuses_a_bad_census_value() -> void:
	var script := ProjectSettings.globalize_path(PERF_SH)
	for value in ["--census=0,60", "--census=10", "--census=a,b"]:
		var output := []
		var code := OS.execute("bash", PackedStringArray([script, value]), output, true)
		assert_eq(code, 2, "%s: bad arguments" % value)
		assert_string_contains("\n".join(output), "--census=EVERY,UNTIL expects", value)

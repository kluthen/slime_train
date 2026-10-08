extends GutTest
## The save format (src/sim/save_data.gd) through Simulation.to_save() and
## Simulation.from_save(): a save goes through JSON text and back, and the
## reloaded simulation has the same state hash, and still has it N ticks
## later. Also: the format's header (format, level ID and version), the
## slimes' fields, the empty object and gate states, exact reals, hand-made
## saves (no bodies, no generator state), the problems that make a save
## unusable, and the keys capture() always writes, which a save must have
## (health review S4).
##
## The synthetic world is test_call.gd's (a floor at y = 0, a loop along it,
## a platform in an exploration branch with its route back) plus a split
## zone at x -900 to -700 and a first slime at x -1400.

# @test-link [[req_persistence_and_saves]]
# @test-link [[req_interactive_objects_general]]

const Support := preload("res://tests/unit/slime_test_support.gd")
const LEVEL_ID := "saves"
const LEVEL_VERSION := 3
const MORE_TICKS := 600


func _level() -> LevelData:
	var data := LevelData.new(LEVEL_ID, LEVEL_VERSION)
	var loop := LoopData.new("t.loop")
	loop.add_segment("t.loop.out", 1, LoopData.OUTGOING, PackedVector2Array([
			Vector2(-1500, -24), Vector2(1500, -24)]))
	loop.add_segment("t.loop.back", 1, LoopData.RETURN, PackedVector2Array([
			Vector2(1500, -24), Vector2(1500, 400), Vector2(-1500, 400), Vector2(-1500, -24)]), "t.gate")
	data.loop = loop
	data.add_branch("t.branch.platform", Rect2(250, -420, 500, 160))
	data.add_route_back("t.route-back.platform", "t.branch.platform", PackedVector2Array([
			Vector2(680, -324), Vector2(300, -324), Vector2(200, -24)]))
	data.add_split_zone("t.split-zone", Rect2(-900, -200, 200, 200))
	data.first_slime = {"id": "start.first-slime", "species": "A", "position": Vector2(-1400, -24)}
	return data


func _terrain() -> TerrainSegments:
	return TerrainSegments.new([
		Support.floor_polygon(),
		PackedVector2Array([Vector2(300, -300), Vector2(700, -300), Vector2(700, -260), Vector2(300, -260)]),
	])


func _sim(master_seed := 21) -> Simulation:
	var sim := Simulation.new(master_seed)
	sim.slimes.terrain = _terrain()
	sim.load_level(_level())
	sim.view.set_to(Vector2(0, -200), 1.0, ScreenView.DEFAULT_SIZE)
	return sim


## A played simulation: a size-2 slime split by the split zone, a slime
## called off the train (free, answering), tilt, taps and ripples.
func _played() -> Simulation:
	var sim := _sim()
	var pair := sim.spawn_train_slime(1, 2, 700.0)
	sim.identities.assign(pair, PackedStringArray(["s1.sleeper.02", "s1.sleeper.05"]))
	var loner := sim.spawn_train_slime(2, 1, 1700.0)
	sim.push_input(Simulation.tilt(18.3))
	sim.run(240)
	var target := sim.slimes.centre_of(loner) + Vector2(-180, -30)
	sim.view.set_to(target, 1.0, ScreenView.DEFAULT_SIZE)
	var at := sim.view.world_to_screen(target)
	sim.push_input(Simulation.touch_down(0, at))
	sim.push_input(Simulation.touch_up(0, at))
	sim.run(20)  # the tap's ripple lasts 36 ticks: still showing
	return sim


## The played story with every slime put on the ground as a load does it
## (MidairLanding: a slime is mid-hop at tick 260), so its save reloads
## exactly (test_midair_load.gd tests a save taken in mid-air).
func _played_on_the_ground() -> Simulation:
	var sim := _played()
	MidairLanding.apply(sim)
	return sim


## `save` through JSON text and back, as the save file does it.
func _through_json(save: Dictionary) -> Dictionary:
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(save)), OK)
	return json.data


func _reloaded(save: Dictionary) -> Simulation:
	var problems := SaveData.problems(save, _level())
	assert_eq(problems, PackedStringArray())
	return Simulation.from_save(save, _level(), _terrain())


# --- Round trip -----------------------------------------------------------------

func test_the_played_story_has_free_split_and_tilted_slimes() -> void:
	var sim := _played()
	var states := []
	for slime_id in sim.slimes.ids():
		states.append(sim.slimes.state_of(slime_id))
	assert_true(SlimeBodies.FREE in states, "a slime answers the call")
	assert_eq(sim.slimes.slime_count, 4, "first slime, two split parts, the called slime")
	assert_eq(sim.phone_tilt.degrees, 18.3)
	assert_false(sim.ripples.is_empty())


func test_a_save_reloads_with_the_same_hash() -> void:
	var sim := _played_on_the_ground()
	var reloaded := _reloaded(_through_json(sim.to_save()))
	assert_not_null(reloaded)
	if reloaded == null:
		return
	assert_eq(StateHash.canonical_json(reloaded.dump()), StateHash.canonical_json(sim.dump()))
	assert_eq(reloaded.state_hash(), sim.state_hash())


func test_a_reloaded_save_stays_equal_after_more_ticks() -> void:
	var sim := _played_on_the_ground()
	var reloaded := _reloaded(_through_json(sim.to_save()))
	assert_not_null(reloaded)
	if reloaded == null:
		return
	sim.run(MORE_TICKS)
	reloaded.run(MORE_TICKS)
	assert_eq(reloaded.tick, sim.tick)
	assert_eq(reloaded.state_hash(), sim.state_hash())


func test_a_save_without_json_reloads_too() -> void:
	var sim := _played_on_the_ground()
	var reloaded := _reloaded(sim.to_save())
	assert_not_null(reloaded)
	if reloaded != null:
		assert_eq(reloaded.state_hash(), sim.state_hash())


func test_a_save_of_a_save_is_the_same_text() -> void:
	var save := _played_on_the_ground().to_save()
	var again := _reloaded(_through_json(save)).to_save()
	assert_eq(SaveData.to_text(again), SaveData.to_text(save))


# --- What a save holds ------------------------------------------------------------

func test_the_header_names_the_format_and_the_level_version() -> void:
	var save := _played().to_save()
	assert_eq(save["format"], SaveData.FORMAT)
	assert_eq(save["level"], {"id": LEVEL_ID, "version": LEVEL_VERSION})
	assert_eq(save["sim"]["tick"], 260)
	assert_eq(save["sim"]["seed"], "21")
	assert_eq(save["sim"]["next_slime_id"], 5)


func test_each_slime_has_its_identity_species_size_state_and_progress() -> void:
	var sim := _played()
	var save := sim.to_save()
	var by_runtime := {}
	for slime in save["slimes"]:
		by_runtime[int(slime["runtime_id"])] = slime
	assert_eq(by_runtime.size(), 4)
	var first: Dictionary = by_runtime[1]
	assert_eq(first["id"], "start.first-slime")
	assert_eq(first["members"], ["start.first-slime"])
	assert_eq(first["species"], "A")
	assert_eq(first["size"], 1)
	assert_eq(first["state"], "train")
	assert_true(first.has("train"), "a train slime has its progress")
	assert_false(first.has("free"))
	assert_eq(by_runtime[2]["id"], "s1.sleeper.02", "the split's original id keeps the first member")
	assert_eq(by_runtime[4]["id"], "s1.sleeper.05")
	assert_eq(by_runtime[4]["species"], "B")
	var called: Dictionary = by_runtime[3]
	assert_eq(called["id"], null, "a slime with no placed origin")
	assert_eq(called["members"], [])
	assert_eq(called["state"], "free")
	assert_true(called["free"]["phase"] in [FreeSlimes.ANSWERING, FreeSlimes.UNSURE], "called")
	assert_false(called.has("train"))
	for slime in save["slimes"]:
		assert_eq(slime["centre"].size(), 2)
		assert_eq(slime["velocity"].size(), 2)
		assert_true(slime.has("body"))


func test_objects_and_gates_are_empty_for_now() -> void:
	var save := _played().to_save()
	assert_eq(save["objects"], {})
	assert_eq(save["gates"], {})


func test_object_and_gate_states_round_trip() -> void:
	var sim := _played_on_the_ground()
	# JSON reads every number back as a float: chunk 14 gives object states
	# their types. Until then, values that JSON keeps as they are.
	sim.object_states["s1.basket"] = {"fill": 0.5, "shape": "round"}
	sim.gate_states["s1.gate"] = {"open": true}
	var reloaded := _reloaded(_through_json(sim.to_save()))
	assert_eq(reloaded.state_hash(), sim.state_hash())


func test_reals_survive_json_exactly() -> void:
	var rng := Rng.new(3)
	for i in 2000:
		var x := rng.randf_range(-5000.0, 5000.0) / 3.0
		var back: Variant = JSON.parse_string(SaveData.to_text({"x": SaveData.exact(x)}))["x"]
		assert_eq(SaveData.real(back), x)
	assert_eq(SaveData.exact(20.0), 20.0, "a real that JSON keeps stays a readable number")
	assert_eq(SaveData.real(12), 12.0)


func test_fingers_down_are_not_saved() -> void:
	var sim := _played()
	sim.push_input(Simulation.touch_down(0, Vector2(100, 100)))
	sim.step()
	var reloaded := _reloaded(_through_json(sim.to_save()))
	assert_eq(reloaded.fingers_down, {}, "a restarted game has no finger on the screen")
	assert_eq(reloaded.active_finger, -1)


# --- Hand-made saves --------------------------------------------------------------

func _hand_made() -> Dictionary:
	return {
		"format": 1,
		"level": {"id": LEVEL_ID, "version": LEVEL_VERSION},
		"slimes": [
			{"id": "start.first-slime", "members": ["start.first-slime"], "species": "A", "size": 1,
					"state": "train", "centre": [-1400, -24]},
			{"id": "s1.sleeper.02", "members": ["s1.sleeper.05", "s1.sleeper.02"], "species": "C",
					"size": 2, "state": "train", "centre": [0, -40], "train": {"distance": 1500}},
			{"species": "B", "size": 1, "state": "free", "centre": [200, -24],
					"free": {"phase": "unsure", "since": 0, "point": [150, -24], "route": ""}},
		],
		"objects": {},
		"gates": {},
	}


func test_a_hand_made_save_loads_with_the_run_seed() -> void:
	var sim := Simulation.from_save(_hand_made(), _level(), _terrain(), 99)
	assert_not_null(sim)
	if sim == null:
		return
	assert_eq(sim.tick, 0)
	assert_eq(sim.rng.seed_value, 99, "no seed in the save: the run's seed")
	assert_eq(Array(sim.slimes.ids()), [1, 2, 3], "runtime ids in list order")
	assert_eq(sim.slimes.slime_count, 3, "slimes in the save: the first slime isn't woken again")
	assert_eq(sim.slimes.species_of(2), Species.from_letter("C"))
	assert_eq(sim.slimes.size_of(2), 2)
	assert_eq(sim.slimes.state_of(3), SlimeBodies.FREE)
	assert_almost_eq(sim.slimes.centre_of(2).x, 0.0, 0.01)
	assert_eq(sim.identities.members_of(2), PackedStringArray(["s1.sleeper.02", "s1.sleeper.05"]))
	assert_almost_eq(sim.train.distance_of(2), 1500.0, 0.001)
	assert_true(sim.train.tracks(1), "a train slime without progress is tracked where the loop is closest")
	assert_eq(sim.free_slimes.phase_of(3), FreeSlimes.UNSURE)
	assert_eq(sim.slimes.next_id, 4)
	sim.run(60)
	assert_eq(sim.tick, 60)


func test_a_hand_made_save_is_repeatable() -> void:
	var a := Simulation.from_save(_hand_made(), _level(), _terrain(), 99)
	var b := Simulation.from_save(_hand_made(), _level(), _terrain(), 99)
	a.run(300)
	b.run(300)
	assert_eq(a.state_hash(), b.state_hash())


# --- Problems ---------------------------------------------------------------------

func test_a_good_save_has_no_problems() -> void:
	assert_eq(SaveData.problems(_hand_made(), _level()), PackedStringArray())


func test_problems_that_make_a_save_unusable() -> void:
	var cases := {
		"another level": func(s: Dictionary) -> void: s["level"]["id"] = "other",
		"a newer level version": func(s: Dictionary) -> void: s["level"]["version"] = LEVEL_VERSION + 1,
		"no level version": func(s: Dictionary) -> void: s["level"].erase("version"),
		"a newer format": func(s: Dictionary) -> void: s["format"] = SaveData.FORMAT + 1,
		"no format": func(s: Dictionary) -> void: s.erase("format"),
		"no slimes": func(s: Dictionary) -> void: s["slimes"] = [],
		"a bad species": func(s: Dictionary) -> void: s["slimes"][0]["species"] = "Z",
		"a bad size": func(s: Dictionary) -> void: s["slimes"][0]["size"] = 4,
		"a bad state": func(s: Dictionary) -> void: s["slimes"][0]["state"] = "flying",
		"a bad centre": func(s: Dictionary) -> void: s["slimes"][0]["centre"] = [1],
		"a bad free phase": func(s: Dictionary) -> void: s["slimes"][2]["free"]["phase"] = "lost",
		"objects not a dictionary": func(s: Dictionary) -> void: s["objects"] = [],
	}
	for label in cases:
		var save := _hand_made().duplicate(true)
		cases[label].call(save)
		assert_ne(SaveData.problems(save, _level()), PackedStringArray(), label)
		assert_null(Simulation.from_save(save, _level(), _terrain(), 1), label + ": not loaded")


## D149: a format other than the build's own is refused, older as well as
## newer (no save format is migrated before the app has shipped). 0 stands
## for an older format: a number only tests use.
# @test-link [[req_persistence_and_saves]]
func test_a_format_other_than_the_builds_own_is_refused() -> void:
	for format in [SaveData.FORMAT + 1, 0]:
		var save := _hand_made().duplicate(true)
		save["format"] = format
		var problems := SaveData.problems(save, _level())
		assert_eq(problems.size(), 1, "format %d" % format)
		var expected := "newer" if format > SaveData.FORMAT else "older"
		assert_string_contains(problems[0] if not problems.is_empty() else "", expected, "format %d" % format)


## Chunk 19 (decision C, proposed): a save of an older level version is
## migrated (SaveMigration, tests/unit/test_save_migration.gd), so it has no
## problems; a newer one is refused above.
# @test-link [[rule_released_level_stable_with_migration]]
func test_a_save_of_an_older_level_version_is_accepted() -> void:
	var save := _hand_made()
	save["level"]["version"] = LEVEL_VERSION - 1
	assert_eq(SaveData.problems(save, _level()), PackedStringArray())
	var sim := Simulation.from_save(save, _level(), _terrain(), 1)
	assert_not_null(sim, "loaded")
	if sim != null:
		assert_eq(sim.to_save()["level"]["version"], LEVEL_VERSION, "at the level's version now")


func test_runtime_ids_must_be_given_for_all_slimes_or_none() -> void:
	var save := _hand_made()
	save["slimes"][0]["runtime_id"] = 1
	assert_ne(SaveData.problems(save, _level()), PackedStringArray())
	save["slimes"][1]["runtime_id"] = 1
	save["slimes"][2]["runtime_id"] = 5
	assert_ne(SaveData.problems(save, _level()), PackedStringArray(), "ascending, no repeats")
	save["slimes"][1]["runtime_id"] = 2
	assert_eq(SaveData.problems(save, _level()), PackedStringArray())


# --- Keys capture() always writes (health review S4) --------------------------------

## The played story's save through JSON, with what it may lack added by hand
## (a rest on a body, an away count, an off-screen proxy, a lost entry, a
## stalled entry, a facing, an open gate, fusion and stuck counts, a stuck
## case, a double hop due), so it has every part capture() writes.
func _full_save() -> Dictionary:
	var save := _through_json(_played_on_the_ground().to_save())
	save["slimes"][0]["body"]["rest"] = {"calm": "resting", "still": 3, "anchor": [0, -24], "pile": 0}
	save["offscreen"]["away"].append({"id": 97, "since": 5})
	save["offscreen"]["proxies"].append({"id": 99, "route": "", "along": 0.5, "from": [0, 0], "to": [10, 0]})
	save["offscreen"]["lost"].append({"id": 98, "tick": 10, "reason": "lost"})
	save["train"]["open_gates"].append("t.gate")
	save["train"]["stalled"].append({"id": 96, "tick": 7, "reason": "out_of_bounds"})
	save["transient"]["facing"].append({"id": 95, "facing": [1, 0]})
	save["transient"]["fusion"].append([1, 2, 3])
	save["transient"]["frontier"]["celebration_hops"].append([1, 2])
	save["stuck_slimes"]["counts"].append([1, 2, 3])
	save["stuck_slimes"]["stuck"].append({"id": 1, "other": 2, "tick": 9, "reason": "stuck", "moved": true})
	return save


## The index of the save's first free slime.
func _free_index(save: Dictionary) -> int:
	for k in save["slimes"].size():
		if save["slimes"][k].has("free"):
			return k
	return -1


## The index of the save's first input log event with `key`.
func _log_index(save: Dictionary, key: String) -> int:
	var log: Array = save["transient"]["input_log"]
	for k in log.size():
		if log[k].has(key):
			return k
	return -1


## Each case is [path, wrong value]: the path's keys from the save's top
## (list indices as ints). The full save with it set to the wrong value has
## a problem naming it (the key, or for a list item the last key before it)
## and doesn't load. Without the key (a dictionary's), it is the same, or,
## with `optional`, the save has no problem.
func _assert_needed(cases: Array, optional := false) -> void:
	var good := _full_save()
	assert_eq(SaveData.problems(good, _level()), PackedStringArray(), "the full save is good")
	for case in cases:
		var path: Array = case[0]
		var key: Variant = path[-1]
		var label := ".".join(path.map(func(part: Variant) -> String: return str(part)))
		var named := "%s'" % key
		if key is int:
			var keys := path.filter(func(part: Variant) -> bool: return part is String)
			named = "%s[" % keys[-1]
		for missing in ([true, false] if key is String else [false]):
			var save := good.duplicate(true)
			var holder: Variant = save
			for part in path.slice(0, -1):
				holder = holder[part]
			if missing:
				holder.erase(key)
			else:
				holder[key] = case[1]
			var what := label + (" missing" if missing else " of the wrong type")
			var problems := SaveData.problems(save, _level())
			if missing and optional:
				assert_eq(problems, PackedStringArray(), what + ": optional")
				continue
			assert_string_contains("\n".join(problems), named, what + ": named")
			assert_null(Simulation.from_save(save, _level(), _terrain(), 1), what + ": not loaded")


func test_objects_and_gates_are_needed() -> void:
	_assert_needed([[["objects"], []], [["gates"], 3]])


func test_the_trains_open_gates_are_needed() -> void:
	_assert_needed([[["train", "open_gates"], {}]])


func test_the_sessions_keys_are_needed() -> void:
	_assert_needed([[["session", "elapsed_ms"], 1.5], [["session", "sunrise_tick"], "x"],
			[["session", "anchor"], []], [["session", "clock"], 0]])


func test_the_offscreen_keys_are_needed() -> void:
	_assert_needed([[["offscreen", "zoomed_out"], 1], [["offscreen", "away"], {}],
			[["offscreen", "proxies"], {}], [["offscreen", "lost"], "x"],
			[["offscreen", "away", -1, "id"], "x"], [["offscreen", "away", -1, "since"], 0.5]])


func test_the_proxies_and_lost_keys_are_needed() -> void:
	_assert_needed([[["offscreen", "proxies", -1, "id"], 1.5], [["offscreen", "proxies", -1, "route"], 7],
			[["offscreen", "proxies", -1, "along"], "x"], [["offscreen", "proxies", -1, "from"], [0]],
			[["offscreen", "proxies", -1, "to"], 0], [["offscreen", "lost", -1, "id"], "x"],
			[["offscreen", "lost", -1, "tick"], [1]], [["offscreen", "lost", -1, "reason"], 3]])


func test_a_free_records_keys_are_needed() -> void:
	var k := _free_index(_full_save())
	assert_gt(k, -1, "the played story has a free slime")
	_assert_needed([[["slimes", k, "free", "since"], "x"], [["slimes", k, "free", "point"], [1, 2, 3]],
			[["slimes", k, "free", "route"], 0]])


func test_a_rests_still_and_pile_are_needed() -> void:
	_assert_needed([[["slimes", 0, "body", "rest", "still"], 1.5], [["slimes", 0, "body", "rest", "pile"], "x"]])


func test_the_transients_keys_are_needed() -> void:
	_assert_needed([[["transient", "view"], []], [["transient", "view", "centre"], 0],
			[["transient", "view", "zoom"], "x"], [["transient", "view", "screen_size"], [1]],
			[["transient", "camera"], []], [["transient", "fusion"], {}],
			[["transient", "tilt"], 0], [["transient", "tilt", "degrees"], "x"],
			[["transient", "tilt", "neutral"], true], [["transient", "tilt", "flat"], 0],
			[["transient", "hint"], []], [["transient", "hint", "since"], "x"],
			[["transient", "hint", "bedtime"], 1], [["transient", "frontier"], 0],
			[["transient", "frontier", "celebration_since"], 0.5], [["transient", "ripples"], {}],
			[["transient", "taps"], 0], [["transient", "facing"], "x"], [["transient", "input_log"], {}]])


func test_the_stuck_logs_keys_are_needed() -> void:
	_assert_needed([[["stuck_slimes", "counts"], {}], [["stuck_slimes", "stuck"], 0]])


func test_the_calls_point_and_tick_are_needed() -> void:
	_assert_needed([[["call", "point"], [1]], [["call", "tick"], "x"]])


func test_the_stalled_logs_entries_are_needed() -> void:
	_assert_needed([[["train", "stalled"], {}]], true)
	_assert_needed([[["train", "stalled", -1], 3], [["train", "stalled", -1, "id"], "x"],
			[["train", "stalled", -1, "tick"], 0.5], [["train", "stalled", -1, "reason"], 3]])


func test_a_bodys_keys_are_needed() -> void:
	_assert_needed([[["slimes", 0, "body", "centre"], 0], [["slimes", 0, "body", "hop_timer"], "x"],
			[["slimes", 0, "body", "heading"], [1, 2]], [["slimes", 0, "body", "held"], 1],
			[["slimes", 0, "body", "supported"], "x"], [["slimes", 0, "body", "rng_state"], 12],
			[["slimes", 0, "body", "rng_state"], "x"]])


func test_a_free_records_stream_is_typed_when_there() -> void:
	var k := _free_index(_full_save())
	_assert_needed([[["slimes", k, "free", "rng_state"], 3]], true)


func test_the_ripples_and_facings_keys_are_needed() -> void:
	_assert_needed([[["transient", "ripples", -1], 3], [["transient", "ripples", -1, "at"], [1]],
			[["transient", "ripples", -1, "tick"], "x"], [["transient", "facing", -1], "x"],
			[["transient", "facing", -1, "id"], 0.5], [["transient", "facing", -1, "facing"], 0]])


func test_a_taps_keys_are_needed() -> void:
	var cases := [[["transient", "taps", -1], 3]]
	var wrong := {"tick": "x", "finger": 0.5, "screen": [1], "world": 0, "zone": 3, "side": "x", "object": 1,
			"kind": 2, "call": 1, "answered": {}}
	for key in wrong:
		cases.append([["transient", "taps", -1, key], wrong[key]])
	_assert_needed(cases)
	var good := _full_save()
	good["transient"]["taps"][-1]["answered"] = [1, "x"]
	assert_ne(SaveData.problems(good, _level()), PackedStringArray(), "an answered id must be a whole number")


func test_the_input_logs_keys_are_needed() -> void:
	var save := _full_save()
	var touch := _log_index(save, "finger")
	var tilt := _log_index(save, "degrees")
	assert_gt(touch, -1, "the played story has a touch in its input log")
	assert_gt(tilt, -1, "the played story has a tilt in its input log")
	_assert_needed([[["transient", "input_log", -1], 3], [["transient", "input_log", touch, "kind"], 3],
			[["transient", "input_log", touch, "tick"], "x"]])
	_assert_needed([[["transient", "input_log", touch, "finger"], "x"],
			[["transient", "input_log", touch, "at"], 0], [["transient", "input_log", tilt, "degrees"], "x"],
			[["transient", "input_log", tilt, "flat"], 0]], true)
	save["transient"]["input_log"][touch]["at"] = null
	assert_eq(SaveData.problems(save, _level()), PackedStringArray(), "a touch may be at no point (null)")


func test_the_cameras_keys_are_needed() -> void:
	var cases := []
	var wrong := {"mode": 1, "zoom": "x", "position": 0, "distance": "x", "rail_left": [1], "rail_gap": 0,
			"rail_length": "x", "hold_finger": 0.5, "hold_side": "x", "drag_point": [1], "drag_tick": "x",
			"return_distance": true, "edge_buttons_visible": 1, "frame_zone": 1, "frame_shift": "x",
			"zone_hold": 0.5, "quiet": "x", "cue_from": "x", "follow_id": 0.5, "follow_species": "x",
			"follow_point": 0, "screensaver": 0, "show_distance": "x", "show_tick": 0.5}
	assert_eq(wrong.size(), Camera.new().dump().size(), "every key dump() writes")
	for key in wrong:
		cases.append([["transient", "camera", key], wrong[key]])
	_assert_needed(cases)


func test_the_count_lists_entries_are_needed() -> void:
	_assert_needed([[["transient", "fusion", -1], [1, 2]], [["transient", "fusion", -1], ["x", 2, 3]],
			[["stuck_slimes", "counts", -1], 3], [["stuck_slimes", "counts", -1], [1, 2, 0.5]],
			[["stuck_slimes", "stuck", -1], "x"], [["stuck_slimes", "stuck", -1, "id"], "x"],
			[["stuck_slimes", "stuck", -1, "other"], 0.5], [["stuck_slimes", "stuck", -1, "tick"], [1]],
			[["stuck_slimes", "stuck", -1, "reason"], 3], [["stuck_slimes", "stuck", -1, "moved"], 1],
			[["transient", "frontier", "celebration_hops", -1], [1]],
			[["transient", "frontier", "celebration_hops", -1], [1, "x"]]])
	_assert_needed([[["transient", "frontier", "celebration_hops"], {}]], true)


func test_the_open_gates_are_names() -> void:
	_assert_needed([[["train", "open_gates", -1], 3]])


## A level's switch, basket and gate states: each key optional (absent: the
## initial state's), of its kind when there; an entry is a dictionary.
func test_object_and_gate_states_are_typed_when_there() -> void:
	var level := _level()
	level.add_switch("t.switch", Rect2(-1150, -100, 50, 50), "t.basket")
	level.add_basket("t.basket", Rect2(-1000, -100, 100, 76), 3, Vector2(-900, -24))
	level.add_gate("t.gate", Rect2(1400, -100, 50, 76))
	var good := _hand_made()
	good["objects"] = {"t.switch": {"flipped": false, "trapdoor_shut": true},
			"t.basket": {"phase": "filling", "weight": 0, "since": -1, "next_release": 0}}
	good["gates"] = {"t.gate": {"open": false, "entrance_closed": false}}
	assert_eq(SaveData.problems(good, level), PackedStringArray(), "the states are good")
	var wrong := {"objects": {"t.switch": {"flipped": 1, "trapdoor_shut": "x"},
			"t.basket": {"phase": "lost", "weight": "x", "since": 0.5, "next_release": [1]}},
			"gates": {"t.gate": {"open": "x", "entrance_closed": 0}}}
	for part in wrong:
		for id in wrong[part]:
			var save := good.duplicate(true)
			save[part][id] = 3
			assert_string_contains("\n".join(SaveData.problems(save, level)), "%s'" % id, id + " not a dictionary")
			for key in wrong[part][id]:
				save = good.duplicate(true)
				save[part][id].erase(key)
				assert_eq(SaveData.problems(save, level), PackedStringArray(), "%s.%s optional" % [id, key])
				save[part][id][key] = wrong[part][id][key]
				assert_string_contains("\n".join(SaveData.problems(save, level)), "%s'" % key,
						"%s.%s of the wrong type" % [id, key])

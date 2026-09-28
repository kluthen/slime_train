extends GutTest
## The save format (src/sim/save_data.gd) through Simulation.to_save() and
## Simulation.from_save(): a save goes through JSON text and back, and the
## reloaded simulation has the same state hash, and still has it N ticks
## later. Also: the format's header (format, level ID and version), the
## slimes' fields, the empty object and gate states, exact reals, hand-made
## saves (no bodies, no generator state), and the problems that make a save
## unusable.
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
	var sim := _played()
	var reloaded := _reloaded(_through_json(sim.to_save()))
	assert_not_null(reloaded)
	if reloaded == null:
		return
	assert_eq(StateHash.canonical_json(reloaded.dump()), StateHash.canonical_json(sim.dump()))
	assert_eq(reloaded.state_hash(), sim.state_hash())


func test_a_reloaded_save_stays_equal_after_more_ticks() -> void:
	var sim := _played()
	var reloaded := _reloaded(_through_json(sim.to_save()))
	assert_not_null(reloaded)
	if reloaded == null:
		return
	sim.run(MORE_TICKS)
	reloaded.run(MORE_TICKS)
	assert_eq(reloaded.tick, sim.tick)
	assert_eq(reloaded.state_hash(), sim.state_hash())


func test_a_save_without_json_reloads_too() -> void:
	var sim := _played()
	var reloaded := _reloaded(sim.to_save())
	assert_not_null(reloaded)
	if reloaded != null:
		assert_eq(reloaded.state_hash(), sim.state_hash())


func test_a_save_of_a_save_is_the_same_text() -> void:
	var save := _played().to_save()
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
	var sim := _played()
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
		"another version": func(s: Dictionary) -> void: s["level"]["version"] = 2,
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


func test_runtime_ids_must_be_given_for_all_slimes_or_none() -> void:
	var save := _hand_made()
	save["slimes"][0]["runtime_id"] = 1
	assert_ne(SaveData.problems(save, _level()), PackedStringArray())
	save["slimes"][1]["runtime_id"] = 1
	save["slimes"][2]["runtime_id"] = 5
	assert_ne(SaveData.problems(save, _level()), PackedStringArray(), "ascending, no repeats")
	save["slimes"][1]["runtime_id"] = 2
	assert_eq(SaveData.problems(save, _level()), PackedStringArray())

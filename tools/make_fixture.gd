extends SceneTree
## Writes the test level's fixtures, levels/test/fixtures/: for each, a
## sidecar <name>.fixture.json (description, whether it has a save, where the
## camera starts) and, when it has one, a save <name>.json in SaveData's
## format, cut down to what a person reads and edits (SaveData.readable).
## Test mode loads them by name ("fixture": "bump"; see TestMode).
##
## Run from the project root, for all of them or the ones named:
##   godot --headless -s res://tools/make_fixture.gd
##   godot --headless -s res://tools/make_fixture.gd -- bump
##
## A fixture is built here, from the level scene, by a function below: add
## one to FIXTURES and write its builder. The level's stable IDs (the
## sleepers') are looked up in the scene, never typed in. Levels change: when
## the test level moves things, run this again. s1-basket-5of6 waits for the
## baskets (chunk 14).
# @spec-link [[req_test_level_and_test_mode]]
# @spec-link [[req_persistence_and_saves]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
const S := LevelData.SCREEN
## The fusion dip's floor: its lowest point is at x 3.0 screens, y 240; a
## slime's centre rests above it.
const DIP_FLOOR := Vector2(3.0 * S, 216.0)
## How far apart bump's two slimes are, px between their outlines.
const BUMP_APART := 40.0

## name -> {"description", "camera" (a level point, or null), "build" (the
## builder's name, or "" for no save: a fresh level)}.
const FIXTURES := {
	"fresh": {"description": ("The test level as new: no save, the first slime woken at its marker "
			+ "and every sleeper asleep at its own; the first-play hint is due."),
			"camera": null, "build": ""},
	"bump": {"description": ("A size-3 and a size-2 train slime of species C, a little apart on the "
			+ "fusion dip's floor, made of five C sleepers (the others asleep at their markers), "
			+ "and the first slime at its marker. For fusion (chunk 10)."),
			"camera": [DIP_FLOOR.x, DIP_FLOOR.y], "build": "_bump"},
}

var _level: Level
var _terrain: TerrainSegments


func _initialize() -> void:
	_level = load(LEVEL_SCENE).instantiate()
	var errors := _level.build()
	if not errors.is_empty():
		_fail("the level doesn't build: %s" % "; ".join(errors))
		return
	_terrain = SlimeWorld.terrain_from(_level)
	var names := PackedStringArray(OS.get_cmdline_user_args())
	if names.is_empty():
		names = PackedStringArray(FIXTURES.keys())
	for name in names:
		if not FIXTURES.has(name):
			_fail("no fixture '%s' (known: %s)" % [name, ", ".join(FIXTURES.keys())])
			return
		var error := _write(name, FIXTURES[name])
		if error != "":
			_fail(error)
			return
		print("make_fixture: wrote %s" % name)
	_level.free()
	quit(0)


func _write(name: String, fixture: Dictionary) -> String:
	var sidecar := {"description": fixture["description"], "save": fixture["build"] != ""}
	if fixture["camera"] != null:
		sidecar["camera"] = fixture["camera"]
	if fixture["build"] != "":
		var sim: Simulation = call(fixture["build"])
		if sim == null:
			return "fixture '%s' could not be built" % name
		var save := SaveData.readable(sim.to_save())
		var check := Simulation.from_save(save, _level.data, _terrain, 1)
		if check == null:
			return "fixture '%s' doesn't load back: %s" % [name, "; ".join(SaveData.problems(save, _level.data))]
		var error := SaveStore.write_file(TestMode.fixture_path(name), save)
		if error != "":
			return error
	var file := FileAccess.open(TestMode.sidecar_path(name), FileAccess.WRITE)
	if file == null:
		return "can't write %s" % TestMode.sidecar_path(name)
	file.store_string(JSON.stringify(sidecar, "\t", false) + "\n")
	file.close()
	return ""


## The level as new: the first slime woken at its marker, the sleepers asleep.
func _fresh_level() -> Simulation:
	var sim := Simulation.new(1)
	sim.slimes.terrain = _terrain
	sim.load_level(_level.data)
	return sim


## bump: a size-3 and a size-2 slime of species C on the dip's floor, made of
## the level's C sleepers (the two in the dip's hollow for the size 2); those
## five sleepers' bodies go.
func _bump() -> Simulation:
	var sim := _fresh_level()
	var sleepers := _sleepers("C")
	if sleepers.size() < 5:
		push_error("make_fixture: the test level has %d C sleepers, bump needs 5" % sleepers.size())
		return null
	# The two nearest the dip are its hollow's; the size 3 takes the first
	# three others.
	var by_gap := sleepers.duplicate()
	by_gap.sort_custom(func(a, b): return absf(a["x"] - DIP_FLOOR.x) < absf(b["x"] - DIP_FLOOR.x))
	var pair: Array = [by_gap[0]["id"], by_gap[1]["id"]]
	var three := []
	for sleeper in sleepers:
		if sleeper["id"] not in pair and three.size() < 3:
			three.append(sleeper["id"])
	var apart := (SlimeBodies.ring_radius_for(3) + SlimeBodies.ring_radius_for(2)
			+ 2.0 * SlimeBodies.EDGE + BUMP_APART)
	for slime_id in sim.slimes.ids():
		var stable_id := sim.identities.stable_id_of(slime_id)
		if stable_id in pair or stable_id in three:
			sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var species := Species.from_letter("C")
	var big := sim.spawn_train_slime(species, 3, _distance_at(sim, DIP_FLOOR.x - apart * 0.5))
	var small := sim.spawn_train_slime(species, 2, _distance_at(sim, DIP_FLOOR.x + apart * 0.5))
	sim.identities.assign(big, PackedStringArray(three))
	sim.identities.assign(small, PackedStringArray(pair))
	return sim


## The loop distance of the dip floor's point at `x`.
func _distance_at(sim: Simulation, x: float) -> float:
	return _level.data.loop.closest(Vector2(x, DIP_FLOOR.y), sim.train.open_gates)["distance"]


## The level's sleepers of species `letter`, left to right: [{"id", "x"}].
func _sleepers(letter: String) -> Array:
	var out := []
	for id in _level.ids():
		var node := _level.find(id)
		if node is Sleeper and node.species == letter:
			out.append({"id": id, "x": _level.position_of(node).x})
	out.sort_custom(func(a, b): return a["x"] < b["x"])
	return out


func _fail(message: String) -> void:
	printerr("make_fixture: ", message)
	if _level != null:
		_level.free()
	quit(1)

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
## the test level moves things, run this again.
##
## The frontier set fixtures (s1-basket-5of6, s1-optout) put the slimes made
## of the ledge sleepers above switch 1 in basket 1 (state "in_basket") and
## flip the switch (its trapdoor open); the camera starts on the basket, so
## its reward isn't kept waiting.
##
## The session fixtures (wind-down, bedtime, sunrise) start a session on test
## mode's default clocks (TestClock) and jump its timer (Session.jump()); a
## run with "sessions": true carries on from there on the same clocks.
# @spec-link [[req_test_level_and_test_mode]]
# @spec-link [[req_persistence_and_saves]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
const S := LevelData.SCREEN
## The fusion dip's floor: its lowest point is at x 3.0 screens, y 240; a
## slime's centre rests above it.
const DIP_FLOOR := Vector2(3.0 * S, 216.0)
## How far apart bump's two slimes are, px between their outlines.
const BUMP_APART := 40.0
## Frontier set 1 (chunk 14): basket 1's pit floor (y) and the camera point
## over it; the ledge sleepers above switch 1 (x from 6.2 to 6.8 screens)
## make the slimes in the basket.
const SWITCH_1 := "s1.switch"
const BASKET_1 := "s1.basket"
const PIT_FLOOR := 100.0
const BASKET_CAMERA := Vector2(6.9 * S, -50.0)
const LEDGES_FROM := 6.2 * S
const LEDGES_TO := 6.8 * S
## Where s1-basket-5of6's train slime starts, just before the switch.
const BEFORE_SWITCH := 6.3 * S

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
	"wind-down": {"description": ("The fresh level 14:50 into a session: the wind-down is on, "
			+ "bedtime comes 10 s in. For sessions (chunk 17; run it with \"sessions\": true)."),
			"camera": null, "build": "_wind_down"},
	"bedtime": {"description": ("The fresh level just as bedtime is reached: the slimes asleep "
			+ "where they were, the edge buttons hidden, the 10-minute cooldown starting. For "
			+ "sessions (chunk 17; run it with \"sessions\": true)."),
			"camera": null, "build": "_bedtime"},
	"sunrise": {"description": ("The fresh level at bedtime, 9:55 into the cooldown: sunrise "
			+ "comes 5 s in. For sessions (chunk 17; run it with \"sessions\": true)."),
			"camera": null, "build": "_sunrise"},
	"s1-basket-5of6": {"description": ("Switch 1 flipped (its trapdoor open) and basket 1 at 5 of "
			+ "6: a size-3 C and a size-2 B resting in it, made of the five ledge sleepers above "
			+ "the switch. The first slime rides the loop just before the switch: it drops in, the "
			+ "basket fills, fires, opens gate 1 and the level's celebration plays. For frontier "
			+ "sets (chunk 14)."),
			"camera": [BASKET_CAMERA.x, BASKET_CAMERA.y], "build": "_basket_5of6"},
	"s1-optout": {"description": ("Switch 1 flipped (its trapdoor open) and basket 1 at 3 of 6: a "
			+ "size-3 C resting in it, made of the three C ledge sleepers above the switch (the B "
			+ "ones asleep). The first slime at its marker. Tap the switch to opt out: the basket "
			+ "lets its slime go. For frontier sets (chunk 14)."),
			"camera": [BASKET_CAMERA.x, BASKET_CAMERA.y], "build": "_optout"},
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


## s1-basket-5of6: basket 1 at 5 of 6 (a size-3 C and a size-2 B in it, from
## the ledge sleepers), switch 1 flipped, the first slime on the loop just
## before the switch.
# @spec-link [[req_switch_basket_gate_set]]
func _basket_5of6() -> Simulation:
	var sim := _fresh_level()
	if not _in_basket(sim, {"C": 3, "B": 2}):
		return null
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == _level.data.first_slime["id"]:
			sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var first := sim.spawn_train_slime(Species.from_letter(_level.data.first_slime["species"]), 1,
			_level.data.loop.closest(Vector2(BEFORE_SWITCH, -124.0), sim.train.open_gates)["distance"])
	sim.identities.assign(first, PackedStringArray([_level.data.first_slime["id"]]))
	return sim


## s1-optout: basket 1 at 3 of 6 (a size-3 C in it, from the C ledge
## sleepers), switch 1 flipped.
# @spec-link [[req_switch_basket_gate_set]]
func _optout() -> Simulation:
	var sim := _fresh_level()
	if not _in_basket(sim, {"C": 3}):
		return null
	return sim


## Makes, for each species letter -> size of `sizes`, one slime of that size
## resting on basket 1's pit floor out of the ledge sleepers of that species
## (their bodies go), then flips switch 1 with its trapdoor open and gives
## the basket its weight. False when the ledges are short of sleepers.
func _in_basket(sim: Simulation, sizes: Dictionary) -> bool:
	var basket: Dictionary = _level.data.baskets.get(BASKET_1, {})
	if basket.is_empty() or not _level.data.switches.has(SWITCH_1):
		push_error("make_fixture: the test level has no %s or %s" % [SWITCH_1, BASKET_1])
		return false
	var box: Rect2 = basket["box"]
	var letters := sizes.keys()
	var weight := 0
	for k in letters.size():
		var letter: String = letters[k]
		var members := []
		for sleeper in _sleepers(letter):
			if sleeper["x"] >= LEDGES_FROM and sleeper["x"] <= LEDGES_TO and members.size() < sizes[letter]:
				members.append(sleeper["id"])
		if members.size() < sizes[letter]:
			push_error("make_fixture: the ledges above %s have %d %s sleepers, %d needed"
					% [SWITCH_1, members.size(), letter, sizes[letter]])
			return false
		for slime_id in sim.slimes.ids():
			if sim.identities.stable_id_of(slime_id) in members:
				sim.slimes.remove(slime_id)
		var size: int = sizes[letter]
		var x := box.get_center().x + (k - (letters.size() - 1) * 0.5) * 3.0 * SlimeBodies.ring_radius_for(3)
		var at := Vector2(x, PIT_FLOOR - SlimeBodies.ring_radius_for(size) - SlimeBodies.EDGE)
		var slime := sim.slimes.create(Species.from_letter(letter), size, at, SlimeBodies.IN_BASKET)
		sim.identities.assign(slime, PackedStringArray(members))
		weight += size
	sim.identities.tidy(sim.slimes)
	sim.frontier.tap_switch(sim, SWITCH_1)
	sim.object_states[SWITCH_1]["trapdoor_shut"] = false
	sim.object_states[BASKET_1]["weight"] = weight
	return true


## wind-down: a session started on the fresh level, 14:50 in.
# @spec-link [[req_session_lifecycle]]
func _wind_down() -> Simulation:
	return _in_session(Session.BEDTIME_MS - 10_000)


## bedtime: a session started on the fresh level, bedtime just reached.
func _bedtime() -> Simulation:
	return _in_session(Session.BEDTIME_MS)


## sunrise: a session started on the fresh level, 9:55 into the cooldown.
func _sunrise() -> Simulation:
	return _in_session(Session.SUNRISE_MS - 5_000)


## The fresh level with a session started on test mode's default clocks and
## its timer jumped to `elapsed_ms` (the phases reached take effect).
func _in_session(elapsed_ms: int) -> Simulation:
	var sim := _fresh_level()
	sim.session.read_clock(TestClock.default_reading())
	sim.session.start(sim)
	sim.session.jump(sim, elapsed_ms)
	sim.session.save_due = false
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

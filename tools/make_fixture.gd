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
## The off-screen fixtures (chunk 15): s2-basket-offscreen does the same
## with switch 2 and basket 2, gate 1 open, the camera on switch 2 (the
## basket out of view); s2-cave-return and lost turn sleepers into free
## slimes where they sleep, off screen.
##
## The session fixtures (wind-down, bedtime, sunrise) start a session on test
## mode's default clocks (TestClock) and jump its timer (Session.jump()); a
## run with "sessions": true carries on from there on the same clocks.
##
## Chunk 16: bump is four C slimes (sizes 2, 2, 3, 1) so both bumps can
## happen; gate1-open and gate2-open open the gates as after their baskets
## fired and spread 20 awake train slimes along the grown loop; the stress
## fixtures fill section 3's bowl with the whole population (200 base
## slimes, no sleeper left), found by scanning the terrain for room
## (_bowl_spots).
# @spec-link [[req_test_level_and_test_mode]]
# @spec-link [[req_persistence_and_saves]]

const LEVEL_SCENE := "res://levels/test/level.tscn"
const S := LevelData.SCREEN
## The fusion dip's floor: its lowest point is at x 3.0 screens, y 240; a
## slime's centre rests above it.
const DIP_FLOOR := Vector2(3.0 * S, 216.0)
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
## Frontier set 2 (chunk 15): basket 2's pit floor (y), the camera on switch
## 2 (basket 2 is 1.5 screens further, out of view), the sleepers around the
## switch and in the cave (x from 10.7 to 12.3 screens) that make the slimes
## in basket 2, and where the train slimes heading into it start.
const GATE_1 := "s1.gate"
const SWITCH_2 := "s2.switch"
const BASKET_2 := "s2.basket"
const PIT_2_FLOOR := 150.0
const SWITCH_2_CAMERA := Vector2(10.97 * S, -150.0)
const SET_2_FROM := 10.7 * S
const SET_2_TO := 12.3 * S
const BEFORE_SWITCH_2 := 10.75 * S
## The cave (chunk 15): s2-cave-return's free slimes are made of the pocket's
## first sleepers (x from 10.95 to 11.65 screens) and start down the route
## back, on the tunnel's first shelf just below the pocket's end (its top
## runs from (11.02, -500) down to (11.9, -550)); the camera is away, on the
## start basin.
const POCKET_FROM := 10.95 * S
const POCKET_TO := 11.65 * S
const SHELF_XS := [11.75, 11.8, 11.85]
const AWAY_CAMERA := Vector2(0.4 * S, 400.0)
## lost's free slime is made of the D sleeper nearest this: on the parade's
## ledges in section 2, beyond gate 1 (closed), in no exploration branch and
## far from the loop in use.
const STRANDED := Vector2(9.3 * S, -264.0)
## bump (chunk 16): the four slimes' sizes, left to right, and where on the
## dip's floor they start (x, screens), about a slime apart.
const BUMP_SIZES := [2, 2, 3, 1]
const BUMP_XS := [2.95, 3.0, 3.05, 3.1]
## The gate fixtures (chunk 16): how many slimes are awake (the first slime
## and section 1's first sleepers, in stable ID order), spread along the
## outgoing loop from just past the split zone to GATE_END_ROOM px before
## its end.
const GATE_2 := "s2.gate"
const GATE_AWAKE := 20
const GATE_START_ROOM := 60.0
const GATE_END_ROOM := 400.0
## The stress fixtures (chunk 16): section 3's bowl, scanned for room in
## columns SPOT_PITCH px apart from BOWL_FROM to BOWL_TO and from BOWL_TOP
## down; basket 3 takes 60 base slimes, the bowl the rest. The camera starts
## on the bowl's framing zone (the whole bowl at half zoom; basket 3 out of
## view).
const SWITCH_3 := "s3.switch"
const BASKET_3 := "s3.basket"
const BOWL_FROM := 13.05 * S
const BOWL_TO := 15.55 * S
const BOWL_TOP := -560.0
const BOWL_BOTTOM := 200.0
const SPOT_PITCH := 50.0
const IN_BASKET_3 := 60
const BOWL_CAMERA := Vector2(14.375 * S, -150.0)
## stress-still's settling time, ticks: the pile lands and rests.
const SETTLE_TICKS := 600

## name -> {"description", "camera" (a level point, or null), "build" (the
## builder's name, or "" for no save: a fresh level)}.
const FIXTURES := {
	"fresh": {"description": ("The test level as new: no save, the first slime woken at its marker "
			+ "and every sleeper asleep at its own; the first-play hint is due."),
			"camera": null, "build": ""},
	"bump": {"description": ("Four train slimes of species C on the fusion dip's floor, sizes 2, "
			+ "2, 3 and 1 from left to right, about a slime apart, made of the eight C sleepers "
			+ "nearest the dip (the others asleep at their markers), and the first slime at its "
			+ "marker. Both bumps can happen: 2 + 2 and 3 + 1. For fusion (chunk 10; four slimes "
			+ "since chunk 16)."),
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
			+ "basket fills, fires and opens gate 1 (the loop grows into section 2). For frontier "
			+ "sets (chunk 14)."),
			"camera": [BASKET_CAMERA.x, BASKET_CAMERA.y], "build": "_basket_5of6"},
	"s1-optout": {"description": ("Switch 1 flipped (its trapdoor open) and basket 1 at 3 of 6: a "
			+ "size-3 C resting in it, made of the three C ledge sleepers above the switch (the B "
			+ "ones asleep). The first slime at its marker. Tap the switch to opt out: the basket "
			+ "lets its slime go. For frontier sets (chunk 14)."),
			"camera": [BASKET_CAMERA.x, BASKET_CAMERA.y], "build": "_optout"},
	"s2-basket-offscreen": {"description": ("Gate 1 open (basket 1 fired, slide 1 shut), switch 2 "
			+ "flipped (its trapdoor open) and basket 2 at 14 of 15: a size-3 A, B, C and D and a "
			+ "size-2 D resting in it, made of sleepers around switch 2 and in the cave. The first "
			+ "slime rides the loop just before switch 2, heading into the basket; the camera is on "
			+ "switch 2, 1.5 screens from the basket. Off screen the slime drops in, the basket "
			+ "fills and waits; brought into view it plays its reward, fires and opens gate 2 (the "
			+ "loop grows into section 3; the celebration waits for basket 3). For off-screen "
			+ "simulation (chunk 15)."),
			"camera": [SWITCH_2_CAMERA.x, SWITCH_2_CAMERA.y], "build": "_basket_offscreen"},
	"s2-cave-return": {"description": ("Gate 1 open (basket 1 fired, slide 1 shut) and 3 free "
			+ "size-1 slimes (A, B, C) starting down the cave's route back, on the tunnel's first "
			+ "shelf below the pocket, made of the pocket's sleepers; the camera is away, on the "
			+ "start basin. Off screen they "
			+ "follow the route back at the deterministic pace, are left alone after 10 s and "
			+ "rejoin the train well before they are lost. For off-screen simulation (chunk 15)."),
			"camera": [AWAY_CAMERA.x, AWAY_CAMERA.y], "build": "_cave_return"},
	"lost": {"description": ("The fresh level with one free size-1 slime (D) on the parade's first "
			+ "ledge, beyond gate 1 (closed): off screen, in no exploration branch, with no route "
			+ "back and no loop near. It is left alone at 10 s, then lost at 1 min 10 s and moved "
			+ "to the start of the loop. For off-screen simulation (chunk 15)."),
			"camera": null, "build": "_lost"},
	"gate1-open": {"description": ("Gate 1 open as after basket 1 fired (switch 1 inert, slide 1 "
			+ "shut): the loop runs into section 2. 20 slimes awake, size 1: the first slime and "
			+ "section 1's first 19 sleepers (in stable ID order), train slimes spread along the "
			+ "outgoing loop from just past the split zone; the camera at section 2's start. For "
			+ "starting from section 2 (chunk 16)."),
			"camera": [8.3 * S, -124.0], "build": "_gate1_open"},
	"gate2-open": {"description": ("Gates 1 and 2 open as after baskets 1 and 2 fired (slides 1 "
			+ "and 2 shut): the loop runs through section 3 to slide 3. The same 20 slimes as "
			+ "gate1-open, spread along the whole outgoing loop; the camera at section 3's start. "
			+ "For the whole loop, and starting from section 3 (chunk 16)."),
			"camera": [13.0 * S, -44.0], "build": "_gate2_open"},
	"stress-still": {"description": ("Gates 1 and 2 open and all 200 base slimes woken (no sleeper "
			+ "left): 60 size-1 slimes resting in basket 3 (switch 3 flipped, the basket full and "
			+ "waiting to be in view), and the other 140 piled at the bottom of section 3's bowl, "
			+ "asleep for the night: a session at bedtime, since a slime outside a basket rests "
			+ "only asleep. Settled for 10 s before saving. The camera on the bowl (its framing "
			+ "zone zooms out to half). The worst still case on one screen (chunk 16; measured by "
			+ "tools/bench_level.gd)."),
			"camera": [BOWL_CAMERA.x, BOWL_CAMERA.y], "build": "_stress_still"},
	"stress-moving": {"description": ("Gates 1 and 2 open and all 200 base slimes woken as size-1 "
			+ "train slimes, spread through section 3's bowl from its bottom up (on the floor, the "
			+ "slopes and the shelves), each following the loop from its nearest point. The camera "
			+ "on the bowl. The worst moving case: a measurement, not a target (chunk 16; "
			+ "tools/bench_level.gd)."),
			"camera": [BOWL_CAMERA.x, BOWL_CAMERA.y], "build": "_stress_moving"},
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


## bump: four slimes of species C on the dip's floor, sizes BUMP_SIZES at
## BUMP_XS, made of the level's C sleepers nearest the dip (as many as their
## sizes add up to, the nearest first); those sleepers' bodies go. A 3 + 2
## pair could make neither bump (chunk 16).
func _bump() -> Simulation:
	var sim := _fresh_level()
	var needed := 0
	for size in BUMP_SIZES:
		needed += size
	var sleepers := _sleepers("C")
	if sleepers.size() < needed:
		push_error("make_fixture: the test level has %d C sleepers, bump needs %d" % [sleepers.size(), needed])
		return null
	var by_gap := sleepers.duplicate()
	by_gap.sort_custom(func(a, b): return absf(a["x"] - DIP_FLOOR.x) < absf(b["x"] - DIP_FLOOR.x))
	var used := []
	for k in needed:
		used.append(by_gap[k]["id"])
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) in used:
			sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var species := Species.from_letter("C")
	var next := 0
	for k in BUMP_SIZES.size():
		var size: int = BUMP_SIZES[k]
		var slime := sim.spawn_train_slime(species, size, _distance_at(sim, float(BUMP_XS[k]) * S))
		sim.identities.assign(slime, PackedStringArray(used.slice(next, next + size)))
		next += size
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
	var pieces := []
	for letter in sizes:
		pieces.append([letter, sizes[letter]])
	return _fill_basket(sim, SWITCH_1, pieces, Vector2(LEDGES_FROM, LEDGES_TO), PIT_FLOOR,
			3.0 * SlimeBodies.ring_radius_for(3))


## Makes, for each [species letter, size] of `pieces`, one slime of that size
## resting on the floor (y `floor_y`) of switch `switch_id`'s basket, `pitch`
## px apart, out of the sleepers of that species whose x is within `span`
## (their bodies go; the leftmost first), then flips the switch with its
## trapdoor open and gives the basket its weight. False when the span is
## short of sleepers.
func _fill_basket(sim: Simulation, switch_id: String, pieces: Array, span: Vector2, floor_y: float,
		pitch: float) -> bool:
	var basket_id := str(_level.data.switches.get(switch_id, {}).get("basket", ""))
	var basket: Dictionary = _level.data.baskets.get(basket_id, {})
	if basket.is_empty():
		push_error("make_fixture: the test level has no %s or its basket" % switch_id)
		return false
	var box: Rect2 = basket["box"]
	var used := []
	var weight := 0
	for k in pieces.size():
		var letter: String = pieces[k][0]
		var size: int = pieces[k][1]
		var members := []
		for sleeper in _sleepers(letter):
			if sleeper["x"] >= span.x and sleeper["x"] <= span.y and members.size() < size \
					and sleeper["id"] not in used:
				members.append(sleeper["id"])
		if members.size() < size:
			push_error("make_fixture: around %s are %d spare %s sleepers, %d needed"
					% [switch_id, members.size(), letter, size])
			return false
		used.append_array(members)
		for slime_id in sim.slimes.ids():
			if sim.identities.stable_id_of(slime_id) in members:
				sim.slimes.remove(slime_id)
		var x := box.get_center().x + (k - (pieces.size() - 1) * 0.5) * pitch
		var at := Vector2(x, floor_y - SlimeBodies.ring_radius_for(size) - SlimeBodies.EDGE)
		var slime := sim.slimes.create(Species.from_letter(letter), size, at, SlimeBodies.IN_BASKET)
		sim.identities.assign(slime, PackedStringArray(members))
		weight += size
	sim.identities.tidy(sim.slimes)
	sim.frontier.tap_switch(sim, switch_id)
	sim.object_states[switch_id]["trapdoor_shut"] = false
	sim.object_states[basket_id]["weight"] = weight
	return true


## s2-basket-offscreen: gate 1 open, basket 2 at 14 of 15 (a size-3 A, B, C
## and D and a size-2 D in it), switch 2 flipped, the first slime on the
## loop just before switch 2.
# @spec-link [[req_offscreen_simulation]]
# @spec-link [[req_switch_basket_gate_set]]
func _basket_offscreen() -> Simulation:
	var sim := _fresh_level()
	_open_gate_1(sim)
	var pieces := [["A", 3], ["B", 3], ["C", 3], ["D", 3], ["D", 2]]
	# Side by side: a size-3 slime's width apart, with a little room.
	var pitch := 2.0 * (SlimeBodies.ring_radius_for(3) + SlimeBodies.EDGE) + 2.0
	if not _fill_basket(sim, SWITCH_2, pieces, Vector2(SET_2_FROM, SET_2_TO), PIT_2_FLOOR, pitch):
		return null
	_move_first_slime(sim, Vector2(BEFORE_SWITCH_2, -44.0))
	return sim


## s2-cave-return: gate 1 open, 3 free size-1 slimes (A, B, C), made of the
## pocket's first sleepers of those species, on the tunnel's first shelf.
# @spec-link [[req_offscreen_simulation]]
# @spec-link [[rule_left_alone_and_lost]]
func _cave_return() -> Simulation:
	var sim := _fresh_level()
	_open_gate_1(sim)
	var letters := ["A", "B", "C"]
	for k in letters.size():
		var letter: String = letters[k]
		var sleeper := {}
		for candidate in _sleepers(letter):
			if candidate["x"] >= POCKET_FROM and candidate["x"] <= POCKET_TO:
				sleeper = candidate
				break
		if sleeper.is_empty():
			push_error("make_fixture: the cave's pocket has no %s sleeper" % letter)
			return null
		var slime := _free_sleeper(sim, sleeper["id"])
		var x: float = SHELF_XS[k]
		var top := -500.0 - 50.0 * (x - 11.02) / 0.88
		var at := Vector2(x * S, top - SlimeBodies.ring_radius_for(1) - SlimeBodies.EDGE - 1.0)
		sim.slimes.translate(slime, at - sim.slimes.centre_of(slime))
	return sim


## lost: the fresh level with one free size-1 D slime where the D sleeper
## nearest STRANDED sleeps.
# @spec-link [[rule_left_alone_and_lost]]
func _lost() -> Simulation:
	var sim := _fresh_level()
	var nearest := {}
	for sleeper in _sleepers("D"):
		if nearest.is_empty() or absf(sleeper["x"] - STRANDED.x) < absf(nearest["x"] - STRANDED.x):
			nearest = sleeper
	if nearest.is_empty():
		push_error("make_fixture: the test level has no D sleeper")
		return null
	if _free_sleeper(sim, nearest["id"]) < 0:
		return null
	return sim


## gate1-open: gate 1 open, GATE_AWAKE size-1 slimes awake along the loop.
# @spec-link [[req_switch_basket_gate_set]]
func _gate1_open() -> Simulation:
	var sim := _fresh_level()
	_open_gate_1(sim)
	return sim if _wake_along_loop(sim) else null


## gate2-open: gates 1 and 2 open, the same slimes awake along the loop.
# @spec-link [[req_switch_basket_gate_set]]
func _gate2_open() -> Simulation:
	var sim := _fresh_level()
	_open_gate_2(sim)
	return sim if _wake_along_loop(sim) else null


## Replaces the first slime and section 1's first GATE_AWAKE - 1 sleepers (in
## stable ID order) with size-1 train slimes of their species, evenly spread
## along the outgoing loop in use (the first slime hindmost). False when
## section 1 is short of sleepers.
func _wake_along_loop(sim: Simulation) -> bool:
	var ids := [str(_level.data.first_slime["id"])]
	for id in _sleeper_ids("s1."):
		if ids.size() < GATE_AWAKE:
			ids.append(id)
	if ids.size() < GATE_AWAKE:
		push_error("make_fixture: section 1 has %d sleepers, %d needed" % [ids.size() - 1, GATE_AWAKE - 1])
		return false
	var species_of := {}
	for slime_id in sim.slimes.ids():
		var stable_id := sim.identities.stable_id_of(slime_id)
		if stable_id in ids:
			species_of[stable_id] = sim.slimes.species_of(slime_id)
			sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var from := _past_split_zone(sim) + GATE_START_ROOM
	var to := sim.train.outgoing_length() - GATE_END_ROOM
	for k in ids.size():
		var distance := from + (to - from) * float(k) / float(ids.size() - 1)
		var slime := sim.spawn_train_slime(species_of[ids[k]], 1, distance)
		sim.identities.assign(slime, PackedStringArray([ids[k]]))
	return true


## stress-still: gates 1 and 2 open, the whole population woken: the last
## IN_BASKET_3 (in stable ID order, section 3's) resting in basket 3, full;
## the others piled at the bowl's bottom (the lowest _bowl_spots), asleep at
## bedtime; then SETTLE_TICKS so the pile lands and rests.
# @spec-link [[rule_max_200_slimes_per_level]]
# @spec-link [[req_switch_basket_gate_set]]
func _stress_still() -> Simulation:
	var sim := _fresh_level()
	_open_gate_2(sim)
	var population := _whole_population(sim)
	var box: Rect2 = _level.data.baskets[BASKET_3]["box"]
	var reach := SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE
	var per_row := int((box.size.x - 2.0 * reach - 4.0) / SPOT_PITCH) + 1
	var pile := population.slice(population.size() - IN_BASKET_3)
	var row := 0
	var column := 0
	for member in pile:
		var shift := SPOT_PITCH * 0.5 if row % 2 == 1 else 0.0
		if column >= per_row - row % 2:
			row += 1
			column = 0
			shift = SPOT_PITCH * 0.5 if row % 2 == 1 else 0.0
		var at := Vector2(box.position.x + reach + 2.0 + shift + column * SPOT_PITCH,
				box.end.y - reach - 2.0 - row * (SPOT_PITCH - 6.0))
		var slime := sim.slimes.create(member[1], 1, at, SlimeBodies.IN_BASKET)
		sim.identities.assign(slime, PackedStringArray([member[0]]))
		column += 1
	sim.frontier.tap_switch(sim, SWITCH_3)
	sim.object_states[SWITCH_3]["trapdoor_shut"] = false
	sim.object_states[BASKET_3]["weight"] = pile.size()
	var rest := population.slice(0, population.size() - IN_BASKET_3)
	if not _into_bowl(sim, rest, SlimeBodies.FREE):
		return null
	sim.session.read_clock(TestClock.default_reading())
	sim.session.start(sim)
	sim.session.jump(sim, Session.BEDTIME_MS)
	sim.session.save_due = false
	for tick in SETTLE_TICKS:
		sim.step()
	return sim


## stress-moving: gates 1 and 2 open, the whole population woken as size-1
## train slimes through the bowl, from its bottom up.
# @spec-link [[rule_max_200_slimes_per_level]]
func _stress_moving() -> Simulation:
	var sim := _fresh_level()
	_open_gate_2(sim)
	if not _into_bowl(sim, _whole_population(sim), SlimeBodies.TRAIN):
		return null
	return sim


## Every slime's body goes (the first slime's and the sleepers'); returns
## [stable ID, species] for each, the first slime first, then the sleepers in
## stable ID order.
func _whole_population(sim: Simulation) -> Array:
	var first := str(_level.data.first_slime["id"])
	var species_of := {}
	for slime_id in sim.slimes.ids():
		species_of[sim.identities.stable_id_of(slime_id)] = sim.slimes.species_of(slime_id)
		sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var ids := species_of.keys()
	ids.erase(first)
	ids.sort()
	ids.push_front(first)
	var out := []
	for id in ids:
		out.append([id, species_of[id]])
	return out


## Makes a size-1 slime in `state` (FREE or TRAIN; a train slime follows the
## loop from its nearest point) for each [stable ID, species] of `members`,
## at the bowl's lowest spots. False when the bowl is short of room.
func _into_bowl(sim: Simulation, members: Array, state: int) -> bool:
	var spots := _bowl_spots()
	if spots.size() < members.size():
		push_error("make_fixture: the bowl has room for %d slimes, %d needed" % [spots.size(), members.size()])
		return false
	for k in members.size():
		var at: Vector2 = spots[k]
		var slime := sim.slimes.create(members[k][1], 1, at, state)
		if state == SlimeBodies.TRAIN:
			sim.train.track(slime, _level.data.loop.closest(at, sim.train.open_gates)["distance"])
		sim.identities.assign(slime, PackedStringArray([members[k][0]]))
	return true


## Room for a size-1 slime in section 3's bowl, lowest first: in columns
## SPOT_PITCH px apart from BOWL_FROM to BOWL_TO, scanned from BOWL_TOP down,
## each space between terrain pieces holds slimes stacked SPOT_PITCH px apart
## from its floor (a ledge's top, or the ground) up to its ceiling (the ledge
## above's underside). A piece the scan gets through within 40 px is a ledge;
## otherwise it is the ground, and the column ends.
func _bowl_spots() -> Array:
	var reach := SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE
	var spots := []
	var x := BOWL_FROM
	while x <= BOWL_TO:
		var ceiling := BOWL_TOP
		var y := BOWL_TOP
		while y < BOWL_BOTTOM:
			if not _terrain.resolve(Vector2(x, y))["hit"]:
				y += 2.0
				continue
			var centre := y - reach - 2.0
			while centre - reach >= ceiling + 2.0:
				if _terrain.resolve(Vector2(x, centre))["distance"] >= reach + 1.0:
					spots.append(Vector2(x, centre))
				centre -= SPOT_PITCH
			var below := y
			var through := false
			while below < y + 40.0 and not through:
				below += 2.0
				var hit := _terrain.resolve(Vector2(x, below))
				through = not hit["hit"] and hit["distance"] < 8.0
			if not through:
				break
			ceiling = below
			y = below + 2.0
		x += SPOT_PITCH
	spots.sort_custom(func(a: Vector2, b: Vector2): return a.y > b.y or (a.y == b.y and a.x < b.x))
	return spots


## Gate 1 open as after basket 1 fired: the basket fired and empty, switch 1
## flipped with its trapdoor shut, the gate open with slide 1's entrance
## shut, the loop grown into section 2.
func _open_gate_1(sim: Simulation) -> void:
	sim.object_states[SWITCH_1]["flipped"] = true
	sim.object_states[SWITCH_1]["trapdoor_shut"] = true
	sim.object_states[BASKET_1]["phase"] = FrontierSets.FIRED
	sim.object_states[BASKET_1]["since"] = 0
	sim.gate_states[GATE_1]["open"] = true
	sim.gate_states[GATE_1]["entrance_closed"] = true
	sim.train.set_open_gates([GATE_1])


## Gates 1 and 2 open as after baskets 1 and 2 fired: set 1 as in
## _open_gate_1, set 2 the same way, the loop grown into section 3.
func _open_gate_2(sim: Simulation) -> void:
	_open_gate_1(sim)
	sim.object_states[SWITCH_2]["flipped"] = true
	sim.object_states[SWITCH_2]["trapdoor_shut"] = true
	sim.object_states[BASKET_2]["phase"] = FrontierSets.FIRED
	sim.object_states[BASKET_2]["since"] = 0
	sim.gate_states[GATE_2]["open"] = true
	sim.gate_states[GATE_2]["entrance_closed"] = true
	sim.train.set_open_gates([GATE_1, GATE_2])


## The distance along the loop in use where it leaves the start's split zone.
func _past_split_zone(sim: Simulation) -> float:
	var distance := 0.0
	while distance < sim.train.length():
		var inside := false
		for zone in _level.data.split_zones.values():
			if (zone as Rect2).has_point(sim.train.position_at(distance)):
				inside = true
		if not inside:
			return distance
		distance += 4.0
	return 0.0


## Replaces sleeper `stable_id`'s body with a free size-1 slime of its
## species where it sleeps, and returns the new slime's id.
func _free_sleeper(sim: Simulation, stable_id: String) -> int:
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) != stable_id:
			continue
		var species := sim.slimes.species_of(slime_id)
		var at := sim.slimes.centre_of(slime_id)
		sim.slimes.remove(slime_id)
		var slime := sim.slimes.create(species, 1, at, SlimeBodies.FREE)
		sim.identities.assign(slime, PackedStringArray([stable_id]))
		sim.identities.tidy(sim.slimes)
		return slime
	return -1


## Moves the first slime onto the loop in use where it passes closest to
## `near`.
func _move_first_slime(sim: Simulation, near: Vector2) -> void:
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == _level.data.first_slime["id"]:
			sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var first := sim.spawn_train_slime(Species.from_letter(_level.data.first_slime["species"]), 1,
			_level.data.loop.closest(near, sim.train.open_gates)["distance"])
	sim.identities.assign(first, PackedStringArray([_level.data.first_slime["id"]]))


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


## The stable IDs of the level's sleepers starting with `prefix`, sorted.
func _sleeper_ids(prefix: String) -> Array:
	var out := []
	for id in _level.ids():
		if id.begins_with(prefix) and _level.find(id) is Sleeper:
			out.append(id)
	out.sort()
	return out


func _fail(message: String) -> void:
	printerr("make_fixture: ", message)
	if _level != null:
		_level.free()
	quit(1)

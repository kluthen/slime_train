extends GutTest
## Save migration by level version (src/sim/save_migration.gd, called by
## SaveData.restore; chunk 19, decision C, proposed): a save of an older
## version of the level loads into the level as it is now, keyed by stable
## IDs. A sleeper whose stable ID is gone, or whose spot moved, and an awake
## slime whose centre is no longer in open space (inside the terrain, or
## outside the level) are displaced: they stay in the save and are lost the
## usual way on load (to the loop start, in the lost log), so no slime is
## ever dropped and the population stays whole. A sleeper the level gained
## is added, asleep at its spot. Object and gate states of stable IDs gone
## are dropped; new objects and gates take their initial state on load. The
## header takes the level's version. A save of a newer version is refused.
##
## The world: the test level (200 slimes: the first slime and 199 sleepers),
## played a little, and a copy of its LevelData one version newer, changed as
## each test needs.

# @test-link [[rule_released_level_stable_with_migration]]
# @test-link [[rule_saves_never_wiped]]

const SEED := 11
const POPULATION := 200
## Ticks played before saving: the first slime has settled on the loop.
const PLAYED := 120

var _level: Level = null
var _terrain: TerrainSegments = null
var _save: Dictionary = {}


func before_all() -> void:
	_level = load(LevelCatalog.scene_path(LevelCatalog.DEFAULT_ID)).instantiate()
	add_child(_level)
	_terrain = SlimeWorld.terrain_from(_level)
	var sim := Simulation.new(SEED)
	sim.slimes.terrain = _terrain
	sim.load_level(_level.data)
	sim.run(PLAYED)
	# As a load does it, so the reload of an unchanged slime is where it was.
	MidairLanding.apply(sim)
	_save = _through_json(sim.to_save())


func after_all() -> void:
	_level.free()


## `save` through JSON text and back, as the save file does it.
func _through_json(save: Dictionary) -> Dictionary:
	var json := JSON.new()
	assert_eq(json.parse(SaveData.to_text(save)), OK)
	return json.data


## A copy of the test level's data, one version newer (its dictionaries
## copied, so a test may change them).
func _newer() -> LevelData:
	var data: LevelData = _level.data
	var out := LevelData.new(data.level_id, data.level_version + 1)
	for property in data.get_property_list():
		if not property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var field: String = property["name"]
		if field in ["level_id", "level_version"]:
			continue
		var value: Variant = data.get(field)
		out.set(field, value.duplicate(true) if value is Dictionary or value is Array else value)
	return out


## A fresh copy of the base save.
func _old_save() -> Dictionary:
	return _save.duplicate(true)


## The save entry of the slime holding stable ID `id`, or {}.
static func _entry(save: Dictionary, id: String) -> Dictionary:
	for slime in save["slimes"]:
		if id in slime.get("members", []):
			return slime
	return {}


## The runtime id of the slime holding stable ID `id` in `sim`, or -1.
static func _holder(sim: Simulation, id: String) -> int:
	for slime_id in sim.slimes.ids():
		if id in sim.identities.members_of(slime_id):
			return slime_id
	return -1


## The ids of `sim`'s lost log.
static func _lost_ids(sim: Simulation) -> Array:
	var out := []
	for entry in sim.offscreen.lost:
		if entry["reason"] == Offscreen.LOST:
			out.append(entry["id"])
	return out


## The first two sleepers of the level, by stable ID.
func _two_sleepers() -> Array:
	var ids: Array = _level.data.sleepers.keys()
	ids.sort()
	return [ids[0], ids[1]]


## The weight of every slime of `sim` (their sizes summed).
static func _weight(sim: Simulation) -> int:
	var out := 0
	for slime_id in sim.slimes.ids():
		out += sim.slimes.size_of(slime_id)
	return out


## Asserts slime `slime_id` of `sim` was lost: back on the train at the
## loop start and in the lost log.
func _assert_lost(sim: Simulation, slime_id: int, label: String) -> void:
	assert_eq(sim.slimes.state_of(slime_id), SlimeBodies.TRAIN, label + ": on the train")
	assert_true(sim.train.tracks(slime_id), label + ": the train tracks it")
	var reach := SlimeBodies.ring_radius_for(sim.slimes.size_of(slime_id)) + SlimeBodies.EDGE
	assert_lte(sim.train.distance_of(slime_id), LoopStart.SPOTS * 2.0 * reach, label + ": at the loop start")
	assert_true(slime_id in _lost_ids(sim), label + ": in the lost log")


# --- Versions ----------------------------------------------------------------------

func test_the_base_save_is_the_whole_population() -> void:
	assert_eq(_save["slimes"].size(), POPULATION)
	assert_eq(SaveMigration.displacements(_old_save(), _level.data, _terrain), PackedInt32Array(),
			"nothing is displaced in the level it was saved in")


func test_an_older_save_is_accepted_and_a_newer_one_refused() -> void:
	var newer := _newer()
	assert_eq(SaveData.problems(_old_save(), newer), PackedStringArray(), "older: migrated")
	assert_true(SaveMigration.is_older(_old_save(), newer))
	assert_false(SaveMigration.is_older(_old_save(), _level.data), "same version")
	var future := _old_save()
	future["level"]["version"] = _level.data.level_version + 1
	var problems := SaveData.problems(future, _level.data)
	assert_eq(problems.size(), 1, str(problems))
	assert_string_contains(problems[0] if not problems.is_empty() else "", "newer version")
	assert_null(Simulation.from_save(future, _level.data, _terrain, 1), "not loaded")


func test_the_header_takes_the_level_version_and_the_input_is_untouched() -> void:
	var newer := _newer()
	newer.sleepers.erase(_two_sleepers()[0])
	var save := _old_save()
	var before := SaveData.to_text(save)
	var migrated := SaveMigration.migrate(save, newer, _terrain)
	assert_eq(migrated["save"]["level"], newer.header())
	assert_eq(SaveData.to_text(save), before, "the input save is unmodified")
	assert_eq(SaveData.problems(migrated["save"], newer), PackedStringArray())


func test_a_save_of_the_same_level_unchanged_but_its_version_reloads_as_it_was() -> void:
	var newer := _newer()
	var migrated := SaveMigration.migrate(_old_save(), newer, _terrain)
	assert_eq(migrated["displaced"], PackedInt32Array())
	var old_slimes: Array = _save["slimes"]
	var new_slimes: Array = migrated["save"]["slimes"]
	assert_eq(new_slimes.size(), old_slimes.size())
	for k in mini(old_slimes.size(), new_slimes.size()):
		assert_eq(new_slimes[k], old_slimes[k], "slime %d untouched" % k)
	var sim := Simulation.from_save(_old_save(), newer, _terrain, 1)
	assert_not_null(sim)
	if sim != null:
		assert_eq(sim.slimes.slime_count, POPULATION)
		assert_eq(_lost_ids(sim), [])


# --- Sleepers ---------------------------------------------------------------------

func test_a_moved_sleeper_is_lost_to_the_loop_start_and_kept() -> void:
	var newer := _newer()
	var moved: String = _two_sleepers()[0]
	var still: String = _two_sleepers()[1]
	newer.sleepers[moved]["position"] += Vector2(50, 0)
	var sim := Simulation.from_save(_old_save(), newer, _terrain, 1)
	assert_not_null(sim)
	if sim == null:
		return
	assert_eq(sim.slimes.slime_count, POPULATION, "no slime dropped, none added")
	assert_eq(_weight(sim), POPULATION, "every basket's quota stays reachable")
	var slime := _holder(sim, moved)
	assert_ne(slime, -1, "still in the game, under its stable ID")
	if slime != -1:
		_assert_lost(sim, slime, moved)
	var sleeper := _holder(sim, still)
	assert_eq(sim.slimes.state_of(sleeper), SlimeBodies.SLEEPER, "the others sleep on")
	assert_eq(sim.slimes.centre_of(sleeper), SaveData.vector_from(_entry(_save, still)["centre"]),
			"where they were")
	var again := sim.to_save()
	assert_eq(again["slimes"].size(), POPULATION, "the next save keeps it")
	assert_eq(again["level"]["version"], newer.level_version)


func test_a_sleeper_whose_stable_id_is_gone_is_lost() -> void:
	var newer := _newer()
	var gone: String = _two_sleepers()[0]
	newer.sleepers.erase(gone)
	var migrated := SaveMigration.migrate(_old_save(), newer, _terrain)
	assert_false(_entry(migrated["save"], gone).is_empty(), "kept in the save")
	assert_eq(migrated["save"]["slimes"].size(), POPULATION)
	var sim := Simulation.from_save(_old_save(), newer, _terrain, 1)
	assert_not_null(sim)
	if sim == null:
		return
	assert_eq(sim.slimes.slime_count, POPULATION)
	var slime := _holder(sim, gone)
	assert_eq(migrated["displaced"], PackedInt32Array([slime]))
	if slime != -1:
		_assert_lost(sim, slime, gone)


func test_a_sleeper_of_another_species_now_is_lost() -> void:
	var newer := _newer()
	var changed: String = _two_sleepers()[0]
	var letter: String = newer.sleepers[changed]["species"]
	newer.sleepers[changed]["species"] = "B" if letter == "A" else "A"
	var sim := Simulation.from_save(_old_save(), newer, _terrain, 1)
	assert_not_null(sim)
	if sim != null:
		_assert_lost(sim, _holder(sim, changed), changed)


func test_a_sleeper_the_level_gained_is_added_asleep_at_its_spot() -> void:
	var newer := _newer()
	var beside: Dictionary = newer.sleepers[_two_sleepers()[0]]
	var spot: Vector2 = beside["position"] + Vector2(0, -200)
	newer.add_sleeper("zz.sleeper.new", "C", spot)
	var migrated := SaveMigration.migrate(_old_save(), newer, _terrain)
	var entry := _entry(migrated["save"], "zz.sleeper.new")
	assert_eq(entry.get("state"), "sleeper")
	assert_eq(entry.get("species"), "C")
	assert_eq(migrated["displaced"], PackedInt32Array(), "nothing displaced")
	var sim := Simulation.from_save(_old_save(), newer, _terrain, 1)
	assert_not_null(sim)
	if sim == null:
		return
	assert_eq(sim.slimes.slime_count, POPULATION + 1, "the level's population now")
	var slime := _holder(sim, "zz.sleeper.new")
	assert_eq(sim.slimes.state_of(slime), SlimeBodies.SLEEPER)
	assert_eq(sim.slimes.species_of(slime), Species.from_letter("C"))
	assert_eq(sim.slimes.size_of(slime), 1)
	assert_eq(sim.slimes.centre_of(slime), spot, "asleep at its spot")
	assert_eq(sim.identities.members_of(slime), PackedStringArray(["zz.sleeper.new"]))


# --- Awake slimes -----------------------------------------------------------------

## A point 10 px inside the terrain, under a long ground segment facing up
## (resolve() says it is inside).
func _inside_terrain() -> Vector2:
	for k in _terrain.segment_count():
		if _terrain.seg_n[k].y < -0.9 and _terrain.seg_d[k].length() > 100.0:
			var at: Vector2 = (_terrain.seg_a[k] + _terrain.seg_b[k]) * 0.5 - _terrain.seg_n[k] * 10.0
			if _terrain.resolve(at)["hit"]:
				return at
	fail_test("no ground segment found")
	return Vector2.ZERO


## The index in the base save of its first awake slime.
func _first_awake() -> int:
	for k in _save["slimes"].size():
		if _save["slimes"][k]["state"] != "sleeper":
			return k
	return -1


func test_an_awake_slime_now_inside_the_terrain_is_lost() -> void:
	var save := _old_save()
	var k := _first_awake()
	var slime: Dictionary = save["slimes"][k]
	slime["centre"] = SaveData.vector(_inside_terrain())
	slime.erase("body")
	var newer := _newer()
	var migrated := SaveMigration.migrate(save, newer, _terrain)
	var runtime := int(slime["runtime_id"])
	assert_eq(migrated["displaced"], PackedInt32Array([runtime]))
	var sim := Simulation.from_save(save, newer, _terrain, 1)
	assert_not_null(sim)
	if sim != null:
		assert_eq(sim.slimes.slime_count, POPULATION)
		_assert_lost(sim, runtime, "inside the terrain")


func test_an_awake_slime_now_outside_the_level_is_lost() -> void:
	var save := _old_save()
	var k := _first_awake()
	var slime: Dictionary = save["slimes"][k]
	slime["centre"] = [-100000.0, 0.0]
	slime.erase("body")
	var migrated := SaveMigration.migrate(save, _newer(), _terrain)
	assert_eq(migrated["displaced"], PackedInt32Array([int(slime["runtime_id"])]))


func test_the_same_slime_in_open_space_is_not_displaced() -> void:
	var migrated := SaveMigration.migrate(_old_save(), _newer(), _terrain)
	var k := _first_awake()
	assert_eq(migrated["displaced"], PackedInt32Array())
	assert_eq(migrated["save"]["slimes"][k], _save["slimes"][k], "kept as it was")


# --- Objects and gates -------------------------------------------------------------

func test_states_of_objects_gone_are_dropped_and_new_ones_start_fresh() -> void:
	var save := _old_save()
	save["objects"]["zz.switch.gone"] = {"flipped": true, "trapdoor_shut": false}
	save["gates"]["zz.gate.gone"] = {"open": true, "entrance_closed": true}
	save["train"]["open_gates"].append("zz.gate.gone")
	var newer := _newer()
	var basket: String = newer.baskets.keys()[0]
	newer.add_basket("zz.basket.new", newer.baskets[basket]["box"], 5, newer.baskets[basket]["outlet"])
	newer.add_gate("zz.gate.new", Rect2(-100000, -100000, 10, 10))
	var migrated := SaveMigration.migrate(save, newer, _terrain)
	var objects: Dictionary = migrated["save"]["objects"]
	var gates: Dictionary = migrated["save"]["gates"]
	assert_false(objects.has("zz.switch.gone"), "dropped")
	assert_false(gates.has("zz.gate.gone"), "dropped")
	assert_false("zz.gate.gone" in migrated["save"]["train"]["open_gates"], "not open any more")
	for id in _save["objects"]:
		assert_eq(objects.get(id), _save["objects"][id], "%s kept" % id)
	for id in _save["gates"]:
		assert_eq(gates.get(id), _save["gates"][id], "%s kept" % id)
	var sim := Simulation.from_save(save, newer, _terrain, 1)
	assert_not_null(sim)
	if sim == null:
		return
	assert_false(sim.object_states.has("zz.switch.gone"))
	assert_false(sim.gate_states.has("zz.gate.gone"))
	var fresh := Simulation.new(SEED)
	fresh.slimes.terrain = _terrain
	fresh.load_level(newer)
	assert_eq(sim.object_states.get("zz.basket.new"), fresh.object_states["zz.basket.new"], "initial state")
	assert_eq(sim.gate_states.get("zz.gate.new"), fresh.gate_states["zz.gate.new"], "initial state")

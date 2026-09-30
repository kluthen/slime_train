extends RefCounted
## The test level's persistence fixtures (chunk 19, DoD 28), built for
## tools/make_fixture.gd on the fresh level's simulation:
##   midair       awake slimes saved in mid-air over the ground of section 1
##                (a fixture's save keeps only their centres: loaded, they
##                are put down, D12);
##   old-version  a save of the test level's version 1 (the header says so;
##                make_fixture writes it), in which the sleeper nearest
##                OLD_SPOT sleeps on the ground there: version 2 has it
##                elsewhere, so it is displaced and lost when the save loads
##                (D72).
## The stable IDs are looked up in the level's data, never typed in.
# @spec-link [[req_test_level_and_test_mode]]

## old-version's save is of this version of the test level (the level is at
## 2 since chunk 19, so that this save is a genuine older one).
const OLD_VERSION := 1
## The fixtures' descriptions (their sidecars'), and where midair's camera
## starts (a level point: over its slimes).
const MIDAIR_DESCRIPTION := ("The fresh level with four size-1 train slimes saved in mid-air over "
		+ "section 1's ground, made of section 1's first four sleepers (in stable ID order): one just "
		+ "above the ground (4 px), one well above it (150 px), one a little above it (30 px) and one "
		+ "80 px above that one. A fixture keeps only their centres: loaded, each is put straight down "
		+ "on what is below it, at rest, none lost (D12). The camera on them. For persistence (chunk "
		+ "19, DoD 28).")
const MIDAIR_CAMERA := [1825.0, -150.0]
const OLD_VERSION_DESCRIPTION := ("The fresh level saved by the test level's version 1: the sleeper "
		+ "nearest x 1525 on section 1's ground sleeps there, while version 2 has it on its ledge. "
		+ "Loaded, the save is migrated: that slime is displaced and lost (to the loop start, in the "
		+ "lost log), every slime kept, and the next save is at version 2 (D72). For persistence "
		+ "(chunk 19).")
## midair's slimes, each on the ground's first surface below x (level px:
## section 1's open ground between its ledges, with nothing above) and this
## many px above its resting height: just above, well above, a little above.
## A last one is above the third, STACK_GAP px over its ring.
const MIDAIR := [[1525.0, 4.0], [1825.0, 150.0], [2125.0, 30.0]]
const STACK_GAP := 80.0
## Where old-version's moved sleeper sleeps in version 1: on the ground's
## first surface below this x, far from any sleeper's spot in version 2.
const OLD_SPOT_X := 1525.0
## A column is scanned for the ground from this y down to GROUND_BOTTOM.
const GROUND_TOP := -700.0
const GROUND_BOTTOM := 1000.0


## midair: the first MIDAIR.size() + 1 sleepers of section 1 (in stable ID
## order) woken as size-1 train slimes, in the air as MIDAIR and STACK_GAP
## say. False (and an error) when section 1 is short of sleepers or a column
## has no ground.
# @spec-link [[req_test_level_and_test_mode]]
# @spec-link [[req_persistence_and_saves]]
static func midair(sim: Simulation, data: LevelData, terrain: TerrainSegments) -> bool:
	var ids := _sleeper_ids(data, "s1.")
	if ids.size() < MIDAIR.size() + 1:
		push_error("make_fixture: section 1 has %d sleepers, midair needs %d" % [ids.size(), MIDAIR.size() + 1])
		return false
	var reach := SlimeBodies.ring_radius_for(1) + SlimeBodies.EDGE
	var last := Vector2.ZERO
	for k in MIDAIR.size() + 1:
		var at := Vector2(last.x, last.y - 2.0 * reach - STACK_GAP)
		if k < MIDAIR.size():
			var x: float = MIDAIR[k][0]
			var ground := _ground_below(terrain, x)
			if is_nan(ground):
				push_error("make_fixture: no ground below x %.0f for midair" % x)
				return false
			at = Vector2(x, ground - reach - float(MIDAIR[k][1]))
		_wake_at(sim, data, ids[k], at)
		last = at
	return true


## old-version: the level's sleeper nearest OLD_SPOT's ground sleeps there
## instead (its slime moved), and make_fixture says which. False (and an
## error) when the column has no ground.
# @spec-link [[req_test_level_and_test_mode]]
# @spec-link [[rule_released_level_stable_with_migration]]
static func old_version(sim: Simulation, data: LevelData, terrain: TerrainSegments) -> bool:
	var ground := _ground_below(terrain, OLD_SPOT_X)
	if is_nan(ground):
		push_error("make_fixture: no ground below x %.0f for old-version" % OLD_SPOT_X)
		return false
	var at := Vector2(OLD_SPOT_X, ground - SlimeBodies.ring_radius_for(1) - SlimeBodies.EDGE)
	var nearest := ""
	var ids: Array = data.sleepers.keys()
	ids.sort()
	for id in ids:
		var spot: Vector2 = data.sleepers[id]["position"]
		if nearest.is_empty() or spot.distance_to(at) < (data.sleepers[nearest]["position"] as Vector2).distance_to(at):
			nearest = id
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == nearest:
			sim.slimes.translate(slime_id, at - sim.slimes.centre_of(slime_id))
	print("make_fixture: old-version moves %s" % nearest)
	return true


## Replaces sleeper `stable_id`'s body with a size-1 train slime of its
## species following the loop from its point nearest `at`, its centre at
## `at`.
static func _wake_at(sim: Simulation, data: LevelData, stable_id: String, at: Vector2) -> void:
	for slime_id in sim.slimes.ids():
		if sim.identities.stable_id_of(slime_id) == stable_id:
			sim.slimes.remove(slime_id)
	sim.identities.tidy(sim.slimes)
	var distance: float = data.loop.closest(at, sim.train.open_gates)["distance"]
	var slime := sim.spawn_train_slime(Species.from_letter(data.sleepers[stable_id]["species"]), 1, distance)
	sim.identities.assign(slime, PackedStringArray([stable_id]))
	sim.slimes.translate(slime, at - sim.slimes.centre_of(slime))


## The y of the terrain's first surface below GROUND_TOP at `x`, or NAN
## when the column has none down to GROUND_BOTTOM.
static func _ground_below(terrain: TerrainSegments, x: float) -> float:
	var y := GROUND_TOP
	while y < GROUND_BOTTOM:
		if terrain.resolve(Vector2(x, y))["hit"]:
			return y
		y += 1.0
	return NAN


## The stable IDs of the level's sleepers starting with `prefix`, sorted.
static func _sleeper_ids(data: LevelData, prefix: String) -> Array:
	var out := data.sleepers.keys().filter(func(id): return id.begins_with(prefix))
	out.sort()
	return out

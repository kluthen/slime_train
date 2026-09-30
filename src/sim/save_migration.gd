class_name SaveMigration
extends RefCounted
## Save migration by level version (chunk 19, decision C, proposed; D72): a
## save of an older version of a level, loaded into the level as it is now.
## Pure logic over the save's plain data (SaveData's format), keyed by stable
## IDs; SaveData.restore applies it when the save's version is lower than
## the level's (SaveData.problems refuses a higher one: a newer game's).
##
## The generic migration. A slime is displaced when:
## - it is a sleeper (state "sleeper") whose stable ID the level no longer
##   has as a sleeper, whose spot moved (more than MOVED px from the level's
##   sleeper), or whose species changed;
## - it is awake and its centre is no longer in open space: inside the
##   terrain (TerrainSegments.is_solid), outside the level (Train.bounds_for:
##   the box outside which a train slime is out of bounds), or, in a basket,
##   in no basket of the level.
## A displaced slime stays in the save as it was: SaveData.restore loses it
## the usual way (Offscreen.lose: to the loop start, back on the train, in
## the lost log), so no slime is ever dropped and the population, and with
## it every basket's quota, stays whole. A sleeper of the level that no
## slime of the save holds (a sleeper added since) is added asleep at its
## spot, as a hand-made save's slime (no body: a rest ring at its centre, the
## ring Sleepers.place makes in a fresh game), after the others. The states
## of objects and gates whose stable ID is gone are dropped, and gone gates
## leave the train's open gates; new objects and gates are left out, so the
## load gives them their initial state (FrontierSets.start, as in a fresh
## game). The header takes the level's version.
##
## The shared detection (level_slimes(), sleeper_moved(), unheld(),
## stateless_objects()) is also the fixture tools' (LevelFixtures.stale:
## whether a fixture's save is older than the level).
# @spec-link [[rule_released_level_stable_with_migration]]
# @spec-link [[rule_saves_never_wiped]]

## A sleeper this far from its place in the level has moved, px (saves
## round a hand-made save's centres to hundredths).
const MOVED := 1.0


## Whether `save` (one SaveData.problems accepts for `data`) was saved by an
## older version of the level: then it loads through migrate().
# @spec-link [[rule_released_level_stable_with_migration]]
static func is_older(save: Dictionary, data: LevelData) -> bool:
	return int(save["level"]["version"]) < data.level_version


## `save` (one SaveData.problems accepts for `data`) migrated to the level
## `data` on its `terrain` (see the class doc): {"save" (a deep copy, the
## input untouched), "displaced" (PackedInt32Array: the runtime ids of the
## displaced slimes, in save order, for SaveData.restore to lose)}.
# @spec-link [[rule_released_level_stable_with_migration]]
# @spec-link [[rule_saves_never_wiped]]
static func migrate(save: Dictionary, data: LevelData, terrain: TerrainSegments) -> Dictionary:
	var out: Dictionary = save.duplicate(true)
	var displaced := displacements(save, data, terrain)
	_add_sleepers(out, data)
	_drop_gone_states(out, data)
	out["level"] = data.header()
	return {"save": out, "displaced": displaced}


## The runtime ids of the slimes of `save` displaced in level `data` on its
## `terrain` (see the class doc), in save order. Slimes without a
## runtime_id are numbered 1, 2, ... in list order, as SaveData.restore does.
# @spec-link [[rule_released_level_stable_with_migration]]
static func displacements(save: Dictionary, data: LevelData, terrain: TerrainSegments) -> PackedInt32Array:
	var out := PackedInt32Array()
	var bounds := Train.bounds_for(terrain, data.loop)
	var slimes: Array = save["slimes"]
	for k in slimes.size():
		var slime: Dictionary = slimes[k]
		var runtime := int(slime["runtime_id"]) if slime.has("runtime_id") else k + 1
		var moved := (_sleeper_displaced(slime, data) if slime["state"] == "sleeper"
				else not _in_open_space(slime, data, terrain, bounds))
		if moved:
			out.append(runtime)
	return out


## The slimes a level places: stable ID -> its entry (the first slime, as
## LevelData.first_slime, and each sleeper, as in LevelData.sleepers).
static func level_slimes(data: LevelData) -> Dictionary:
	var out := {}
	if not data.first_slime.is_empty():
		out[data.first_slime["id"]] = data.first_slime
	for id in data.sleepers:
		out[id] = data.sleepers[id]
	return out


## Whether a save's slime `slime` sleeps more than MOVED px from the spot of
## the level's sleeper `sleeper` (an entry of LevelData.sleepers).
static func sleeper_moved(slime: Dictionary, sleeper: Dictionary) -> bool:
	return SaveData.vector_from(slime["centre"]).distance_to(sleeper["position"]) > MOVED


## The stable IDs of the level's slimes (level_slimes()) that no slime of
## `save` holds, sorted.
static func unheld(save: Dictionary, data: LevelData) -> Array:
	var held := {}
	for slime in save.get("slimes", []):
		for id in slime.get("members", []):
			held[id] = true
	var out := level_slimes(data).keys().filter(func(id): return not held.has(id))
	out.sort()
	return out


## The stable IDs of the level's switches, baskets, then gates that have no
## state in `save` (its "objects" and "gates").
static func stateless_objects(save: Dictionary, data: LevelData) -> Array:
	var out := []
	var objects: Dictionary = save.get("objects", {})
	var gates: Dictionary = save.get("gates", {})
	for id in data.switches.keys() + data.baskets.keys():
		if not objects.has(id):
			out.append(id)
	for id in data.gates:
		if not gates.has(id):
			out.append(id)
	return out


## Whether sleeper `slime` of a save is displaced in level `data`: its stable
## ID is no sleeper of the level, or the level's sleeper sleeps elsewhere or
## is of another species.
static func _sleeper_displaced(slime: Dictionary, data: LevelData) -> bool:
	var id: Variant = slime.get("id")
	if id == null or not data.sleepers.has(id):
		return true
	var sleeper: Dictionary = data.sleepers[id]
	return sleeper_moved(slime, sleeper) or slime["species"] != sleeper["species"]


## Whether awake slime `slime` of a save has its centre in open space in
## level `data`: out of the `terrain`, inside `bounds` (none: no box to
## check), and, in a basket, inside one of the level's baskets.
static func _in_open_space(slime: Dictionary, data: LevelData, terrain: TerrainSegments,
		bounds: Rect2) -> bool:
	var centre := SaveData.vector_from(slime["centre"])
	if terrain != null and terrain.is_solid(centre):
		return false
	if bounds.has_area() and not bounds.has_point(centre):
		return false
	if slime["state"] != "in_basket":
		return true
	for id in data.baskets:
		if (data.baskets[id]["box"] as Rect2).has_point(centre):
			return true
	return false


## Appends to `save` a sleeper for each of the level's sleepers no slime of
## it holds, in stable ID order, with the next runtime ids (when the save
## numbers its slimes) and next_slime_id moved past them.
static func _add_sleepers(save: Dictionary, data: LevelData) -> void:
	var slimes: Array = save["slimes"]
	var numbered: bool = slimes[0].has("runtime_id")
	var sim: Dictionary = save.get("sim", {})
	var next := int(sim.get("next_slime_id", 0))
	if numbered:
		next = maxi(next, int(slimes[-1]["runtime_id"]) + 1)
	for id in unheld(save, data):
		if not data.sleepers.has(id):
			continue
		var sleeper: Dictionary = data.sleepers[id]
		var entry := {"id": id, "members": [id], "species": sleeper["species"], "size": 1,
				"state": "sleeper", "centre": SaveData.vector(sleeper["position"]),
				"velocity": SaveData.vector(Vector2.ZERO)}
		if numbered:
			entry["runtime_id"] = next
			next += 1
		slimes.append(entry)
	if numbered and save.has("sim"):
		save["sim"]["next_slime_id"] = next


## Drops from `save` the object and gate states whose stable ID the level
## `data` no longer has, and the gone gates from the train's open gates.
static func _drop_gone_states(save: Dictionary, data: LevelData) -> void:
	var objects: Dictionary = save.get("objects", {})
	for id in objects.keys():
		if not data.switches.has(id) and not data.baskets.has(id):
			objects.erase(id)
	var gates: Dictionary = save.get("gates", {})
	for id in gates.keys():
		if not data.gates.has(id):
			gates.erase(id)
	var train: Variant = save.get("train")
	if train is Dictionary and train.get("open_gates") is Array:
		train["open_gates"] = train["open_gates"].filter(func(id): return data.gates.has(id))

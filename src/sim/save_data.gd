class_name SaveData
extends RefCounted
## The save format: a simulation as plain JSON data and back (pure logic, no
## files; SaveStore writes them). Simulation.to_save() and
## Simulation.from_save() use it. A reloaded save has the same state hash as
## the simulation saved, and stays equal to it tick after tick.
##
## Format 1 (see docs/dev/README.md, "Saves and fixtures"):
##
##   {
##     "format": 1,
##     "level": {"id": "test", "version": 1},
##     "sim": {"tick", "seed", "rng_state", "next_slime_id"},   # optional
##     "slimes": [ {                        # in runtime id order, at least one
##       "id": "s1.sleeper.02" or null,     # stable ID: the first member
##       "members": ["s1.sleeper.02", ...], # SlimeIdentities
##       "runtime_id": 4,                   # optional (all or none)
##       "species": "C", "size": 2, "state": "train" | "free" | "sleeper" | "bedtime_asleep",
##       "centre": [x, y], "velocity": [x, y],
##       "train": {"distance", "laps", "on_slide", "mark", "marked_at", "lost"},  # optional
##       "free": {"phase", "since", "point", "route", "rng_state"},             # optional
##       "body": {"points", "previous", "centre", "hop_timer", "heading", "held",
##                "supported", "rng_state"},                                   # optional
##     } ],
##     "train": {"open_gates": [...], "lost": [{"id", "tick", "reason"}]},
##     "call": null or {"point", "tick"},
##     "objects": {}, "gates": {},          # stable ID -> state (chunk 14)
##     "hint_done": true,                   # optional: the first call happened
##     "transient": {"view", "camera", "ripples", "taps", "facing", "input_log",
##                   "tilt", "fusion", "hint"},                          # optional
##   }
##
## The first-play hint (Hint): "hint_done" is the level's done mark (absent:
## false, the hint is due, as on a fresh save); "transient.hint" keeps its
## count ({"since", "bedtime"}) so a reload is exact. The game restarts the
## count when it shows the reloaded world (Hint.world_shown).
##
## Exactness. JSON numbers are doubles printed to 17 digits, and Godot's
## parser doesn't always read those back to the same double. So every real
## goes through exact(): kept as a number when it reads back the same, else
## written as "f64:<16 hex digits>" (its IEEE bytes). Points and previous
## points are base64 of their coordinates as little-endian doubles. 64-bit
## integers (seeds, generator states) are strings. JSON reads every number
## as a float, so whole numbers are turned back into ints on load.
##
## Optional parts, for hand-made saves (fixtures): without "sim" the run's
## seed is used and the tick is 0; without "runtime_id" slimes are numbered
## 1, 2, ... in list order; without "body" a slime is a rest ring at its
## centre with a fresh stream; a train slime without "train" is placed where
## the loop is closest; without "transient" the view and the input start
## empty.
##
## Not saved: the fingers on the screen (a restarted game has none: saving
## them would leave a finger stuck down), input not yet consumed, and what
## each tick recomputes (hop aims, touching pairs).
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[req_interactive_objects_general]]

const FORMAT := 1
const EXACT_PREFIX := "f64:"
const PHASES := [FreeSlimes.ANSWERING, FreeSlimes.UNSURE, FreeSlimes.HEADING_BACK]


# --- Saving --------------------------------------------------------------------

## The save of `sim`, as plain JSON data.
static func capture(sim: Simulation) -> Dictionary:
	var slimes := []
	for slime_id in sim.slimes.ids():
		slimes.append(_slime(sim, slime_id))
	var train: Variant = null
	if sim.train != null:
		var lost := []
		for entry in sim.train.lost:
			lost.append({"id": entry["id"], "tick": entry["tick"], "reason": entry["reason"]})
		train = {"open_gates": sim.train.open_gates.duplicate(), "lost": lost}
	var last_call: Variant = null
	if sim.free_slimes.call_tick >= 0:
		last_call = {"point": vector(sim.free_slimes.call_point), "tick": sim.free_slimes.call_tick}
	return {
		"format": FORMAT,
		"level": sim.level.header() if sim.level != null else null,
		"sim": {"tick": sim.tick, "seed": str(sim.rng.seed_value), "rng_state": str(sim.rng.state),
				"next_slime_id": sim.slimes.next_id},
		"slimes": slimes,
		"train": train,
		"call": last_call,
		"objects": sim.object_states.duplicate(true),
		"gates": sim.gate_states.duplicate(true),
		"hint_done": sim.hint.done,
		"transient": _transient(sim),
	}


static func _slime(sim: Simulation, slime_id: int) -> Dictionary:
	var bodies := sim.slimes
	var members := sim.identities.members_of(slime_id)
	var body := bodies.body_of(slime_id)
	var out := {
		"id": members[0] if not members.is_empty() else null,
		"members": Array(members),
		"runtime_id": slime_id,
		"species": Species.letter(bodies.species_of(slime_id)),
		"size": bodies.size_of(slime_id),
		"state": SlimeBodies.STATE_NAMES[bodies.state_of(slime_id)],
		"centre": vector(bodies.centre_of(slime_id)),
		"velocity": vector(bodies.velocity_of(slime_id)),
		"body": {"points": pack_vectors(body["points"]), "previous": pack_vectors(body["previous"]),
				"centre": vector(body["centre"]), "hop_timer": exact(body["hop_timer"]),
				"heading": exact(body["heading"]), "held": body["held"], "supported": body["supported"],
				"rng_state": str(body["rng_state"])},
	}
	if sim.train != null and sim.train.tracks(slime_id):
		var record := sim.train.record_of(slime_id)
		out["train"] = {"distance": exact(record["distance"]), "laps": record["laps"],
				"on_slide": record["on_slide"], "mark": exact(record["mark"]),
				"marked_at": record["marked_at"], "lost": record["lost"]}
	if sim.free_slimes.tracks(slime_id):
		var record := sim.free_slimes.record_of(slime_id)
		out["free"] = {"phase": record["phase"], "since": record["since"], "point": vector(record["point"]),
				"route": record["route"], "rng_state": str(record["rng_state"])}
	return out


static func _transient(sim: Simulation) -> Dictionary:
	var ripples := []
	for ripple in sim.ripples:
		ripples.append({"at": vector(ripple["at"]), "tick": ripple["tick"]})
	var taps := []
	for tap in sim.taps:
		taps.append({"tick": tap["tick"], "finger": tap["finger"], "screen": vector(tap["screen"]),
				"world": vector(tap["world"]), "zone": tap["zone"], "side": tap["side"],
				"object": tap["object"], "kind": tap["kind"], "call": tap["call"],
				"answered": tap["answered"].duplicate()})
	var facing := []
	var ids := sim.facing.keys()
	ids.sort()
	for slime_id in ids:
		facing.append({"id": slime_id, "facing": vector(sim.facing[slime_id])})
	var log := []
	for event in sim.input_log:
		log.append(_exact_values(event))
	return {
		"view": {"centre": vector(sim.view.centre), "zoom": exact(sim.view.zoom),
				"screen_size": vector(sim.view.screen_size)},
		"ripples": ripples,
		"taps": taps,
		"facing": facing,
		"input_log": log,
		"fusion": sim.fusion.dump(),
		"camera": _exact_values(sim.camera.dump()),
		"hint": {"since": sim.hint.since, "bedtime": sim.hint.bedtime},
		"tilt": {"degrees": exact(sim.phone_tilt.degrees), "neutral": exact(sim.phone_tilt.neutral),
				"flat": sim.phone_tilt.flat},
	}


## `data` with its reals exact() and its vectors vector().
static func _exact_values(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		var value: Variant = data[key]
		match typeof(value):
			TYPE_VECTOR2:
				out[key] = vector(value)
			TYPE_FLOAT:
				out[key] = exact(value)
			_:
				out[key] = value
	return out


## The reverse of _exact_values(): [x, y] back to vectors, exact reals back
## to floats. Whole numbers stay floats; the owner's restore() casts them.
static func _typed_values(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		var value: Variant = data[key]
		if typeof(value) == TYPE_ARRAY and value.size() == 2:
			out[key] = vector_from(value)
		elif typeof(value) == TYPE_STRING and value.begins_with(EXACT_PREFIX):
			out[key] = real(value)
		else:
			out[key] = value
	return out


# --- Checking ------------------------------------------------------------------

## What makes `save` unusable with `level_data` (empty: it can be loaded).
## A save of another level version is refused: migrating it comes with
## chunk 19, and until then it is kept untouched.
static func problems(save: Variant, level_data: LevelData) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(save) != TYPE_DICTIONARY:
		return PackedStringArray(["not a save (expected a dictionary)"])
	var format: Variant = _whole(save.get("format"))
	if format == null:
		out.append("no format number")
	elif format > FORMAT:
		out.append("format %d is newer than this game's (%d)" % [format, FORMAT])
	elif format < 1:
		out.append("unknown format %d" % format)
	var header: Variant = save.get("level")
	if typeof(header) != TYPE_DICTIONARY:
		out.append("no level header")
	elif level_data == null:
		out.append("no level loaded to put the save in")
	else:
		if str(header.get("id", "")) != level_data.level_id:
			out.append("saved for level '%s', not '%s'" % [header.get("id", ""), level_data.level_id])
		var version: Variant = _whole(header.get("version"))
		if version != level_data.level_version:
			out.append("saved for version %s of level '%s', which is at version %d (migration: chunk 19)"
					% [header.get("version"), level_data.level_id, level_data.level_version])
	var sim: Variant = save.get("sim", {})
	if typeof(sim) != TYPE_DICTIONARY:
		out.append("'sim' must be a dictionary")
	else:
		for key in ["seed", "rng_state"]:
			if sim.has(key) and not str(sim[key]).is_valid_int():
				out.append("'sim.%s' must be a whole number as a string" % key)
		for key in ["tick", "next_slime_id"]:
			if sim.has(key) and (_whole(sim[key]) == null or _whole(sim[key]) < 0):
				out.append("'sim.%s' must be a whole number >= 0" % key)
	var slimes: Variant = save.get("slimes")
	if typeof(slimes) != TYPE_ARRAY or slimes.is_empty():
		out.append("no slimes (a level always has at least its first slime)")
	else:
		out.append_array(_slime_problems(slimes))
	for key in ["objects", "gates"]:
		if typeof(save.get(key, {})) != TYPE_DICTIONARY:
			out.append("'%s' must be a dictionary (stable ID -> state)" % key)
	for key in ["train", "call", "transient"]:
		var part: Variant = save.get(key)
		if part != null and typeof(part) != TYPE_DICTIONARY:
			out.append("'%s' must be a dictionary or null" % key)
	if save.has("hint_done") and typeof(save["hint_done"]) != TYPE_BOOL:
		out.append("'hint_done' must be true or false")
	return out


static func _slime_problems(slimes: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var with_ids := 0
	var last_id := 0
	for k in slimes.size():
		var slime: Variant = slimes[k]
		var at := "slime %d: " % k
		if typeof(slime) != TYPE_DICTIONARY:
			out.append(at + "not a dictionary")
			continue
		var letter := str(slime.get("species", ""))
		if letter.length() != 1 or Species.from_letter(letter) < 0:
			out.append(at + "unknown species '%s'" % letter)
		var size: Variant = _whole(slime.get("size"))
		if size == null or size < 1 or size > SlimeBodies.MAX_SIZE:
			out.append(at + "size must be 1 to %d" % SlimeBodies.MAX_SIZE)
		if str(slime.get("state", "")) not in SlimeBodies.STATE_NAMES:
			out.append(at + "unknown state '%s'" % slime.get("state", ""))
		if not _is_vector(slime.get("centre")):
			out.append(at + "'centre' must be [x, y]")
		if slime.has("velocity") and not _is_vector(slime["velocity"]):
			out.append(at + "'velocity' must be [x, y]")
		if typeof(slime.get("members", [])) != TYPE_ARRAY:
			out.append(at + "'members' must be a list of stable IDs")
		if slime.has("runtime_id"):
			with_ids += 1
			var runtime: Variant = _whole(slime["runtime_id"])
			if runtime == null or runtime <= last_id:
				out.append(at + "runtime ids must be whole numbers, ascending, without repeats")
			else:
				last_id = runtime
		var free: Variant = slime.get("free")
		if free != null and (typeof(free) != TYPE_DICTIONARY or str(free.get("phase", "")) not in PHASES):
			out.append(at + "'free' needs a phase: %s" % ", ".join(PHASES))
		var train: Variant = slime.get("train")
		if train != null and typeof(train) != TYPE_DICTIONARY:
			out.append(at + "'train' must be a dictionary")
		var body: Variant = slime.get("body")
		if body != null and size != null and size >= 1 and size <= SlimeBodies.MAX_SIZE:
			var n := SlimeBodies.points_for(size)
			if (typeof(body) != TYPE_DICTIONARY or unpack_vectors(str(body.get("points", ""))).size() != n
					or unpack_vectors(str(body.get("previous", ""))).size() != n):
				out.append(at + "'body' must hold %d points and previous points" % n)
	if with_ids != 0 and with_ids != slimes.size():
		out.append("either every slime has a runtime_id or none does")
	return out


# --- Loading -------------------------------------------------------------------

## The simulation saved in `save`, on `level_data` and `terrain`, or null
## when problems() finds any. `fallback_seed` is used when the save has none.
static func restore(save: Dictionary, level_data: LevelData, terrain: TerrainSegments,
		fallback_seed: int) -> Simulation:
	if not problems(save, level_data).is_empty():
		return null
	var saved_sim: Dictionary = save.get("sim", {})
	var seed_value := str(saved_sim["seed"]).to_int() if saved_sim.has("seed") else fallback_seed
	var sim := Simulation.new(seed_value)
	sim.slimes.terrain = terrain
	sim.tick = _whole(saved_sim.get("tick", 0))
	if saved_sim.has("rng_state"):
		sim.rng.state = str(saved_sim["rng_state"]).to_int()
	# Bodies first, so that load_level finds slimes and wakes no first slime.
	var slimes: Array = save["slimes"]
	var runtime_ids := PackedInt32Array()
	for k in slimes.size():
		var slime: Dictionary = slimes[k]
		var slime_id: int = _whole(slime["runtime_id"]) if slime.has("runtime_id") else k + 1
		runtime_ids.append(slime_id)
		var state := SlimeBodies.STATE_NAMES.find(str(slime["state"]))
		sim.slimes.create_with_id(slime_id, Species.from_letter(str(slime["species"])), _whole(slime["size"]),
				vector_from(slime["centre"]), state)
		if slime.has("body"):
			var body: Dictionary = slime["body"]
			sim.slimes.set_body(slime_id, {"points": unpack_vectors(body["points"]),
					"previous": unpack_vectors(body["previous"]), "centre": vector_from(body["centre"]),
					"hop_timer": real(body["hop_timer"]), "heading": real(body["heading"]),
					"held": bool(body["held"]), "supported": bool(body["supported"]),
					"rng_state": str(body["rng_state"]).to_int()})
		elif slime.has("velocity"):
			sim.slimes.set_velocity(slime_id, vector_from(slime["velocity"]))
		sim.identities.assign(slime_id, PackedStringArray(slime.get("members", [])))
	sim.slimes.next_id = maxi(sim.slimes.next_id, _whole(saved_sim.get("next_slime_id", 0)))
	sim.load_level(level_data)
	sim.hint.done = save.get("hint_done", false)
	var saved_train: Variant = save.get("train")
	if sim.train != null and saved_train is Dictionary:
		sim.train.set_open_gates(saved_train.get("open_gates", []))
		for entry in saved_train.get("lost", []):
			sim.train.lost.append({"id": _whole(entry["id"]), "tick": _whole(entry["tick"]),
					"reason": str(entry["reason"])})
	for k in slimes.size():
		_restore_progress(sim, runtime_ids[k], slimes[k])
	var last_call: Variant = save.get("call")
	if last_call is Dictionary:
		sim.free_slimes.call_point = vector_from(last_call["point"])
		sim.free_slimes.call_tick = _whole(last_call["tick"])
	sim.object_states = save.get("objects", {}).duplicate(true)
	sim.gate_states = save.get("gates", {}).duplicate(true)
	var transient: Variant = save.get("transient")
	if transient is Dictionary:
		_restore_transient(sim, transient)
	sim.hint.update(sim.tick)
	return sim


static func _restore_progress(sim: Simulation, slime_id: int, slime: Dictionary) -> void:
	var train: Variant = slime.get("train")
	if sim.train != null and train is Dictionary:
		var record := {}
		for key in ["distance", "mark"]:
			if train.has(key):
				record[key] = real(train[key])
		for key in ["laps", "marked_at"]:
			if train.has(key):
				record[key] = _whole(train[key])
		for key in ["on_slide", "lost"]:
			if train.has(key):
				record[key] = bool(train[key])
		sim.train.restore_record(slime_id, record)
	elif sim.train != null and sim.slimes.state_of(slime_id) == SlimeBodies.TRAIN:
		var at := sim.slimes.centre_of(slime_id)
		sim.train.track(slime_id, sim.level.loop.closest(at, sim.train.open_gates)["distance"])
	var free: Variant = slime.get("free")
	if free is Dictionary:
		var record := {"phase": str(free["phase"]), "since": _whole(free.get("since", 0)),
				"point": vector_from(free.get("point", [0, 0])), "route": str(free.get("route", ""))}
		if free.has("rng_state"):
			record["rng_state"] = str(free["rng_state"]).to_int()
		sim.free_slimes.restore_record(slime_id, record)


static func _restore_transient(sim: Simulation, transient: Dictionary) -> void:
	# After load_level, which takes the tilt's neutral: the saved neutral wins,
	# so the reloaded state is the saved one. Taking a new neutral when a
	# session resumes is the session's job (chunk 17, D95).
	if transient.get("tilt") is Dictionary:
		var tilt: Dictionary = transient["tilt"]
		sim.phone_tilt.restore({"degrees": real(tilt.get("degrees", 0.0)),
				"neutral": real(tilt.get("neutral", 0.0)), "flat": bool(tilt.get("flat", false))})
	# The camera after load_level too, which puts it on the rails near the
	# first slime. A save keeps no fingers, so no edge button stays held.
	if transient.get("camera") is Dictionary:
		sim.camera.restore(_typed_values(transient["camera"]))
		sim.camera.release(sim.camera.hold_finger)
	if transient.get("hint") is Dictionary:
		sim.hint.since = _whole(transient["hint"].get("since", sim.tick))
		sim.hint.bedtime = bool(transient["hint"].get("bedtime", false))
	if transient.get("view") is Dictionary:
		var view: Dictionary = transient["view"]
		sim.view.set_to(vector_from(view["centre"]), real(view["zoom"]), vector_from(view["screen_size"]))
	for ripple in transient.get("ripples", []):
		sim.ripples.append({"at": vector_from(ripple["at"]), "tick": _whole(ripple["tick"])})
	for tap in transient.get("taps", []):
		var answered := []
		for slime_id in tap["answered"]:
			answered.append(_whole(slime_id))
		sim.taps.append({"tick": _whole(tap["tick"]), "finger": _whole(tap["finger"]),
				"screen": vector_from(tap["screen"]), "world": vector_from(tap["world"]),
				"zone": str(tap["zone"]), "side": _whole(tap["side"]), "object": str(tap["object"]),
				"kind": str(tap["kind"]), "call": bool(tap["call"]), "answered": answered})
	for entry in transient.get("facing", []):
		sim.facing[_whole(entry["id"])] = vector_from(entry["facing"])
	# The contact counts (Fusion): [[a, b, ticks]], whole numbers.
	if transient.get("fusion") is Array:
		sim.fusion.restore(transient["fusion"])
	for event in transient.get("input_log", []):
		var entry := {"kind": str(event["kind"]), "tick": _whole(event["tick"])}
		if event.has("finger"):
			entry["finger"] = _whole(event["finger"])
		if event.has("at"):
			entry["at"] = vector_from(event["at"]) if event["at"] != null else null
		if event.has("degrees"):
			entry["degrees"] = real(event["degrees"])
		if event.has("flat"):
			entry["flat"] = bool(event["flat"])
		sim.input_log.append(entry)


# --- Text and values -----------------------------------------------------------

## The save as JSON text: keys sorted, tab-indented, full precision.
static func to_text(save: Dictionary) -> String:
	return JSON.stringify(save, "\t", true, true)


## `x` as JSON can carry it exactly: the number itself when it reads back
## the same, else "f64:" and the hex of its 8 bytes (little-endian).
static func exact(x: float) -> Variant:
	if is_finite(x) and JSON.parse_string(JSON.stringify([x], "", false, true))[0] == x:
		return x
	return EXACT_PREFIX + PackedFloat64Array([x]).to_byte_array().hex_encode()


## A real written by exact() (or a plain number from a hand-made save).
static func real(value: Variant) -> float:
	if typeof(value) == TYPE_STRING and value.begins_with(EXACT_PREFIX):
		return value.substr(EXACT_PREFIX.length()).hex_decode().decode_double(0)
	return float(value)


## A vector as [x, y], each exact().
static func vector(v: Vector2) -> Array:
	return [exact(v.x), exact(v.y)]


## A vector from [x, y] (reals as exact() writes them).
static func vector_from(value: Variant) -> Vector2:
	return Vector2(real(value[0]), real(value[1]))


## Points as base64 of their coordinates, x then y, as little-endian doubles.
static func pack_vectors(points: PackedVector2Array) -> String:
	var numbers := PackedFloat64Array()
	numbers.resize(points.size() * 2)
	for k in points.size():
		numbers[2 * k] = points[k].x
		numbers[2 * k + 1] = points[k].y
	return Marshalls.raw_to_base64(numbers.to_byte_array())


## The points pack_vectors() wrote (empty when the text isn't such a list).
static func unpack_vectors(text: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	if text.is_empty():
		return out
	var numbers := Marshalls.base64_to_raw(text).to_float64_array()
	if numbers.size() % 2 != 0:
		return out
	out.resize(numbers.size() / 2)
	for k in out.size():
		out[k] = Vector2(numbers[2 * k], numbers[2 * k + 1])
	return out


## A save cut down to what a person reads and edits (fixtures): the level,
## and each slime's identity, species, size, state, centre and progress
## (train distance, free phase). The run's seed then drives the rest.
static func readable(save: Dictionary) -> Dictionary:
	var slimes := []
	for slime in save["slimes"]:
		var out := {}
		for key in ["id", "members", "species", "size", "state"]:
			out[key] = slime[key]
		out["centre"] = _rounded(vector_from(slime["centre"]))
		if slime.has("train"):
			out["train"] = {"distance": snappedf(real(slime["train"]["distance"]), 0.01)}
		if slime.has("free"):
			out["free"] = {"phase": slime["free"]["phase"], "since": 0,
					"point": _rounded(vector_from(slime["free"]["point"])), "route": slime["free"]["route"]}
		slimes.append(out)
	return {"format": save["format"], "level": save["level"], "slimes": slimes,
			"objects": save.get("objects", {}), "gates": save.get("gates", {}),
			"hint_done": save.get("hint_done", false)}


static func _rounded(v: Vector2) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]


## An int from an int or a whole float (JSON numbers are floats), else null.
static func _whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value):
		return int(value)
	return null


static func _is_vector(value: Variant) -> bool:
	return (typeof(value) == TYPE_ARRAY and value.size() == 2
			and typeof(value[0]) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]
			and typeof(value[1]) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING])

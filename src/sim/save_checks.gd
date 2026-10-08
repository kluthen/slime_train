class_name SaveChecks
extends RefCounted
## What makes a save unusable (SaveData.problems): every key capture()
## always writes must be there, of its kind, and every optional key of its
## kind when it is there (see docs/dev/README.md, "Defaults on load"). Pure
## checks on plain JSON data: no error pushed, nothing loaded.

## The phases a free record may have.
const PHASES := [FreeSlimes.ANSWERING, FreeSlimes.UNSURE, FreeSlimes.HEADING_BACK]
## The kinds of value _needed() checks a key for, and how a problem names them.
enum Kind { WHOLE, REAL, VECTOR, TEXT, FLAG, DICT, LIST, WHOLE_TEXT }
const KIND_NAMES := ["a whole number", "a number", "[x, y]", "a string", "true or false", "a dictionary",
		"a list", "a whole number as a string"]
## The keys of the camera's state (Camera.dump), all needed in a save's
## "transient.camera".
const CAMERA_KEYS := {"mode": Kind.TEXT, "zoom": Kind.REAL, "position": Kind.VECTOR, "distance": Kind.REAL,
		"rail_left": Kind.REAL, "rail_gap": Kind.VECTOR, "rail_length": Kind.REAL, "hold_finger": Kind.WHOLE,
		"hold_side": Kind.WHOLE, "drag_point": Kind.VECTOR, "drag_tick": Kind.WHOLE,
		"return_distance": Kind.REAL, "edge_buttons_visible": Kind.FLAG, "frame_zone": Kind.TEXT,
		"frame_shift": Kind.VECTOR, "zone_hold": Kind.WHOLE, "quiet": Kind.WHOLE, "cue_from": Kind.REAL,
		"follow_id": Kind.WHOLE, "follow_species": Kind.WHOLE, "follow_point": Kind.VECTOR,
		"screensaver": Kind.FLAG, "show_distance": Kind.REAL, "show_tick": Kind.WHOLE}


## What makes `save` unusable with `level_data` (empty: it can be loaded).
## A save of an older version of the level is usable: restore() migrates it
## (SaveMigration, chunk 19, decision C). A save of a newer version (a newer
## game's) is refused, and kept untouched (rule_saves_never_wiped). A format
## other than this build's own is refused, older as well as newer: no save
## format is migrated (D149; before the app has shipped none needs to be).
# @spec-link [[req_persistence_and_saves]]
# @spec-link [[rule_released_level_stable_with_migration]]
# @spec-link [[rule_saves_never_wiped]]
static func problems(save: Variant, level_data: LevelData) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(save) != TYPE_DICTIONARY:
		return PackedStringArray(["not a save (expected a dictionary)"])
	var format: Variant = SaveData._whole(save.get("format"))
	if format == null:
		out.append("no format number")
	elif format > SaveData.FORMAT:
		out.append("format %d is newer than this game's (%d)" % [format, SaveData.FORMAT])
	elif format < SaveData.FORMAT:
		out.append("format %d is older than this game's (%d), and no older format is migrated" % [format, SaveData.FORMAT])
	var header: Variant = save.get("level")
	if typeof(header) != TYPE_DICTIONARY:
		out.append("no level header")
	elif level_data == null:
		out.append("no level loaded to put the save in")
	else:
		if str(header.get("id", "")) != level_data.level_id:
			out.append("saved for level '%s', not '%s'" % [header.get("id", ""), level_data.level_id])
		var version: Variant = SaveData._whole(header.get("version"))
		if version == null:
			out.append("no level version (a whole number)")
		elif version > level_data.level_version:
			out.append("saved by a newer version of level '%s' (%d), which is at version %d in this game"
					% [level_data.level_id, version, level_data.level_version])
	var sim: Variant = save.get("sim", {})
	if typeof(sim) != TYPE_DICTIONARY:
		out.append("'sim' must be a dictionary")
	else:
		for key in ["seed", "rng_state"]:
			if sim.has(key) and not str(sim[key]).is_valid_int():
				out.append("'sim.%s' must be a whole number as a string" % key)
		for key in ["tick", "next_slime_id"]:
			if sim.has(key) and (SaveData._whole(sim[key]) == null or SaveData._whole(sim[key]) < 0):
				out.append("'sim.%s' must be a whole number >= 0" % key)
	var slimes: Variant = save.get("slimes")
	if typeof(slimes) != TYPE_ARRAY or slimes.is_empty():
		out.append("no slimes (a level always has at least its first slime)")
	else:
		out.append_array(_slime_problems(slimes))
	# Stable ID -> state.
	out.append_array(_needed(save, "", {"objects": Kind.DICT, "gates": Kind.DICT}))
	if level_data != null and save.get("objects") is Dictionary and save.get("gates") is Dictionary:
		out.append_array(_frontier_problems(save["objects"], save["gates"], level_data))
	for key in ["train", "call", "transient", "offscreen", "stuck_slimes"]:
		var part: Variant = save.get(key)
		if part != null and typeof(part) != TYPE_DICTIONARY:
			out.append("'%s' must be a dictionary or null" % key)
	if save.get("train") is Dictionary:
		out.append_array(_train_problems(save["train"]))
	if save.get("call") is Dictionary:
		out.append_array(_needed(save["call"], "call.", {"point": Kind.VECTOR, "tick": Kind.WHOLE}))
	if save.get("offscreen") is Dictionary:
		out.append_array(_offscreen_problems(save["offscreen"]))
	if save.get("stuck_slimes") is Dictionary:
		out.append_array(_stuck_problems(save["stuck_slimes"]))
	if save.get("transient") is Dictionary:
		out.append_array(_transient_problems(save["transient"]))
	if save.has("hint_done") and typeof(save["hint_done"]) != TYPE_BOOL:
		out.append("'hint_done' must be true or false")
	if save.has("celebration_done") and typeof(save["celebration_done"]) != TYPE_BOOL:
		out.append("'celebration_done' must be true or false")
	if save.has("session"):
		out.append_array(_session_problems(save["session"]))
	return out


## What is wrong with a save's "session" (see the class doc).
# @spec-link [[req_session_lifecycle]]
static func _session_problems(session: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(session) != TYPE_DICTIONARY:
		return PackedStringArray(["'session' must be a dictionary"])
	if str(session.get("phase", "")) not in Session.PHASES:
		out.append("'session.phase' must be one of %s" % ", ".join(Session.PHASES))
	out.append_array(_needed(session, "session.", {"elapsed_ms": Kind.WHOLE, "sunrise_tick": Kind.WHOLE,
			"anchor": Kind.DICT, "clock": Kind.DICT}))
	if not out.is_empty():
		return out
	if SaveData._whole(session["elapsed_ms"]) < 0:
		out.append("'session.elapsed_ms' must be a whole number >= 0")
	var parts := {"anchor": ["wall_ms", "mono_ms", "elapsed_ms"], "clock": ["wall_ms", "mono_ms", "tick"]}
	for part in parts:
		var value: Dictionary = session[part]
		if value.is_empty():
			continue
		for key in parts[part]:
			if SaveData._whole(value.get(key)) == null:
				out.append("'session.%s.%s' must be a whole number" % [part, key])
		if part == "clock" and typeof(value.get("epoch")) != TYPE_STRING:
			out.append("'session.clock.epoch' must be a string")
	var timed := str(session["phase"]) != Session.SCREENSAVER
	if timed and out.is_empty() and (session["anchor"].is_empty() != session["clock"].is_empty()):
		out.append("'session.anchor' and 'session.clock' come together")
	return out


## What is wrong with the states of `level_data`'s switches, baskets and
## gates in a save's "objects" and "gates" (FrontierSets): each a
## dictionary, each key optional (absent: the initial state's), of its kind
## when there, a basket's phase one of FrontierSets.PHASES. The states of
## stable IDs the level doesn't have are not read (a migration drops them).
# @spec-link [[req_interactive_objects_general]]
static func _frontier_problems(objects: Dictionary, gates: Dictionary, level_data: LevelData) -> PackedStringArray:
	var out := PackedStringArray()
	var groups := [[objects, "objects", level_data.switches, {"flipped": Kind.FLAG, "trapdoor_shut": Kind.FLAG}],
			[objects, "objects", level_data.baskets, {"phase": Kind.TEXT, "weight": Kind.WHOLE, "since": Kind.WHOLE,
					"next_release": Kind.WHOLE}],
			[gates, "gates", level_data.gates, {"open": Kind.FLAG, "entrance_closed": Kind.FLAG}]]
	for group in groups:
		var states: Dictionary = group[0]
		for id in group[2]:
			if not states.has(id):
				continue
			var at := "%s.%s" % [group[1], id]
			if typeof(states[id]) != TYPE_DICTIONARY:
				out.append("'%s' must be a dictionary" % at)
				continue
			var state: Dictionary = states[id]
			out.append_array(_needed(state, at + ".", group[3], true))
			if state.get("phase") is String and state["phase"] not in FrontierSets.PHASES:
				out.append("'%s.phase' must be one of %s" % [at, ", ".join(FrontierSets.PHASES)])
	return out


## What is wrong with a save's top-level "train": its open gates (names)
## needed, its stalled log optional, each entry {"id", "tick", "reason"}.
static func _train_problems(train: Dictionary) -> PackedStringArray:
	var out := _needed(train, "train.", {"open_gates": Kind.LIST})
	out.append_array(_needed(train, "train.", {"stalled": Kind.LIST}, true))
	if train.get("open_gates") is Array:
		var gates: Array = train["open_gates"]
		for k in gates.size():
			if typeof(gates[k]) != TYPE_STRING:
				out.append("'train.open_gates[%d]' must be a string" % k)
	if train.get("stalled") is Array:
		out.append_array(_entry_problems(train["stalled"], "train.stalled",
				{"id": Kind.WHOLE, "tick": Kind.WHOLE, "reason": Kind.TEXT}))
	return out


## What is wrong with a save's "stuck_slimes" (StuckSlimes.dump): its counts
## [lower id, higher id, checks] and its log's entries.
static func _stuck_problems(stuck: Dictionary) -> PackedStringArray:
	var out := _needed(stuck, "stuck_slimes.", {"counts": Kind.LIST, "stuck": Kind.LIST})
	if stuck.get("counts") is Array:
		out.append_array(_tuple_problems(stuck["counts"], "stuck_slimes.counts", 3))
	if stuck.get("stuck") is Array:
		out.append_array(_entry_problems(stuck["stuck"], "stuck_slimes.stuck", {"id": Kind.WHOLE,
				"other": Kind.WHOLE, "tick": Kind.WHOLE, "reason": Kind.TEXT, "moved": Kind.FLAG}))
	return out


## What is wrong with a save's "offscreen" (see the file doc).
# @spec-link [[req_offscreen_simulation]]
static func _offscreen_problems(offscreen: Dictionary) -> PackedStringArray:
	var out := _needed(offscreen, "offscreen.", {"zoomed_out": Kind.FLAG, "away": Kind.LIST,
			"proxies": Kind.LIST, "lost": Kind.LIST})
	if offscreen.has("crowd_level"):
		var crowd: Variant = SaveData._whole(offscreen["crowd_level"])
		if crowd == null or crowd < 0 or crowd > Offscreen.CROWD_STEPS.size():
			out.append("'offscreen.crowd_level' must be a whole number from 0 to %d" % Offscreen.CROWD_STEPS.size())
	var entries := {"away": {"id": Kind.WHOLE, "since": Kind.WHOLE},
			"proxies": {"id": Kind.WHOLE, "route": Kind.TEXT, "along": Kind.REAL, "from": Kind.VECTOR,
					"to": Kind.VECTOR},
			"lost": {"id": Kind.WHOLE, "tick": Kind.WHOLE, "reason": Kind.TEXT}}
	for part in entries:
		if offscreen.get(part) is Array:
			out.append_array(_entry_problems(offscreen[part], "offscreen.%s" % part, entries[part]))
	return out


## What is wrong with a save's "transient" (see the file doc): every part
## capture() writes and their entries' keys; optional, "frontier.celebration_hops"
## and an input event's "finger", "at" (or null), "degrees" and "flat", which
## only some kinds of event have.
static func _transient_problems(transient: Dictionary) -> PackedStringArray:
	var out := _needed(transient, "transient.", {"view": Kind.DICT, "camera": Kind.DICT, "ripples": Kind.LIST,
			"taps": Kind.LIST, "facing": Kind.LIST, "input_log": Kind.LIST, "fusion": Kind.LIST,
			"tilt": Kind.DICT, "hint": Kind.DICT, "frontier": Kind.DICT})
	var parts := {"view": {"centre": Kind.VECTOR, "zoom": Kind.REAL, "screen_size": Kind.VECTOR},
			"tilt": {"degrees": Kind.REAL, "neutral": Kind.REAL, "flat": Kind.FLAG},
			"hint": {"since": Kind.WHOLE, "bedtime": Kind.FLAG},
			"frontier": {"celebration_since": Kind.WHOLE}}
	parts["camera"] = CAMERA_KEYS
	for part in parts:
		if transient.get(part) is Dictionary:
			out.append_array(_needed(transient[part], "transient.%s." % part, parts[part]))
	var frontier: Variant = transient.get("frontier")
	if frontier is Dictionary:
		out.append_array(_needed(frontier, "transient.frontier.", {"celebration_hops": Kind.LIST}, true))
		if frontier.get("celebration_hops") is Array:
			out.append_array(_tuple_problems(frontier["celebration_hops"], "transient.frontier.celebration_hops", 2))
	if transient.get("fusion") is Array:
		out.append_array(_tuple_problems(transient["fusion"], "transient.fusion", 3))
	var entries := {"ripples": {"at": Kind.VECTOR, "tick": Kind.WHOLE},
			"taps": {"tick": Kind.WHOLE, "finger": Kind.WHOLE, "screen": Kind.VECTOR, "world": Kind.VECTOR,
					"zone": Kind.TEXT, "side": Kind.WHOLE, "object": Kind.TEXT, "kind": Kind.TEXT,
					"call": Kind.FLAG, "answered": Kind.LIST},
			"facing": {"id": Kind.WHOLE, "facing": Kind.VECTOR},
			"input_log": {"kind": Kind.TEXT, "tick": Kind.WHOLE}}
	for part in entries:
		if transient.get(part) is Array:
			out.append_array(_entry_problems(transient[part], "transient.%s" % part, entries[part]))
	if transient.get("taps") is Array:
		out.append_array(_answered_problems(transient["taps"]))
	if transient.get("input_log") is Array:
		out.append_array(_input_log_problems(transient["input_log"]))
	return out


## The problems of the taps' "answered" lists: whole numbers (slime ids).
static func _answered_problems(taps: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for k in taps.size():
		var answered: Variant = taps[k].get("answered") if taps[k] is Dictionary else null
		if answered is Array and answered.any(func(slime_id: Variant) -> bool: return SaveData._whole(slime_id) == null):
			out.append("'transient.taps[%d].answered' must hold whole numbers" % k)
	return out


## The problems of the input events' optional keys: "finger", "degrees" and
## "flat" of their kind when there, "at" [x, y] or null.
static func _input_log_problems(log: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for k in log.size():
		if not log[k] is Dictionary:
			continue
		var event: Dictionary = log[k]
		var at := "transient.input_log[%d]." % k
		out.append_array(_needed(event, at, {"finger": Kind.WHOLE, "degrees": Kind.REAL, "flat": Kind.FLAG}, true))
		if event.has("at") and event["at"] != null and not _is_vector(event["at"]):
			out.append("'%sat' must be [x, y] or null" % at)
	return out


## The problems of a list's entries: each a list of `length` whole numbers.
static func _tuple_problems(list: Array, at: String, length: int) -> PackedStringArray:
	var out := PackedStringArray()
	for k in list.size():
		var entry: Variant = list[k]
		var good: bool = typeof(entry) == TYPE_ARRAY and entry.size() == length
		if good:
			for value in entry:
				good = good and SaveData._whole(value) != null
		if not good:
			out.append("'%s[%d]' must be a list of %d whole numbers" % [at, k, length])
	return out


## The problems of a list's entries: each a dictionary with `keys`.
static func _entry_problems(list: Array, at: String, keys: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in list.size():
		var entry: Variant = list[k]
		if typeof(entry) != TYPE_DICTIONARY:
			out.append("'%s[%d]' must be a dictionary" % [at, k])
		else:
			out.append_array(_needed(entry, "%s[%d]." % [at, k], keys))
	return out


## The problems of `holder`'s `keys` (key -> Kind): each must be there (or,
## when `optional`, may be left out), of its kind. A problem names the key
## as `at` + key.
static func _needed(holder: Dictionary, at: String, keys: Dictionary, optional := false) -> PackedStringArray:
	var out := PackedStringArray()
	for key in keys:
		if not holder.has(key):
			if not optional:
				out.append("'%s%s' is missing" % [at, key])
		elif not _is_kind(holder[key], keys[key]):
			out.append("'%s%s' must be %s" % [at, key, KIND_NAMES[keys[key]]])
	return out


## Whether `value` is of `kind` (whole numbers may be whole floats, as JSON
## reads them).
static func _is_kind(value: Variant, kind: Kind) -> bool:
	match kind:
		Kind.WHOLE:
			return SaveData._whole(value) != null
		Kind.REAL:
			return _is_real(value)
		Kind.VECTOR:
			return _is_vector(value)
		Kind.TEXT:
			return typeof(value) == TYPE_STRING
		Kind.FLAG:
			return typeof(value) == TYPE_BOOL
		Kind.DICT:
			return typeof(value) == TYPE_DICTIONARY
		Kind.WHOLE_TEXT:
			return typeof(value) == TYPE_STRING and value.is_valid_int()
		_:
			return typeof(value) == TYPE_ARRAY


## What is wrong with a save's slimes: each one's species, size, state,
## centre, optional velocity, members and runtime id, its free record, its
## train record and its body (points for its size and detail, its keys, its
## rest).
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
		var size: Variant = SaveData._whole(slime.get("size"))
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
			var runtime: Variant = SaveData._whole(slime["runtime_id"])
			if runtime == null or runtime <= last_id:
				out.append(at + "runtime ids must be whole numbers, ascending, without repeats")
			else:
				last_id = runtime
		var free: Variant = slime.get("free")
		if free != null and (typeof(free) != TYPE_DICTIONARY or str(free.get("phase", "")) not in PHASES):
			out.append(at + "'free' needs a phase: %s" % ", ".join(PHASES))
		elif free != null:
			out.append_array(_prefixed(at, _needed(free, "free.", {"since": Kind.WHOLE, "point": Kind.VECTOR,
					"route": Kind.TEXT})))
			out.append_array(_prefixed(at, _needed(free, "free.", {"rng_state": Kind.WHOLE_TEXT}, true)))
		var train: Variant = slime.get("train")
		if train != null and typeof(train) != TYPE_DICTIONARY:
			out.append(at + "'train' must be a dictionary")
		var body: Variant = slime.get("body")
		if body != null and size != null and size >= 1 and size <= SlimeBodies.MAX_SIZE:
			var level: Variant = SaveData._detail_level(body) if typeof(body) == TYPE_DICTIONARY else 0
			if level == null:
				out.append(at + "'body.detail' must be a whole number from 0 to %d" % SlimeBodies.MAX_DETAIL)
				continue
			var n := SlimeBodies.detail_points_for(size, level)
			if (typeof(body) != TYPE_DICTIONARY or SaveData.unpack_vectors(str(body.get("points", ""))).size() != n
					or SaveData.unpack_vectors(str(body.get("previous", ""))).size() != n):
				out.append(at + "'body' must hold %d points and previous points" % n)
				continue
			out.append_array(_prefixed(at, _needed(body, "body.", {"centre": Kind.VECTOR, "hop_timer": Kind.REAL,
					"heading": Kind.REAL, "held": Kind.FLAG, "supported": Kind.FLAG,
					"rng_state": Kind.WHOLE_TEXT})))
			if body.has("rest") and (typeof(body["rest"]) != TYPE_DICTIONARY
					or str(body["rest"].get("calm", "")) not in SlimeBodies.CALM_NAMES
					or not _is_vector(body["rest"].get("anchor"))):
				out.append(at + "'body.rest' needs a calm (%s) and an anchor [x, y]"
						% ", ".join(SlimeBodies.CALM_NAMES))
			elif body.has("rest"):
				out.append_array(_prefixed(at, _needed(body["rest"], "body.rest.", {"still": Kind.WHOLE,
						"pile": Kind.WHOLE})))
	if with_ids != 0 and with_ids != slimes.size():
		out.append("either every slime has a runtime_id or none does")
	return out


## `problems`, each with `at` in front.
static func _prefixed(at: String, problems: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for problem in problems:
		out.append(at + problem)
	return out


## A real as exact() writes it: a number, or "f64:" and 16 hex digits.
static func _is_real(value: Variant) -> bool:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return true
	return (typeof(value) == TYPE_STRING and value.begins_with(SaveData.EXACT_PREFIX)
			and value.length() == SaveData.EXACT_PREFIX.length() + 16
			and value.substr(SaveData.EXACT_PREFIX.length()).is_valid_hex_number())


## Whether `value` is [x, y] as vector() writes it (numbers or exact reals).
static func _is_vector(value: Variant) -> bool:
	return (typeof(value) == TYPE_ARRAY and value.size() == 2
			and typeof(value[0]) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]
			and typeof(value[1]) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING])

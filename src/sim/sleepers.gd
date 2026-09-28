class_name Sleepers
extends RefCounted
## Sleepers (master spec §5.2, D13, D70): the level's placed sleeping slimes,
## their waking, and their tap targets. Stateless: a sleeper is a slime body
## in the SLEEPER state (SlimeBodies), named by its stable ID
## (SlimeIdentities); Simulation calls these at load, after the bodies tick,
## and on a tap.
##
## - Placing: a fresh game (Simulation.load_level) creates every sleeper of
##   the level, size 1, asleep, at its marker, in stable ID order, after the
##   first slime. A save brings its own sleepers.
## - Asleep: a sleeper doesn't simulate (SlimeBodies skips it: it never
##   hops, falls or moves) but other slimes touch it, rest on it and bump
##   into it, as against a wall.
## - Waking: a sleeper wakes when a free slime touches it, both on screen (a
##   slime is on screen when any of its ring shows). Train slimes never wake
##   it, nor does anything off screen. The woken slime is free, unsure where
##   it woke (FreeSlimes.UNSURE, point: its centre), then heads back and
##   rejoins the train like any free slime. A woken slime is free itself, so
##   it can wake a sleeper it touches on a later tick; within one tick only
##   the slimes free at its start wake others.
## - Tapping: a tap on a sleeper is a call centred on its body (TapDispatcher);
##   the tap box follows the body, and a woken sleeper is no longer one.
# @spec-link [[req_waking_sleepers]]
# @spec-link [[req_slime_states]]


## Creates the level's sleepers in `sim` (a fresh game): stable ID order,
## size 1, asleep, centred on their markers, each named by its stable ID.
static func place(sim: Simulation, data: LevelData) -> void:
	var ids := data.sleepers.keys()
	ids.sort()
	for id in ids:
		var sleeper: Dictionary = data.sleepers[id]
		var slime := sim.slimes.create(Species.from_letter(sleeper["species"]), 1, sleeper["position"],
				SlimeBodies.SLEEPER)
		if slime >= 0:
			sim.identities.assign(slime, PackedStringArray([id]))


## Wakes every sleeper a free slime touched during the last bodies tick, both
## on screen (`sim.view`). Call right after SlimeBodies.tick().
static func wake(sim: Simulation) -> void:
	var bodies := sim.slimes
	var woken := PackedInt32Array()
	for pair in bodies.touching_pairs():
		var a: int = pair.x
		var b: int = pair.y
		var sa := bodies.state_of(a)
		var sb := bodies.state_of(b)
		var sleeper := -1
		var waker := -1
		if sa == SlimeBodies.SLEEPER and sb == SlimeBodies.FREE:
			sleeper = a
			waker = b
		elif sb == SlimeBodies.SLEEPER and sa == SlimeBodies.FREE:
			sleeper = b
			waker = a
		if sleeper < 0 or sleeper in woken:
			continue
		if _on_screen(sim, waker) and _on_screen(sim, sleeper):
			woken.append(sleeper)
	for sleeper in woken:
		bodies.set_state(sleeper, SlimeBodies.FREE)
		sim.free_slimes.restore_record(sleeper, {"phase": FreeSlimes.UNSURE, "since": sim.tick,
				"point": bodies.centre_of(sleeper), "route": ""})


## The level's tap targets with every placed sleeper's box centred on its
## body while it sleeps; a placed sleeper that is awake (or gone) is left
## out. Targets that aren't placed sleepers pass through unchanged.
static func tap_targets(sim: Simulation) -> Dictionary:
	if sim.level == null:
		return {}
	var targets: Dictionary = sim.level.tap_targets
	if sim.level.sleepers.is_empty():
		return targets
	var asleep := {}
	for slime_id in sim.slimes.ids():
		if sim.slimes.state_of(slime_id) == SlimeBodies.SLEEPER:
			var stable_id := sim.identities.stable_id_of(slime_id)
			if stable_id != "":
				asleep[stable_id] = slime_id
	var out := {}
	for id in targets:
		var target: Dictionary = targets[id]
		if target["kind"] != TapDispatcher.KIND_SLEEPER or not sim.level.sleepers.has(id):
			out[id] = target
		elif asleep.has(id):
			var box: Rect2 = target["box"]
			var centre := sim.slimes.centre_of(asleep[id])
			out[id] = {"kind": target["kind"], "box": Rect2(centre - box.size * 0.5, box.size)}
	return out


## Whether any of slime `slime_id`'s ring shows in `sim.view`.
static func _on_screen(sim: Simulation, slime_id: int) -> bool:
	var view := sim.view
	var size := view.screen_size / view.zoom
	var shown := Rect2(view.centre - size * 0.5, size).grow(sim.slimes.radius_of(slime_id))
	return shown.has_point(sim.slimes.centre_of(slime_id))

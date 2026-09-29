class_name Simulation
extends RefCounted
## The simulation core: the whole game state, advanced one fixed tick at a
## time. It has no scene dependencies. The scene layer (src/main.gd) turns
## frame time into ticks with FixedStep and calls step() once per tick, so
## the result depends on elapsed time and input only, never on frame rate.
##
## Input (touches and tilt, real or injected by test mode) is queued with
## push_input() and consumed at the start of the next step(). An event pushed
## while `tick` is T is stamped with T.
##
## For now the state is the tick counter, the master Rng, the level played
## (its ID and version), the slimes' soft bodies (SlimeBodies), the train
## (each train slime's progress along the loop), the free slimes and the last
## call (FreeSlimes), the view (ScreenView), the ripples, the recent taps, the
## slimes' facings and a record of the input received. Later chunks fill it
## in; each piece of state they add must appear in dump().
##
## Taps (master spec §5.5). A tap is dispatched when its finger touches down
## (TapDispatcher, with the current `view`): the parent zone, an edge button,
## an object or open ground. Every accepted tap leaves a ripple where it
## touched, turns the awake slimes within the call radius toward it, and is
## recorded in `taps`; open ground and a sleeper also call (FreeSlimes.answer_call).
## The first touch wins (D66, O67's proposed default): a touch that starts
## while any finger is down is ignored entirely (no ripple, no call) until it
## lifts, even if the finger that was first lifts before it. `fingers_down`
## still records every finger. One exception, a resting thumb (D110, to
## check in a playtest): a finger that pressed an edge strip and has been
## down RESTING_THUMB_TICKS (5 s) keeps holding the strip but no longer
## counts as down for that rule (`edge_holds`).
##
## load_level() hands the simulation its level: it builds the train and the
## split zones and, in a fresh state, wakes the first slime (a base slime of
## the level's first slime species, on the train, at its marker) and puts
## every sleeper to sleep at its marker (Sleepers). No call from the player
## is needed.
##
## Sleepers (chunk 9): they don't simulate; a free slime touching one, both
## on screen, wakes it (Sleepers.wake, right after the bodies tick); a tap on
## one is a call centred on its body. The first-play hint (`hint`) shows next
## to the first sleeper 10 s after the world shows, until the first call.
##
## Tilt (Tilt, `phone_tilt`): the tilt event feeds it, a session's start
## (or its resuming) takes its neutral (Session), and before the bodies tick
## its way down goes to the slime bodies, where only free slimes feel it.
##
## Sessions (chunk 17, Session): right after the input, the session counts
## the clock reading the scene layer fed it (session.read_clock()) and moves
## through screensaver mode, session, wind-down, bedtime and sunrise. The
## simulation never reads a clock itself.
##
## Saves (chunk 8): to_save() captures the whole state as plain JSON data and
## from_save() rebuilds it (SaveData has the format). A reloaded save has the
## saved state hash and carries on tick for tick. `identities` says which
## placed slimes each slime is made of (SlimeIdentities, D72): the stable
## part of a save. `object_states` and `gate_states` hold the interactive
## objects' and gates' state by stable ID (chunk 14; empty until then).
##
## Tick order: queued input (taps dispatched, calls answered, tilt read); the
## session advances (clocks, phases, bedtime and sunrise); the slimes far
## from the view park and move at their off-screen pace, the near ones
## simulate again (Offscreen); the train steers (aims the coming hops, carries the slimes on a slide); the free
## slimes steer; the slime bodies (free slimes fall the way the tilt says;
## hops, then the solver); the free slimes'
## hops are paced and every hop turns its slime; the split zones split (train
## and free slimes inherit); slimes in contact fuse or bump, and train slimes
## gather at dip bottoms (Fusion); the free slimes change phase or rejoin the
## train; the train follows (progress; stalled slimes go to the start of the
## loop); every CHECK_TICKS, slimes stuck inside each other are pulled apart
## (StuckSlimes); the camera watches (idle clock, cue, the slime it follows,
## no one at bedtime), is shown the gates a basket fired open this tick, and
## moves (Camera: rails, edge buttons, call drag, framing zones, idle camera,
## a gate's show); spent ripples go.

## Simulation ticks per second. Tuning durations (3 s of contact to fuse, 10 s
## before left alone, and so on) are counted in ticks at this rate.
const TICK_RATE := 60
const TICK_SECONDS := 1.0 / TICK_RATE

## How many consumed input events the input log keeps.
const INPUT_LOG_SIZE := 64

const INPUT_TOUCH_DOWN := "touch_down"
const INPUT_TOUCH_UP := "touch_up"
const INPUT_TILT := "tilt"

## How long a tap's ripple lasts, ticks (0.6 s).
const RIPPLE_TICKS := 36
## How many dispatched taps `taps` keeps.
const TAP_LOG_SIZE := 16
## How long a finger pressing an edge strip stays down before it rests: it
## keeps holding the strip but stops blocking other touches, ticks (5 s,
## D110; to check in a playtest).
const RESTING_THUMB_TICKS := 5 * TICK_RATE

## Ticks run since the simulation started.
var tick := 0
## The master random generator. All gameplay randomness comes from it or from
## streams derived from it (Rng.derive).
var rng: Rng
## The level played, as plain data (loop, routes back, split zones), or null.
## Set by load_level(), which the game root calls once the level has loaded. Its geometry is static; only its
## ID and version go into dump().
var level: LevelData = null
## The slimes' soft bodies. Their per-slime random streams derive from `rng`.
## The game root gives them the level's terrain (TerrainSegments).
# @spec-link [[req_slime_states]]
var slimes: SlimeBodies
## The train: every train slime's progress along the loop. Null without a
## level.
var train: Train = null
## The level's split zones at work.
var split_zones := SplitZones.new()
## The phone's tilt: the last reading, its neutral, and the way down it gives
## free slimes.
# @spec-link [[req_tilt_input]]
var phone_tilt := Tilt.new()
## The last tilt reading, degrees (phone_tilt.degrees).
var tilt_degrees: float:
	get:
		return phone_tilt.degrees
## Every finger down, accepted or ignored: finger index -> screen position.
var fingers_down: Dictionary = {}
## The finger whose touch counts (the first touch wins), or -1.
# @spec-link [[req_controls_tap_zones]]
var active_finger := -1
## The fingers down whose tap was an edge-strip press: finger index -> the
## tick it touched down. After RESTING_THUMB_TICKS such a finger rests.
# @spec-link [[req_controls_tap_zones]]
var edge_holds: Dictionary = {}
## The last INPUT_LOG_SIZE input events consumed, each stamped with its "tick".
var input_log: Array[Dictionary] = []
## What the player sees: the scene layer copies its camera here before every
## tick; tests set it. Taps are dispatched through it.
var view := ScreenView.new()
## The camera: on the loop's rails, moved by the edge buttons, pulled by a
## call (Camera). The scene layer makes `view` and its Camera2D show it.
# @spec-link [[req_camera_rails_and_framing]]
var camera := Camera.new()
## Screensaver mode: the camera starts on the idle camera (Camera.watch()).
## False in the core, as in a session. With sessions on (Session.enabled) or
## a session running, the session sets it every tick; otherwise tests set it.
## A mode, like input: not in dump() nor saves (the camera's dump has what
## it did, the session's its phase).
# @spec-link [[req_idle_camera_and_screensaver_zoom]]
var screensaver := false
## The free slimes and the last call.
# @spec-link [[req_call_mechanic]]
var free_slimes: FreeSlimes
## The ripples still showing, oldest first: {"at" (level pixels), "tick"}.
# @spec-link [[req_controls_tap_zones]]
var ripples: Array[Dictionary] = []
## The last TAP_LOG_SIZE accepted taps, oldest first: {"tick", "finger",
## "screen", "world", "zone", "side", "object", "kind", "call", "answered"}.
var taps: Array[Dictionary] = []
## The way each slime looks: slime id -> unit vector. Set toward a tap for the
## awake slimes in range, and along every hop. Slimes without one look right.
var facing: Dictionary = {}
## Which placed base slimes each slime is made of (stable IDs, for saves).
# @spec-link [[req_persistence_and_saves]]
var identities := SlimeIdentities.new()
## The contact counts: which touching slimes fuse or bump, and when (Fusion).
# @spec-link [[rule_fusion_contact_time]]
var fusion := Fusion.new()
## The interactive objects' state by stable ID, as plain data (chunk 14).
# @spec-link [[req_interactive_objects_general]]
var object_states: Dictionary = {}
## The gates' state by stable ID, as plain data (chunk 14).
var gate_states: Dictionary = {}
## The frontier sets: switches, baskets, gates and the level's one-time
## celebration, on object_states and gate_states (FrontierSets; chunk 14).
# @spec-link [[req_switch_basket_gate_set]]
var frontier := FrontierSets.new()
## The first-play hint: due until the first call; shows 10 s after the world
## shows (Hint). The game calls hint.world_shown() when it shows the world.
# @spec-link [[req_first_play_hint]]
var hint := Hint.new()
## Screensaver mode, the session, wind-down, bedtime and sunrise, on the
## clock readings the scene layer feeds it (Session; chunk 17).
# @spec-link [[req_session_lifecycle]]
var session := Session.new()
## Physics only on or near the screen: parked slimes, their off-screen
## pace, left-alone and lost free slimes, the zoomed-out detail (Offscreen;
## chunk 15). Its `enabled` is a mode, set by the game.
# @spec-link [[req_offscreen_simulation]]
var offscreen := Offscreen.new()
## The stuck safety net: pairs of slimes that can't fuse lodged inside each
## other, counted every 0.5 s; the smaller one goes to the start of the loop
## (StuckSlimes; chunk 23A). Its counts and log are in dump() and saves.
# @spec-link [[rule_stuck_slimes_moved_to_start]]
var stuck_slimes := StuckSlimes.new()

var _pending_input: Array[Dictionary] = []


func _init(master_seed: int) -> void:
	rng = Rng.new(master_seed)
	slimes = SlimeBodies.new(rng)
	free_slimes = FreeSlimes.new(rng)


## A finger touching the screen at `at` (screen pixels). `finger` 0 is the
## first finger, 1 the second, and so on.
static func touch_down(finger: int, at: Vector2) -> Dictionary:
	return {"kind": INPUT_TOUCH_DOWN, "finger": finger, "at": at}


## A finger leaving the screen. `at` may be null: the finger lifts where it was.
static func touch_up(finger: int, at: Variant) -> Dictionary:
	return {"kind": INPUT_TOUCH_UP, "finger": finger, "at": at}


## The phone's tilt: a raw reading in degrees, positive when down turns toward
## screen-right, and whether the phone lies flat (see Tilt).
static func tilt(degrees: float, flat := false) -> Dictionary:
	return {"kind": INPUT_TILT, "degrees": degrees, "flat": flat}


## Queues an input event (from touch_down, touch_up or tilt) for the next step.
func push_input(event: Dictionary) -> void:
	var kind: String = event.get("kind", "")
	if kind not in [INPUT_TOUCH_DOWN, INPUT_TOUCH_UP, INPUT_TILT]:
		push_error("Simulation: unknown input kind '%s'" % kind)
		return
	_pending_input.append(event.duplicate())


## Hands the simulation its level (plain data): builds the train on the
## level's loop, bounded by the terrain (so set slimes.terrain first), and the
## split zones. In a fresh state (tick 0, no slimes) the game wakes the first
## slime: a base slime of the first slime's species, on the train, at its
## marker, and puts every sleeper to sleep at its marker (Sleepers.place).
## The hint takes its place and starts counting.
# @spec-link [[req_slime_states]]
# @spec-link [[req_loop_and_world]]
# @spec-link [[req_waking_sleepers]]
func load_level(data: LevelData) -> void:
	level = data
	train = null
	split_zones = SplitZones.new()
	if data == null:
		return
	if data.loop != null:
		train = Train.new(data.loop)
		train.bounds = Train.bounds_for(slimes.terrain, data.loop)
	split_zones = SplitZones.new(data.split_zones)
	camera.zones = data.framing_zones
	camera.start(data.loop, train.open_gates if train != null else [], data.first_slime.get("position"))
	var fresh := tick == 0 and slimes.slime_count == 0
	if fresh and not data.first_slime.is_empty():
		var at: Vector2 = data.first_slime["position"]
		var first := slimes.create(Species.from_letter(data.first_slime["species"]), 1, at, SlimeBodies.TRAIN)
		if str(data.first_slime.get("id", "")) != "":
			identities.assign(first, PackedStringArray([data.first_slime["id"]]))
		if train != null:
			train.track(first, data.loop.closest(at, train.open_gates)["distance"])
	if fresh:
		Sleepers.place(self, data)
	hint.place(data)
	hint.world_shown(tick)
	frontier.start(self)


## Puts a train slime of `slime_species` and `slime_size` on the loop,
## `distance` px along it, resting its centre above the route (which runs at
## a base slime's centre height). For tests and the debug tools. Returns its
## id, or -1 without a train.
func spawn_train_slime(slime_species: int, slime_size: int, distance: float) -> int:
	if train == null:
		return -1
	var lift := SlimeBodies.ring_radius_for(slime_size) - SlimeBodies.ring_radius_for(1)
	var at := train.position_at(distance) + Vector2(0.0, -lift)
	var slime := slimes.create(slime_species, slime_size, at, SlimeBodies.TRAIN)
	if slime >= 0:
		train.track(slime, distance)
	return slime


## Advances the simulation by one tick.
# @spec-link [[req_hopping_behavior]]
# @spec-link [[req_camera_shows_gate_opening]]
func step() -> void:
	for event in _pending_input:
		_apply_input(event)
	_pending_input.clear()
	session.advance(self)
	offscreen.step(self)
	var gates: Array = train.open_gates if train != null else []
	if train != null:
		train.steer(slimes, TICK_SECONDS)
	free_slimes.steer(slimes, TICK_SECONDS, level, gates)
	slimes.free_down = phone_tilt.down()
	slimes.tick(TICK_SECONDS)
	Sleepers.wake(self)
	free_slimes.paced(slimes)
	_face_hops()
	for parts in split_zones.apply(slimes):
		identities.split(parts)
		if train != null:
			train.inherit(parts)
		free_slimes.inherit(parts, tick)
	fusion.step(self)
	frontier.step(self)
	gates = train.open_gates if train != null else []
	free_slimes.follow(slimes, tick, level, gates)
	if train != null:
		train.follow(slimes, tick)
	stuck_slimes.step(self)
	camera.watch(slimes, not fingers_down.is_empty(), screensaver, session.phase == Session.BEDTIME)
	for gate_id in frontier.gates_fired_open(self):
		camera.show_gate(level.gates[gate_id]["box"], view, level.loop, gates, tick)
	camera.step(level.loop if level != null else null, gates, TICK_SECONDS, tick)
	_tidy()
	tick += 1
	hint.update(tick)


## Runs `ticks` steps at once.
func run(ticks: int) -> void:
	for i in ticks:
		step()


## Fuses slimes `a` and `b` (SlimeBodies.merge) and merges their identities.
## Returns the fused slime's id (the lower), or -1 when they can't fuse. The
## hook for fusion (chunk 10).
# @spec-link [[req_persistence_and_saves]]
func fuse(a: int, b: int) -> int:
	var kept := slimes.merge(a, b)
	if kept < 0:
		return -1
	identities.merge(a, b)
	return kept


## The whole state as a save: plain JSON data (SaveData has the format).
# @spec-link [[req_persistence_and_saves]]
func to_save() -> Dictionary:
	return SaveData.capture(self)


## The simulation saved in `save`, on `level_data` with its baked `terrain`,
## or null when the save doesn't fit (SaveData.problems). `fallback_seed`
## seeds a hand-made save that has none. The fingers down are not saved: the
## reloaded simulation has none.
# @spec-link [[req_persistence_and_saves]]
static func from_save(save: Dictionary, level_data: LevelData, terrain: TerrainSegments = null,
		fallback_seed := 0) -> Simulation:
	return SaveData.restore(save, level_data, terrain, fallback_seed)


## The whole state as plain data, for StateHash and, from chunk 8, saves.
## 64-bit values (the seed, the generator state) are strings so that they
## survive a JSON round trip.
func dump() -> Dictionary:
	var fingers := {}
	for finger in fingers_down:
		fingers[str(finger)] = fingers_down[finger]
	var holds := {}
	for finger in edge_holds:
		holds[str(finger)] = edge_holds[finger]
	var facings := []
	var facing_ids := facing.keys()
	facing_ids.sort()
	for slime_id in facing_ids:
		facings.append({"id": slime_id, "facing": (facing[slime_id] as Vector2).snapped(Vector2(0.0001, 0.0001))})
	return {
		"tick": tick,
		"seed": str(rng.seed_value),
		"rng_state": str(rng.state),
		"level": level.header() if level != null else null,
		"slimes": slimes.dump(),
		"next_slime_id": slimes.next_id,
		"identities": identities.dump(),
		"objects": object_states.duplicate(true),
		"gates": gate_states.duplicate(true),
		"train": train.dump() if train != null else null,
		"free_slimes": free_slimes.dump(),
		"fusion": fusion.dump(),
		"facing": facings,
		"view": view.dump(),
		"camera": camera.dump(),
		"hint": hint.dump(),
		"frontier": frontier.dump(),
		"session": session.dump(),
		"offscreen": offscreen.dump(),
		"stuck_slimes": stuck_slimes.dump(),
		"ripples": ripples.duplicate(true),
		"taps": taps.duplicate(true),
		"input": {
			"tilt": phone_tilt.dump(),
			"fingers_down": fingers,
			"active_finger": active_finger,
			"edge_holds": holds,
			"log": input_log.duplicate(true),
		},
	}


## The hash of dump(): equal hashes, equal states.
func state_hash() -> String:
	return StateHash.of(dump())


## The call radius for the current view, level pixels.
func call_radius() -> float:
	return FreeSlimes.call_radius(view.world_width())


func _apply_input(event: Dictionary) -> void:
	match event["kind"]:
		INPUT_TOUCH_DOWN:
			var finger: int = event["finger"]
			# The first touch wins: only a touch on a screen with no finger
			# down counts, a resting thumb aside.
			var counts := _no_finger_blocks()
			fingers_down[finger] = event["at"]
			if counts:
				active_finger = finger
				camera.touched()
				_tap(finger, event["at"])
		INPUT_TOUCH_UP:
			fingers_down.erase(event["finger"])
			edge_holds.erase(event["finger"])
			camera.release(event["finger"])
			if event["finger"] == active_finger:
				active_finger = -1
		INPUT_TILT:
			phone_tilt.read(event["degrees"], event.get("flat", false))
	var logged := event.duplicate()
	logged["tick"] = tick
	input_log.append(logged)
	if input_log.size() > INPUT_LOG_SIZE:
		input_log.pop_front()


## Whether a touch starting now counts under the first-touch rule: no finger
## is down, or every finger down is a resting thumb (an edge-strip press held
## RESTING_THUMB_TICKS or longer, D110).
# @spec-link [[req_controls_tap_zones]]
func _no_finger_blocks() -> bool:
	for finger in fingers_down:
		if not edge_holds.has(finger) or tick - int(edge_holds[finger]) < RESTING_THUMB_TICKS:
			return false
	return true


## An accepted tap at screen point `at`: dispatched, answered with a ripple
## and with the slimes in range turning toward it; open ground and a sleeper
## call.
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_call_mechanic]]
# @spec-link [[req_denial_and_stepup_behavior]]
# @spec-link [[req_session_lifecycle]]
func _tap(finger: int, at: Vector2) -> void:
	# At bedtime taps only ripple: no object, no edge button (hidden), no call.
	var bedtime := session.phase == Session.BEDTIME
	var targets := {} if bedtime else Sleepers.tap_targets(self)
	var hit := TapDispatcher.dispatch(at, view, targets, camera.edge_buttons_visible)
	if bedtime:
		hit["call"] = false
	elif hit["zone"] in [TapDispatcher.ZONE_GROUND, TapDispatcher.ZONE_OBJECT] and session.can_start():
		# Only a tap that reaches the world starts a session (O69), and it
		# does its normal job too.
		session.start(self)
	if hit["zone"] == TapDispatcher.ZONE_EDGE:
		camera.press(hit["side"], finger)
		edge_holds[finger] = tick
	if hit["kind"] == TapDispatcher.KIND_SWITCH:
		frontier.tap_switch(self, hit["object"])
	var world: Vector2 = hit["world"]
	ripples.append({"at": world.snapped(Vector2(0.01, 0.01)), "tick": tick})
	var radius := call_radius()
	for slime_id in slimes.ids():
		var state := slimes.state_of(slime_id)
		if state != SlimeBodies.TRAIN and state != SlimeBodies.FREE:
			continue
		var centre := slimes.centre_of(slime_id)
		if centre.distance_to(world) <= radius and not centre.is_equal_approx(world):
			facing[slime_id] = (world - centre).normalized()
	var answered := PackedInt32Array()
	if hit["call"]:
		answered = free_slimes.answer_call(hit["call_point"], tick, slimes, radius)
		hint.called()
		camera.on_call(hit["call_point"], tick, view)
	taps.append({"tick": tick, "finger": finger, "screen": at,
			"world": world.snapped(Vector2(0.01, 0.01)), "zone": hit["zone"], "side": hit["side"],
			"object": hit["object"], "kind": hit["kind"], "call": hit["call"],
			"answered": Array(answered)})
	if taps.size() > TAP_LOG_SIZE:
		taps.pop_front()


## Every slime that hopped this tick looks the way it hopped.
func _face_hops() -> void:
	for slime_id in slimes.hopped:
		var velocity := slimes.velocity_of(slime_id)
		if absf(velocity.x) > 1.0:
			facing[slime_id] = Vector2(signf(velocity.x), 0.0)


## Drops the spent ripples and the facings of slimes that are gone.
func _tidy() -> void:
	while not ripples.is_empty() and tick - ripples[0]["tick"] >= RIPPLE_TICKS:
		ripples.pop_front()
	for slime_id in facing.keys():
		if not slimes.has(slime_id):
			facing.erase(slime_id)
	identities.tidy(slimes)

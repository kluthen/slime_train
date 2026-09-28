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
## still records every finger.
##
## load_level() hands the simulation its level: it builds the train and the
## split zones and, in a fresh state, wakes the first slime (a base slime of
## the level's first slime species, on the train, at its marker). No call
## from the player is needed.
##
## Tick order: queued input (taps dispatched, calls answered); the train
## steers (aims the coming hops, carries the slimes on a slide); the free
## slimes steer; the slime bodies (hops, then the solver); the free slimes'
## hops are paced and every hop turns its slime; the split zones split (train
## and free slimes inherit); the free slimes change phase or rejoin the
## train; the train follows (progress, lost slimes); spent ripples go.

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
## Placeholder until chunk 11: the last tilt received, in degrees.
var tilt_degrees := 0.0
## Every finger down, accepted or ignored: finger index -> screen position.
var fingers_down: Dictionary = {}
## The finger whose touch counts (the first touch wins), or -1.
# @spec-link [[req_controls_tap_zones]]
var active_finger := -1
## The last INPUT_LOG_SIZE input events consumed, each stamped with its "tick".
var input_log: Array[Dictionary] = []
## What the player sees: the scene layer copies its camera here before every
## tick; tests set it. Taps are dispatched through it.
var view := ScreenView.new()
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


## The phone's tilt, in degrees (raw; chunk 11 applies the dead zone and limits).
static func tilt(degrees: float) -> Dictionary:
	return {"kind": INPUT_TILT, "degrees": degrees}


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
## marker. Sleepers come with chunk 9.
# @spec-link [[req_slime_states]]
# @spec-link [[req_loop_and_world]]
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
	if tick == 0 and slimes.slime_count == 0 and not data.first_slime.is_empty():
		var at: Vector2 = data.first_slime["position"]
		var first := slimes.create(Species.from_letter(data.first_slime["species"]), 1, at, SlimeBodies.TRAIN)
		if train != null:
			train.track(first, data.loop.closest(at, train.open_gates)["distance"])


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
func step() -> void:
	for event in _pending_input:
		_apply_input(event)
	_pending_input.clear()
	var gates: Array = train.open_gates if train != null else []
	if train != null:
		train.steer(slimes, TICK_SECONDS)
	free_slimes.steer(slimes, TICK_SECONDS, level, gates)
	slimes.tick(TICK_SECONDS)
	free_slimes.paced(slimes)
	_face_hops()
	for parts in split_zones.apply(slimes):
		if train != null:
			train.inherit(parts)
		free_slimes.inherit(parts, tick)
	free_slimes.follow(slimes, tick, level, gates)
	if train != null:
		train.follow(slimes, tick)
	_tidy()
	tick += 1


## Runs `ticks` steps at once.
func run(ticks: int) -> void:
	for i in ticks:
		step()


## The whole state as plain data, for StateHash and, from chunk 8, saves.
## 64-bit values (the seed, the generator state) are strings so that they
## survive a JSON round trip.
func dump() -> Dictionary:
	var fingers := {}
	for finger in fingers_down:
		fingers[str(finger)] = fingers_down[finger]
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
		"train": train.dump() if train != null else null,
		"free_slimes": free_slimes.dump(),
		"facing": facings,
		"view": view.dump(),
		"ripples": ripples.duplicate(true),
		"taps": taps.duplicate(true),
		"input": {
			"tilt_degrees": tilt_degrees,
			"fingers_down": fingers,
			"active_finger": active_finger,
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
			# The first touch wins: only a touch on an empty screen counts.
			var counts := fingers_down.is_empty()
			fingers_down[finger] = event["at"]
			if counts:
				active_finger = finger
				_tap(finger, event["at"])
		INPUT_TOUCH_UP:
			fingers_down.erase(event["finger"])
			if event["finger"] == active_finger:
				active_finger = -1
		INPUT_TILT:
			tilt_degrees = event["degrees"]
	var logged := event.duplicate()
	logged["tick"] = tick
	input_log.append(logged)
	if input_log.size() > INPUT_LOG_SIZE:
		input_log.pop_front()


## An accepted tap at screen point `at`: dispatched, answered with a ripple
## and with the slimes in range turning toward it; open ground and a sleeper
## call.
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_call_mechanic]]
func _tap(finger: int, at: Vector2) -> void:
	var targets: Dictionary = level.tap_targets if level != null else {}
	var hit := TapDispatcher.dispatch(at, view, targets)
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

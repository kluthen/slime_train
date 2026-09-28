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
## For now the state is the tick counter, the master Rng, an empty slime list
## and a record of the input received. Later chunks fill it in; each piece of
## state they add must appear in dump().

## Simulation ticks per second. Tuning durations (3 s of contact to fuse, 10 s
## before left alone, and so on) are counted in ticks at this rate.
const TICK_RATE := 60
const TICK_SECONDS := 1.0 / TICK_RATE

## How many consumed input events the input log keeps.
const INPUT_LOG_SIZE := 64

const INPUT_TOUCH_DOWN := "touch_down"
const INPUT_TOUCH_UP := "touch_up"
const INPUT_TILT := "tilt"

## Ticks run since the simulation started.
var tick := 0
## The master random generator. All gameplay randomness comes from it or from
## streams derived from it (Rng.derive).
var rng: Rng
## Placeholder: the slimes. Filled from chunk 5 on.
var slimes: Array = []
## Placeholder until chunk 11: the last tilt received, in degrees.
var tilt_degrees := 0.0
## Placeholder until chunk 7: the fingers down, finger index -> screen position.
var fingers_down: Dictionary = {}
## Placeholder until chunk 7: the last INPUT_LOG_SIZE input events consumed,
## each stamped with its "tick".
var input_log: Array[Dictionary] = []

var _pending_input: Array[Dictionary] = []


func _init(master_seed: int) -> void:
	rng = Rng.new(master_seed)


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


## Advances the simulation by one tick.
func step() -> void:
	for event in _pending_input:
		_apply_input(event)
	_pending_input.clear()
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
	return {
		"tick": tick,
		"seed": str(rng.seed_value),
		"rng_state": str(rng.state),
		"slimes": slimes.duplicate(true),
		"input": {
			"tilt_degrees": tilt_degrees,
			"fingers_down": fingers,
			"log": input_log.duplicate(true),
		},
	}


## The hash of dump(): equal hashes, equal states.
func state_hash() -> String:
	return StateHash.of(dump())


func _apply_input(event: Dictionary) -> void:
	match event["kind"]:
		INPUT_TOUCH_DOWN:
			fingers_down[event["finger"]] = event["at"]
		INPUT_TOUCH_UP:
			fingers_down.erase(event["finger"])
		INPUT_TILT:
			tilt_degrees = event["degrees"]
	var logged := event.duplicate()
	logged["tick"] = tick
	input_log.append(logged)
	if input_log.size() > INPUT_LOG_SIZE:
		input_log.pop_front()

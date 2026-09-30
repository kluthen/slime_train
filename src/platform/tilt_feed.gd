class_name TiltFeed
extends RefCounted
## Feeds the phone's tilt sensor to the simulation in normal play (master
## spec §5.5): the game root calls feed() before every tick, never in test
## mode (whose script's "tilt" steps are its only tilt, so runs stay
## repeatable).
##
## A reading reaches the simulation as its tilt input (Simulation.tilt(),
## from TiltSensor.reading()), only when it changed by CHANGE_DEGREES or more,
## or went flat or back: every input is logged (Simulation.input_log, 64
## events), and a steady phone must not push the touches out of it. A new
## simulation gets the current reading on its first tick. A reading of
## exactly Vector3.ZERO (desktop, or before the phone's first sensor event)
## pushes nothing, so desktop play is as before.
##
## The reading is pushed before the tick, so a resumed session's neutral
## (taken in that tick, Session.advance) is the latest reading. A tap that
## starts a session is queued before this tick's reading: the neutral is then
## the reading pushed before, at most CHANGE_DEGREES and one tick off.
##
## Tilt is never a touch: it doesn't restart the idle clock (Camera.watch()).
# @spec-link [[req_tilt_input]]

## The smallest change of the in-plane angle worth a new input, degrees
## (proposed: well under the 10° dead zone, above most sensor noise).
const CHANGE_DEGREES := 1.0

## Where readings come from: returns a Vector3 like
## Input.get_accelerometer() (see TiltSensor). Tests put a fake first.
var sensor := Callable(Input, "get_accelerometer")

## The simulation the last reading went to (its instance ID), and that
## reading (TiltSensor.reading()).
var _fed_id := 0
var _last := {}


## Reads the sensor and, when the reading is new for `sim` (another
## simulation, a change of CHANGE_DEGREES or more, or flat or not), pushes it
## as a tilt input for the next tick. Returns whether it pushed.
func feed(sim: Simulation) -> bool:
	var gravity: Vector3 = sensor.call()
	if gravity == Vector3.ZERO:
		return false
	var now := TiltSensor.reading(gravity)
	if sim.get_instance_id() == _fed_id and not changed(_last, now):
		return false
	_fed_id = sim.get_instance_id()
	_last = now
	sim.push_input(Simulation.tilt(now["degrees"], now["flat"]))
	return true


## Whether reading `after` differs enough from `before` (TiltSensor.reading()
## dictionaries) to be pushed: flat or not changed, or the angle moved by
## CHANGE_DEGREES or more (across ±180° too).
static func changed(before: Dictionary, after: Dictionary) -> bool:
	if before.is_empty() or before["flat"] != after["flat"]:
		return true
	return absf(wrapf(after["degrees"] - before["degrees"], -180.0, 180.0)) >= CHANGE_DEGREES

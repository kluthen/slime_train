class_name TiltSensor
extends RefCounted
## Turns the phone's accelerometer into a tilt reading for Tilt (master spec
## §5.5): the angle of gravity in the screen's plane, and whether the phone
## lies flat. Pure: static functions on a Vector3, no engine state.
##
## The input is Godot's Input.get_accelerometer(), in m/s². On Android, Godot
## (4.7.2, GodotInputHandler.onSensorChanged) rotates the sensor's axes to the
## display's rotation, then hands GodotLib.accelerometer(-x, -y, -z): the
## Android reading negated. So the vector is in **screen axes** (x toward the
## screen's right, y toward its top, z out of the screen) and at rest it
## points **down, along gravity** (about 9.81 long): a phone held upright in
## landscape reads (0, -9.81, 0), one lying flat screen up (0, 0, -9.81). On
## desktop (and before the phone's first sensor event) it is Vector3.ZERO.
##
## The angle is how far gravity turns from the screen's down around the
## screen's normal, **positive toward screen-right**: the phone's right edge
## dips (Tilt's sign). The phone is flat when gravity has too small a part in
## the screen's plane for that angle to mean anything: the screen within
## FLAT_DEGREES of horizontal (face up or face down), or no gravity to speak
## of (no sensor, free fall).
# @spec-link [[req_tilt_input]]

## The screen within this many degrees of horizontal counts as flat (the
## in-plane part of gravity under sin(FLAT_DEGREES) of the whole; proposed,
## the spec gives no value).
const FLAT_DEGREES := 20.0
## A reading shorter than this, m/s², says nothing about the way down (no
## sensor, or free fall): flat (proposed).
const MIN_MAGNITUDE := 1.0


## The reading for `gravity` (Input.get_accelerometer()): {"degrees": the
## in-plane angle (0 when flat), "flat": whether the phone lies flat}, the
## arguments of Simulation.tilt().
static func reading(gravity: Vector3) -> Dictionary:
	if is_flat(gravity):
		return {"degrees": 0.0, "flat": true}
	return {"degrees": degrees_of(gravity), "flat": false}


## The angle of `gravity` in the screen's plane from the screen's down,
## degrees in -180 to 180, positive when the phone's right edge dips.
## Meaningless when the phone is flat (see is_flat()).
static func degrees_of(gravity: Vector3) -> float:
	return rad_to_deg(atan2(gravity.x, -gravity.y))


## Whether the phone lies too flat for the in-plane angle to mean anything:
## gravity's part in the screen's plane is under sin(FLAT_DEGREES) of its
## length, or the reading is shorter than MIN_MAGNITUDE (Vector3.ZERO: no
## sensor).
static func is_flat(gravity: Vector3) -> bool:
	var magnitude := gravity.length()
	if magnitude < MIN_MAGNITUDE:
		return true
	var in_plane := Vector2(gravity.x, gravity.y).length()
	return in_plane < magnitude * sin(deg_to_rad(FLAT_DEGREES))

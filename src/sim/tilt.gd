class_name Tilt
extends RefCounted
## The phone's tilt, turned into the way down for free slimes (master spec
## §5.5): the world stays fixed on the screen and gravity turns with the
## phone, up to CAP_DEGREES from neutral, with a dead zone of
## DEAD_ZONE_DEGREES around neutral where it doesn't turn. Only free slimes
## feel it (SlimeBodies.gravity_for); tilt is never needed to make progress.
##
## A reading is an angle in degrees: the direction of real gravity in the
## screen's plane, measured from the screen's down. **Positive turns down
## toward screen-right**: the phone's right edge dips (it turns clockwise as
## the player looks at it, like a steering wheel turned right). A reading may
## also say the phone lies **flat**: the screen faces up, gravity has next to
## no part in its plane and the angle means nothing. Lying flat counts as
## neutral. Deciding "flat" from the sensor (a threshold on the gravity
## vector's part in the screen's plane) is the sensor's job (TiltSensor,
## chunk 20); on desktop, test mode's `tilt` step says it (`"flat": true`).
##
## Neutral is how the phone was held when the session started: take_neutral_now()
## (placeholder until sessions, chunk 17: Simulation.load_level takes it, so
## every fresh or resumed level starts neutral, as D95 proposes). A session
## started flat takes the screen's down (0°) as neutral.
##
## The dead zone and the cap apply to the reading relative to neutral. Past
## the dead zone, gravity turns continuously from 0° at the dead zone's edge
## to CAP_DEGREES at the cap (no jump at the edge), and no further.
# @spec-link [[req_tilt_input]]

## The dead zone around neutral where gravity doesn't turn, degrees
## (specs/tuning.md: about 10°).
const DEAD_ZONE_DEGREES := 10.0
## The most gravity turns from neutral, degrees (specs/tuning.md: ±45°).
const CAP_DEGREES := 45.0

## The last reading, degrees (positive: down toward screen-right).
var degrees := 0.0
## Whether the last reading was of a phone lying flat.
var flat := false
## The reading taken as neutral, degrees.
var neutral := 0.0


## A new reading from the sensor (or from test mode).
# @spec-link [[req_tilt_input]]
func read(reading_degrees: float, is_flat := false) -> void:
	degrees = reading_degrees
	flat = is_flat


## Takes `angle` (degrees) as neutral.
func set_neutral(angle: float) -> void:
	neutral = wrapf(angle, -180.0, 180.0)


## Takes the phone's current hold as neutral: the last reading, or 0° when
## the phone lies flat (or nothing was read yet).
func take_neutral_now() -> void:
	set_neutral(0.0 if flat else degrees)


## The reading relative to neutral, -180 to 180 degrees; 0 when flat.
func relative_degrees() -> float:
	if flat:
		return 0.0
	return wrapf(degrees - neutral, -180.0, 180.0)


## How far gravity turns for free slimes, degrees: 0 inside the dead zone,
## then up to ±CAP_DEGREES.
func gravity_degrees() -> float:
	return turn_for(relative_degrees())


## The unit vector free slimes fall along: exactly Vector2.DOWN inside the
## dead zone, turned toward screen-right for a positive tilt.
# @spec-link [[req_tilt_input]]
func down() -> Vector2:
	var turned := gravity_degrees()
	if turned == 0.0:
		return Vector2.DOWN
	var angle := deg_to_rad(turned)
	return Vector2(sin(angle), cos(angle))


## How far gravity turns for a reading `relative` degrees from neutral.
static func turn_for(relative: float) -> float:
	var amount := absf(relative)
	if amount <= DEAD_ZONE_DEGREES:
		return 0.0
	var past := minf(amount, CAP_DEGREES) - DEAD_ZONE_DEGREES
	return signf(relative) * past * CAP_DEGREES / (CAP_DEGREES - DEAD_ZONE_DEGREES)


## The state as plain data (Simulation.dump, saves).
func dump() -> Dictionary:
	return {"degrees": degrees, "neutral": neutral, "flat": flat}


## Sets the state back from dump().
func restore(data: Dictionary) -> void:
	degrees = float(data.get("degrees", 0.0))
	neutral = float(data.get("neutral", 0.0))
	flat = bool(data.get("flat", false))

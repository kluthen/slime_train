class_name TapFeedback
extends Node2D
## Draws what the simulation says about taps, above the slimes: every tap's
## ripple, an expanding ring where the finger touched (D65), and each slime's
## facing, a placeholder eye dot on the side it looks at (slimes in range
## turn toward a tap), for the slimes that can be seen only
## (SlimeRenderer.is_seen: not parked, on the shown part of the world). Also
## the first-play hint (Hint), while it shows: a wordless touch mark pulsing
## around the first sleeper (D65). It only reads
## the simulation. Placeholder art until the ui_ux tree settles the look.
## Place it at the world origin.
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_first_play_hint]]

const RIPPLE_COLOR := Color(1.0, 1.0, 1.0, 0.9)
## The ripple's radius at its start and end, and its line width, screen pixels.
const RIPPLE_FROM := 10.0
const RIPPLE_TO := 64.0
const RIPPLE_WIDTH := 3.0
const EYE_COLOR := Color(0.05, 0.05, 0.1)
## The eye dot's radius, and how far out from the centre it sits, as shares
## of the slime's ring radius.
const EYE_SIZE := 0.16
const EYE_OUT := 0.5
const HINT_COLOR := Color(1.0, 1.0, 1.0, 0.85)
## One pulse of the hint, seconds of simulated time (so a recorded run
## shows the same frames).
const HINT_PULSE_SECONDS := 1.2
## The hint's ring: its radius swells from HINT_FROM to HINT_TO and fades
## (screen pixels), with a steady inner ring at HINT_FROM.
const HINT_FROM := 34.0
const HINT_TO := 58.0
const HINT_WIDTH := 4.0

## The simulation drawn.
var simulation: Simulation = null


func _init() -> void:
	z_index = 10


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if simulation == null:
		return
	var zoom := simulation.view.zoom
	for ripple in simulation.ripples:
		var age := clampf(float(simulation.tick - ripple["tick"]) / Simulation.RIPPLE_TICKS, 0.0, 1.0)
		var radius := lerpf(RIPPLE_FROM, RIPPLE_TO, age) / zoom
		var color := Color(RIPPLE_COLOR, RIPPLE_COLOR.a * (1.0 - age))
		draw_arc(ripple["at"], radius, 0.0, TAU, 40, color, RIPPLE_WIDTH / zoom, true)
	var hint := simulation.hint
	if hint.visible:
		var pulse := fmod(float(simulation.tick) / Simulation.TICK_RATE, HINT_PULSE_SECONDS) / HINT_PULSE_SECONDS
		var swell := lerpf(HINT_FROM, HINT_TO, pulse) / zoom
		draw_arc(hint.position, HINT_FROM / zoom, 0.0, TAU, 40, HINT_COLOR, HINT_WIDTH / zoom, true)
		draw_arc(hint.position, swell, 0.0, TAU, 48, Color(HINT_COLOR, HINT_COLOR.a * (1.0 - pulse)),
				HINT_WIDTH / zoom, true)
	var slimes := simulation.slimes
	for slime_id in eyed_slimes(slimes, SlimeRenderer.shown_rect(get_viewport())):
		var r := slimes.radius_of(slime_id)
		var look: Vector2 = simulation.facing.get(slime_id, Vector2.RIGHT)
		var at := slimes.centre_of(slime_id) + look * r * EYE_OUT + Vector2(0.0, -r * 0.2)
		draw_circle(at, r * EYE_SIZE, EYE_COLOR)


## The slimes of `slimes` whose eye is drawn: those that can be seen on world
## rect `shown` (SlimeRenderer.is_seen), in slime index order.
static func eyed_slimes(slimes: SlimeBodies, shown: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	for s in slimes.slime_count:
		if SlimeRenderer.is_seen(slimes, s, shown):
			out.append(slimes.id[s])
	return out

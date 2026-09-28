class_name TestModeOverlay
extends Node2D
## Test mode's on-screen marker, a developer aid rather than game interface: a
## banner with the tick, seed and time scale, and a ring on every finger
## down, so a debug run shows what the script is doing.

const TEXT_COLOR := Color(1.0, 0.2, 0.8)
const FONT_SIZE := 16
const FINGER_RADIUS := 28.0

## The test mode it reports on.
var test_mode: TestMode = null
## How many times _draw ran (lets a headless test see that drawing happens).
var draw_count := 0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_count += 1
	if test_mode == null or test_mode.game == null:
		return
	var sim: Simulation = test_mode.game.simulation
	var font := ThemeDB.fallback_font
	var banner := "TEST MODE  tick %d  seed %d  time x%s" % [sim.tick, sim.rng.seed_value, test_mode.time_scale]
	draw_string(font, Vector2(8, 8 + FONT_SIZE), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
	for finger in sim.fingers_down:
		var at: Vector2 = sim.fingers_down[finger]
		draw_arc(at, FINGER_RADIUS, 0.0, TAU, 32, TEXT_COLOR, 3.0)
		draw_string(font, at + Vector2(FINGER_RADIUS, -FINGER_RADIUS), str(finger),
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)

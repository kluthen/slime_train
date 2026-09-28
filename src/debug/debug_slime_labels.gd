class_name DebugSlimeLabels
extends Node2D
## Draws, under each slime, its runtime id and state name ("#12 train") and,
## on a second line, its stable ID (its first member, "+n" for the others).
## World space, like TapFeedback: place it at the world origin; the text
## keeps its screen size at any zoom. It only reads the simulation. Debug
## builds only (DebugOverlay toggles it).

## The text's size and the gap under the body, screen pixels.
const FONT_SIZE := 13
const GAP := 4.0
const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const OUTLINE_SIZE := 4

## The simulation drawn.
var simulation: Simulation = null


func _init() -> void:
	z_index = 12


func _process(_delta: float) -> void:
	queue_redraw()


## The two lines drawn for slime `slime_id` of `sim`.
static func lines_for(sim: Simulation, slime_id: int) -> PackedStringArray:
	var bodies := sim.slimes
	var first := "#%d %s" % [slime_id, SlimeBodies.STATE_NAMES[bodies.state_of(slime_id)]]
	var members := sim.identities.members_of(slime_id)
	var second := ""
	if not members.is_empty():
		second = members[0] if members.size() == 1 else "%s +%d" % [members[0], members.size() - 1]
	return PackedStringArray([first, second])


func _draw() -> void:
	if simulation == null:
		return
	var font := ThemeDB.fallback_font
	var zoom := simulation.view.zoom
	var bodies := simulation.slimes
	for slime_id in bodies.ids():
		var lines := lines_for(simulation, slime_id)
		var under := bodies.centre_of(slime_id) + Vector2(0.0, bodies.radius_of(slime_id) + SlimeBodies.EDGE)
		draw_set_transform(under, 0.0, Vector2.ONE / zoom)
		var y := GAP + font.get_ascent(FONT_SIZE)
		for line in lines:
			if line.is_empty():
				continue
			var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			var at := Vector2(-width * 0.5, y)
			draw_string_outline(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, OUTLINE_COLOR)
			draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
			y += font.get_height(FONT_SIZE)
	draw_set_transform(Vector2.ZERO)

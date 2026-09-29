@tool
class_name Sleeper
extends Node2D
## A sleeping slime placed in the level (master spec §5.2): it wakes when a
## free slime touches it, on screen (D13, D70). Sleepers sit off the loop
## (rule 17). The marker: a fresh game puts a sleeping slime body here
## (Level.build -> LevelData.sleepers -> Sleepers.place), so the game draws
## the body, not this; the circle and label show in the editor only.
# @spec-link [[rule_sleepers_never_on_loop]]
# @spec-link [[req_level_design_rules]]

## The stable ID, `<place>.sleeper.<nn>`, numbered left to right.
@export var stable_id := "":
	set(value):
		stable_id = value
		queue_redraw()
## Its species (placeholder letters; the real species come with the art).
@export_enum("A", "B", "C", "D", "E", "F") var species := "A":
	set(value):
		species = value
		queue_redraw()

## Its size: level-placed sleepers are always size 1.
var size := 1


func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


## What a tap lands on (TapDispatcher): its drawn circle's box. A tap on a
## sleeper is a call centred on its body (D46; Sleepers.tap_targets moves the
## box onto the body and drops it once the sleeper wakes).
# @spec-link [[req_controls_tap_zones]]
func tap_target() -> Dictionary:
	return {"kind": TapDispatcher.KIND_SLEEPER, "size": Vector2.ONE * 2.0 * PlaceholderArt.SLIME_RADIUS}


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := PlaceholderArt.species_color(species)
	draw_circle(Vector2.ZERO, PlaceholderArt.SLIME_RADIUS, Color(color, 0.45))
	draw_arc(Vector2.ZERO, PlaceholderArt.SLIME_RADIUS, 0.0, TAU, 32, color, 2.0, true)
	var label := stable_id.get_slice(".", stable_id.get_slice_count(".") - 1)
	PlaceholderArt.draw_label(self, "%s %s" % [species, label], Vector2(-18, -PlaceholderArt.SLIME_RADIUS - 6))

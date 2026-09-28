@tool
class_name Sleeper
extends Node2D
## A sleeping slime placed in the level (master spec §5.2): it wakes when an
## awake slime of its species touches it. Sleepers sit off the loop (rule 5).
## Placeholder: a coloured circle until the slime body (chunk 5).
# @spec-link [[rule_sleepers_never_on_loop]]
# @spec-link [[req_level_design_rules]]

## The stable ID, `<place>.sleeper.<nn>`, numbered left to right.
@export var stable_id := "":
	set(value):
		stable_id = value
		queue_redraw()
## Its species (placeholder letters; the real species come with the art).
@export_enum("A", "B", "C", "D", "E") var species := "A":
	set(value):
		species = value
		queue_redraw()

## Its size: level-placed sleepers are always size 1.
var size := 1


func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _draw() -> void:
	var color := PlaceholderArt.species_color(species)
	draw_circle(Vector2.ZERO, PlaceholderArt.SLIME_RADIUS, Color(color, 0.45))
	draw_arc(Vector2.ZERO, PlaceholderArt.SLIME_RADIUS, 0.0, TAU, 32, color, 2.0, true)
	var label := stable_id.get_slice(".", stable_id.get_slice_count(".") - 1)
	PlaceholderArt.draw_label(self, "%s %s" % [species, label], Vector2(-18, -PlaceholderArt.SLIME_RADIUS - 6))

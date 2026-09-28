@tool
class_name FirstSlime
extends Node2D
## Where the first awake slime starts, on the loop in the start basin
## (master spec §5.2). The first sleeper is placed near it (rule 6).
## The game wakes the slime here at the start of a fresh game: Simulation.
## load_level creates it (size 1, a train slime, of this species).
# @spec-link [[rule_first_sleeper_near_first_awake_slime]]
# @spec-link [[req_level_design_rules]]
# @spec-link [[req_slime_states]]

## The stable ID, `start.first-slime`.
@export var stable_id := "start.first-slime":
	set(value):
		stable_id = value
		queue_redraw()
## Its species.
@export_enum("A", "B", "C", "D", "E") var species := "A":
	set(value):
		species = value
		queue_redraw()


func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _draw() -> void:
	var color := PlaceholderArt.species_color(species)
	draw_circle(Vector2.ZERO, PlaceholderArt.SLIME_RADIUS, color)
	draw_arc(Vector2.ZERO, PlaceholderArt.SLIME_RADIUS + 4.0, 0.0, TAU, 32, Color.WHITE, 2.0, true)
	PlaceholderArt.draw_label(self, "%s first slime" % species, Vector2(-40, -PlaceholderArt.SLIME_RADIUS - 8))

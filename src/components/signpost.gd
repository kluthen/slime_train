@tool
class_name Signpost
extends Node2D
## A signpost (master spec §5.4, D47, rule 6): stands at a fork of the loop
## (in v1, each frontier switch) and shows which way the loop goes. Not
## interactive. Placeholder: a labelled post until the art; the game draws
## its arrow the way its switch sends the flow (FrontierView).

const COLOR := Color(0.8, 0.65, 0.4)

## The stable ID, `<place>.signpost`.
@export var stable_id := "":
	set(value):
		stable_id = value
		queue_redraw()
## The stable ID of the Switch it explains.
# @spec-link [[rule_signpost_at_every_fork]]
@export var switch_id := ""


func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(0, -60), COLOR, 4.0)
	draw_rect(Rect2(-30, -90, 60, 32), COLOR)
	PlaceholderArt.draw_label(self, stable_id, Vector2(-30, -96))


## The stable IDs it points at, by property (see Level): its switch.
# @spec-link [[req_interactive_objects_general]]
func references() -> Dictionary:
	return {"switch_id": switch_id}

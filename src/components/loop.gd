class_name Loop
extends Node2D
## The loop (master spec §5.1): the drawn route the train follows. Its
## children are LoopSegment nodes, in loop order: for each section its
## outgoing segments, then its return route. Opening a section's gate retires
## that section's return route and extends the loop into the next section.
##
## At load, the Level turns the segments into LoopData (plain data in level
## pixels) that the simulation uses; see src/sim/loop_data.gd.

## The loop's stable ID; by convention `start.loop`.
@export var stable_id := "start.loop"


func _init() -> void:
	add_to_group(Level.THINGS_GROUP)


## The LoopSegment children, in order.
func segment_nodes() -> Array[LoopSegment]:
	var out: Array[LoopSegment] = []
	for child in get_children():
		if child is LoopSegment:
			out.append(child)
	return out


## The loop as plain data, in the coordinates of `level`.
# @spec-link [[req_loop_and_world]]
# @spec-link [[rule_return_route_per_section]]
func build_data(level: Level) -> LoopData:
	var loop_data := LoopData.new(stable_id)
	for segment in segment_nodes():
		loop_data.add_segment(segment.stable_id, segment.section, segment.kind,
				segment.level_points(level), segment.gate_id)
	return loop_data

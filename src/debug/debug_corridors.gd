class_name DebugCorridors
extends Node2D
## Outlines the hop corridor (chunk 22f, D147 (4); TrainHold) of every
## simulated train slime under a debug label (DebugSlimeLabels.labelled_slimes:
## the slimes that can be seen), coloured by whether it holds (HELD_COLOR) or
## is free (FREE_COLOR). The corridor is the one its next hop would check: from
## its centre to the target the Train would aim it at, plus
## TrainHold.CORRIDOR_PAST, TrainHold.CORRIDOR_HALF_WIDTH either side. None on a
## slide (no hop there). World space, like DebugSlimeLabels: place it at the
## world origin; the line keeps its screen width at any zoom. It only reads the
## simulation. Debug builds only: DebugOverlay toggles it, hidden by default,
## and it redraws every frame only while shown.
# @spec-link [[req_platform_and_performance_targets]]

const HELD_COLOR := Color(1.0, 0.35, 0.3, 0.9)
const FREE_COLOR := Color(0.4, 1.0, 0.5, 0.7)
## The outline's width, screen pixels.
const LINE_WIDTH := 1.5

## The simulation drawn.
var simulation: Simulation = null


## Under the slime labels (DebugSlimeLabels' z_index 12).
func _init() -> void:
	z_index = 11


## Processes (redraws each frame) only while shown.
func _ready() -> void:
	set_process(is_visible_in_tree())


## Follows being shown or hidden: no redraw while hidden.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		set_process(is_visible_in_tree())


## Asks for this frame's redraw (only processing while shown).
func _process(_delta: float) -> void:
	queue_redraw()


## Train slime `slime_id`'s hop corridor in `sim` now (TrainHold.corridor_corners
## towards the Train's hop_target from its steering progress), or none when it
## isn't a followed, simulated train slime or is on a slide.
# @spec-link [[req_platform_and_performance_targets]]
static func corridor_of(sim: Simulation, slime_id: int) -> PackedVector2Array:
	var bodies := sim.slimes
	var train := sim.train
	if train == null or bodies.state_of(slime_id) != SlimeBodies.TRAIN or bodies.is_parked(slime_id) \
			or not train.tracks(slime_id):
		return PackedVector2Array()
	var from := bodies.centre_of(slime_id)
	var progress := train.steering_distance(train.distance_of(slime_id), from)
	if train.is_slide_at(progress):
		return PackedVector2Array()
	return TrainHold.corridor_corners(from, train.hop_target(progress, Train.hop_reach(bodies.size_of(slime_id))))


## This frame's drawing: the labelled train slimes' corridors, outlined.
func _draw() -> void:
	if simulation == null:
		return
	var zoom := simulation.view.zoom
	var bodies := simulation.slimes
	for slime_id in DebugSlimeLabels.labelled_slimes(bodies, SlimeRenderer.shown_rect(get_viewport()), zoom):
		var corners := corridor_of(simulation, slime_id)
		if corners.is_empty():
			continue
		corners.append(corners[0])
		var color := HELD_COLOR if simulation.train.is_holding(slime_id) else FREE_COLOR
		draw_polyline(corners, color, LINE_WIDTH / zoom)

class_name DebugCorridors
extends Node2D
## Outlines the hop corridor (chunk 22f, D147 (4); TrainHold) of every
## simulated train slime under a debug label (DebugSlimeLabels.labelled_slimes:
## the slimes that can be seen), coloured by whether it holds (HELD_COLOR) or
## is free (FREE_COLOR). The corridor is the one its next hop would check: from
## its centre to the target the Train would aim it at, plus
## TrainHold.CORRIDOR_PAST, TrainHold.CORRIDOR_HALF_WIDTH either side. None on a
## slide (no hop there). World space, like DebugSlimeLabels: place it at the
## world origin; the line keeps its screen width at any zoom. With the Train's
## front_first on (chunk 22g), it also marks the loop buckets' boundaries, a
## short tick across the loop at each (bucket_ticks), for information. It
## only reads the simulation. Debug builds only: DebugOverlay toggles it,
## hidden by default, and it redraws every frame only while shown.
# @spec-link [[req_platform_and_performance_targets]]

const HELD_COLOR := Color(1.0, 0.35, 0.3, 0.9)
const FREE_COLOR := Color(0.4, 1.0, 0.5, 0.7)
## The loop buckets' boundary ticks: muted, under the corridors' colours.
# @spec-link [[req_platform_and_performance_targets]]
const BOUNDARY_COLOR := Color(0.75, 0.8, 0.9, 0.5)
## A boundary tick's length either side of the loop, world px.
const TICK_HALF_LENGTH := 12.0
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


## The loop buckets' boundary ticks of `train` now: two ends per boundary
## (Train.bucket_boundaries), a segment across the loop centred on it,
## TICK_HALF_LENGTH either side. None with front_first off or no Train.
# @spec-link [[req_platform_and_performance_targets]]
static func bucket_ticks(train: Train) -> PackedVector2Array:
	var ticks := PackedVector2Array()
	if train == null:
		return ticks
	for distance in train.bucket_boundaries():
		var at := train.position_at(distance)
		var across := train.direction_at(distance).orthogonal() * TICK_HALF_LENGTH
		ticks.append(at - across)
		ticks.append(at + across)
	return ticks


## This frame's drawing: the loop buckets' boundary ticks, then the labelled
## train slimes' corridors, outlined.
func _draw() -> void:
	if simulation == null:
		return
	var zoom := simulation.view.zoom
	var ticks := bucket_ticks(simulation.train)
	if not ticks.is_empty():
		draw_multiline(ticks, BOUNDARY_COLOR, LINE_WIDTH / zoom)
	var bodies := simulation.slimes
	for slime_id in DebugSlimeLabels.labelled_slimes(bodies, SlimeRenderer.shown_rect(get_viewport()), zoom):
		var corners := corridor_of(simulation, slime_id)
		if corners.is_empty():
			continue
		corners.append(corners[0])
		var color := HELD_COLOR if simulation.train.is_holding(slime_id) else FREE_COLOR
		draw_polyline(corners, color, LINE_WIDTH / zoom)

class_name DebugSlimeLabels
extends Node2D
## Draws, under each slime, its runtime id and state name ("#12 train") and,
## on a second line, its stable ID (its first member, "+n" for the others).
## World space, like TapFeedback: place it at the world origin; the text
## keeps its screen size at any zoom. It only reads the simulation. Debug
## builds only (DebugOverlay toggles it). It redraws every frame only while
## shown, and labels only the slimes that can be seen (labelled_slimes()).
## Their places follow every frame; their text is cached and rebuilt at most
## every TEXT_REFRESH_MS (text_lines(), refresh_text()), so a label may lag
## its slime's state by up to that (issue 24.6).

## The text's size and the gap under the body, screen pixels.
const FONT_SIZE := 13
const GAP := 4.0
const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const OUTLINE_SIZE := 4
## How far past the shown rect a slime is still labelled, beyond its own
## reach (SlimeRenderer.is_seen), screen pixels: a label's half width and its
## two lines under the body.
const LABEL_REACH := 160.0
## The cached label text is rebuilt at most this often, real milliseconds.
# @spec-link [[req_platform_and_performance_targets]]
const TEXT_REFRESH_MS := 250


## A slime's cached label text: its lines (lines_for()) and each line's
## width at FONT_SIZE, screen pixels.
class LabelText:
	extends RefCounted
	var lines: PackedStringArray
	var widths: PackedFloat32Array

	## Caches `label_lines` and their widths measured with `font`.
	func _init(label_lines: PackedStringArray, font: Font) -> void:
		lines = label_lines
		for line in lines:
			widths.append(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)


## The simulation drawn.
var simulation: Simulation = null
## The real time its per-frame drawing (_draw; its _process only asks for
## the redraw) took, microseconds, summed until the debug perf log takes it
## (and sets it back to 0); nothing else reads it. Always counted: two clock
## reads a frame.
# @spec-link [[req_platform_and_performance_targets]]
var frame_cost_usec := 0

## The cached text: slime id -> LabelText, built on first use since the
## last refresh (refresh_text()).
# @spec-link [[req_platform_and_performance_targets]]
var _text := {}
## The simulation the cached text was built from.
var _text_simulation: Simulation = null
## When (Time.get_ticks_msec()) the cached text is dropped next; -1: now.
var _text_due_ms := -1


func _init() -> void:
	z_index = 12


## Processes (redraws each frame) only while shown.
func _ready() -> void:
	set_process(is_visible_in_tree())


## Follows being shown or hidden: no redraw while hidden.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		set_process(is_visible_in_tree())


func _process(_delta: float) -> void:
	queue_redraw()


## The slimes of `slimes` labelled when world rect `shown` is on screen at
## `zoom`: those seen (SlimeRenderer.is_seen) on `shown` grown by LABEL_REACH
## screen pixels, in slime index order.
static func labelled_slimes(slimes: SlimeBodies, shown: Rect2, zoom: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var reach := shown.grow(LABEL_REACH / zoom)
	for s in slimes.slime_count:
		if SlimeRenderer.is_seen(slimes, s, reach):
			out.append(slimes.id[s])
	return out


## The two lines drawn for slime `slime_id` of `sim`.
static func lines_for(sim: Simulation, slime_id: int) -> PackedStringArray:
	var bodies := sim.slimes
	var first := "#%d %s" % [slime_id, SlimeBodies.STATE_NAMES[bodies.state_of(slime_id)]]
	var members := sim.identities.members_of(slime_id)
	var second := ""
	if not members.is_empty():
		second = members[0] if members.size() == 1 else "%s +%d" % [members[0], members.size() - 1]
	return PackedStringArray([first, second])


## Draws this frame (_paint()), adding the time it took to frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _draw() -> void:
	var start_usec := Time.get_ticks_usec()
	_paint()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## Drops the cached text when TEXT_REFRESH_MS have passed since the last
## drop at real time `now_ms` (or on the first call), or when the
## simulation changed; text_lines() then builds it anew. Returns whether it
## dropped it.
# @spec-link [[req_platform_and_performance_targets]]
func refresh_text(now_ms: int) -> bool:
	if simulation == _text_simulation and _text_due_ms >= 0 and now_ms < _text_due_ms:
		return false
	_text.clear()
	_text_simulation = simulation
	_text_due_ms = now_ms + TEXT_REFRESH_MS
	return true


## Slime `slime_id`'s label text: the cached one, else lines_for() built
## now and cached until the next refresh_text() drop.
# @spec-link [[req_platform_and_performance_targets]]
func text_lines(slime_id: int) -> LabelText:
	var text: LabelText = _text.get(slime_id)
	if text == null:
		text = LabelText.new(lines_for(simulation, slime_id), ThemeDB.fallback_font)
		_text[slime_id] = text
	return text


## This frame's drawing: the seen slimes' labels, placed now, their text
## from the cache (refresh_text(), text_lines()).
func _paint() -> void:
	if simulation == null:
		return
	refresh_text(Time.get_ticks_msec())
	var font := ThemeDB.fallback_font
	var zoom := simulation.view.zoom
	var bodies := simulation.slimes
	for slime_id in labelled_slimes(bodies, SlimeRenderer.shown_rect(get_viewport()), zoom):
		var text := text_lines(slime_id)
		var under := bodies.centre_of(slime_id) + Vector2(0.0, bodies.radius_of(slime_id) + SlimeBodies.EDGE)
		draw_set_transform(under, 0.0, Vector2.ONE / zoom)
		var y := GAP + font.get_ascent(FONT_SIZE)
		for i in text.lines.size():
			var line := text.lines[i]
			if line.is_empty():
				continue
			var at := Vector2(-text.widths[i] * 0.5, y)
			draw_string_outline(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, OUTLINE_COLOR)
			draw_string(font, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
			y += font.get_height(FONT_SIZE)
	draw_set_transform(Vector2.ZERO)

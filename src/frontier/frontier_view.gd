class_name FrontierView
extends Node2D
## Draws what the simulation says about the frontier sets (FrontierSets),
## above the level's placeholder boxes: each basket's quota outlines, filled
## by the weight in it (a size-3 slime fills 3); the reward while it plays;
## each switch's shut trapdoor and which way it sends the flow; each
## signpost's arrow, the way its switch sends the flow; each gate's box while
## closed and its lid once the old slide entrance is closed; the level's
## one-time celebration (hidden at bedtime, when it stands still); and,
## once it has played, the level's lasting mark at the start of the loop
## (item 23.11). It only reads the simulation. Placeholder art until the
## ui_ux tree settles the look. Place it at the world origin.
## Each basket's slots are two instanced draws (ShapeInstances children: the
## filled slots' discs, then every slot's outline), and the celebration and
## the mark are drawn on a last child (the overlay), so they stay above them.
# @spec-link [[req_switch_basket_gate_set]]
# @spec-link [[rule_signpost_at_every_fork]]
# @spec-link [[req_level_completion_celebration]]

const OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const FILL_COLOR := Color(1.0, 0.85, 0.3, 0.9)
## One quota outline's radius and the gap between two, level pixels.
const OUTLINE_RADIUS := 14.0
const OUTLINE_GAP := 8.0
## A quota outline's line width (level pixels, antialiased) and point count.
const OUTLINE_WIDTH := 2.0
const OUTLINE_SEGMENTS := 24
## How far above the basket's box the outlines sit, level pixels.
const OUTLINE_LIFT := 30.0
const DOOR_COLOR := Color(0.55, 0.45, 0.35)
const GATE_COLOR := Color(0.5, 0.5, 0.6, 0.9)
const ARROW_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const ARROW_LENGTH := 44.0
const REWARD_COLOR := Color(1.0, 0.95, 0.5)
const CELEBRATION_COLORS: Array[Color] = [Color(1.0, 0.4, 0.4), Color(1.0, 0.85, 0.3),
		Color(0.4, 0.8, 1.0), Color(0.5, 1.0, 0.5), Color(0.85, 0.5, 1.0)]
## The lasting mark's placeholder bunting, level pixels: half the span
## between its posts, their height above the ground, how far the string
## sags, its pennant count and how far each pennant hangs.
const MARK_HALF_WIDTH := 90.0
const MARK_HEIGHT := 150.0
const MARK_SAG := 20.0
const MARK_PENNANTS := 6
const MARK_PENNANT_DROP := 26.0
const MARK_POST_COLOR := Color(0.95, 0.95, 0.9)

## The simulation drawn.
var simulation: Simulation = null
## The real time its per-frame work took, microseconds: _process building
## the drawn state and _draw drawing it (only on a frame that redraws),
## summed until the debug perf log takes it (and sets it back to 0); nothing
## else reads it. Always counted: a few clock reads a frame.
# @spec-link [[req_platform_and_performance_targets]]
var frame_cost_usec := 0

## The drawn state (_fill_drawn_state()) of the last redraw asked for, and
## the array this frame's is built into; the two swap on a change, so no
## allocation a frame once their sizes settle.
# @spec-link [[req_platform_and_performance_targets]]
var _drawn_state := []
var _next_state := []

## The way on along the loop at each switch (id -> unit Vector2, see
## way_of()), worked out for level _ways_level with gates _ways_gates open:
## the loop doesn't move, so only a new level or a gate opening changes it.
var _ways := {}
var _ways_level: LevelData = null
var _ways_gates: Array = []

## Per basket id, its slots' two instanced draws, children before _overlay:
## [the filled slots' discs, every slot's outline], made for level
## _slots_level (_sync_slots()).
# @spec-link [[req_platform_and_performance_targets]]
var _slots := {}
var _slots_level: LevelData = null
## The last child, drawn after the baskets' instanced draws (children draw
## after their parent's own drawing, in tree order): the celebration and the
## lasting mark, which the baskets' outlines used to be drawn under.
# @spec-link [[req_platform_and_performance_targets]]
var _overlay := Node2D.new()


func _init() -> void:
	z_index = 5
	_overlay.name = "Overlay"
	_overlay.draw.connect(_paint_overlay)
	add_child(_overlay)


## Asks for a redraw only when the drawn state changed since the last one,
## or every frame while the celebration's burst shows (it moves with the
## tick and the view); otherwise the last picture stays on screen.
# @spec-link [[req_platform_and_performance_targets]]
func _process(_delta: float) -> void:
	var start_usec := Time.get_ticks_usec()
	var celebrating := _fill_drawn_state(_next_state)
	if celebrating or _next_state != _drawn_state:
		var last := _drawn_state
		_drawn_state = _next_state
		_next_state = last
		queue_redraw()
		_overlay.queue_redraw()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## Fills `into` with every value _paint() draws from, in a fixed order, so
## two equal arrays draw the same picture: the simulation and its level
## (their geometry is fixed per level), then per switch its trapdoor shut and
## its way, per signpost its way, per gate open and its entrance closed, per
## basket its weight, phase and reward pulse age, then whether the
## celebration's burst shows and where the lasting mark stands (or null).
## Returns whether the burst shows.
# @spec-link [[req_platform_and_performance_targets]]
func _fill_drawn_state(into: Array) -> bool:
	if simulation == null or simulation.level == null:
		into.resize(2)
		into[0] = simulation.get_instance_id() if simulation != null else 0
		into[1] = 0
		return false
	var level := simulation.level
	var states := simulation.object_states
	into.resize(4 + level.switches.size() * 2 + level.signposts.size()
			+ level.gates.size() * 2 + level.baskets.size() * 3)
	into[0] = simulation.get_instance_id()
	into[1] = level.get_instance_id()
	var celebrating := simulation.frontier.celebration_showing(simulation)
	into[2] = celebrating
	into[3] = mark_at()
	var i := 4
	for id in level.switches:
		into[i] = (states.get(id, {}) as Dictionary).get("trapdoor_shut", true)
		into[i + 1] = way_of(id)
		i += 2
	for id in level.signposts:
		into[i] = way_of(level.signposts[id]["switch"])
		i += 1
	for id in level.gates:
		var gate_state: Dictionary = simulation.gate_states.get(id, {})
		into[i] = gate_state.get("open", false)
		into[i + 1] = gate_state.get("entrance_closed", false)
		i += 2
	for id in level.baskets:
		var state: Dictionary = states.get(id, {})
		var phase: String = state.get("phase", FrontierSets.FILLING)
		into[i] = state.get("weight", 0)
		into[i + 1] = phase
		into[i + 2] = simulation.tick - int(state.get("since", 0)) if phase == FrontierSets.REWARD else 0
		i += 3
	return celebrating


## Draws this frame (_paint()), adding the time it took to frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _draw() -> void:
	var start_usec := Time.get_ticks_usec()
	_paint()
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## Draws the overlay (_overlay): the celebration while its burst shows and
## the lasting mark once it stands, adding the time it took to
## frame_cost_usec.
# @spec-link [[req_platform_and_performance_targets]]
func _paint_overlay() -> void:
	var start_usec := Time.get_ticks_usec()
	if simulation != null and simulation.level != null:
		if simulation.frontier.celebration_showing(simulation):
			_celebration()
		var mark: Variant = mark_at()
		if mark != null:
			_mark(mark)
	frame_cost_usec += Time.get_ticks_usec() - start_usec


## This frame's drawing: switches, signposts, gates and baskets (the
## celebration and the lasting mark are the overlay's, _paint_overlay()).
func _paint() -> void:
	_sync_slots(simulation.level if simulation != null else null)
	if simulation == null or simulation.level == null:
		return
	var level := simulation.level
	var states := simulation.object_states
	for id in level.switches:
		var switch: Dictionary = level.switches[id]
		var state: Dictionary = states.get(id, {})
		var trapdoor: Rect2 = switch["trapdoor"]
		if trapdoor.has_area() and state.get("trapdoor_shut", true):
			draw_rect(trapdoor, DOOR_COLOR)
		_arrow((switch["box"] as Rect2).get_center(), way_of(id))
	for id in level.signposts:
		var signpost: Dictionary = level.signposts[id]
		_arrow(signpost["position"] + Vector2(0.0, -74.0), way_of(signpost["switch"]))
	for id in level.gates:
		var gate: Dictionary = level.gates[id]
		var state: Dictionary = simulation.gate_states.get(id, {})
		if not state.get("open", false):
			draw_rect(gate["box"], GATE_COLOR)
		if state.get("entrance_closed", false) and (gate["lid"] as Rect2).has_area():
			draw_rect(gate["lid"], DOOR_COLOR)
	for id in level.baskets:
		_basket(id, level.baskets[id], states.get(id, {}))


## Makes the baskets' instanced draws (_slots) for `level` (null: none) when
## they were made for another: two children per basket, in the level's
## basket order, then the overlay moved last.
# @spec-link [[req_platform_and_performance_targets]]
func _sync_slots(level: LevelData) -> void:
	if level == _slots_level:
		return
	for pair: Array in _slots.values():
		for node: ShapeInstances in pair:
			remove_child(node)
			node.queue_free()
	_slots.clear()
	_slots_level = level
	if level == null:
		return
	for id in level.baskets:
		var discs := ShapeInstances.new()
		discs.name = "BasketDiscs%d" % _slots.size()
		var outlines := ShapeInstances.new()
		outlines.name = "BasketOutlines%d" % _slots.size()
		outlines.self_modulate = OUTLINE_COLOR
		add_child(discs)
		add_child(outlines)
		_slots[id] = [discs, outlines]
	move_child(_overlay, -1)


## Basket `id`'s instanced draws: [the filled slots' discs, every slot's
## outline] (see _slots).
func basket_slots(id: String) -> Array:
	return _slots[id]


## Where the level's lasting mark is drawn (the start of the loop), or null
## while it doesn't show: the celebration hasn't played, or its burst still
## plays (FrontierSets.mark_showing).
# @spec-link [[req_level_completion_celebration]]
func mark_at() -> Variant:
	if simulation == null or simulation.level == null or simulation.level.loop == null:
		return null
	if not simulation.frontier.mark_showing(simulation.tick):
		return null
	return FrontierSets.mark_point(simulation.level)


## The way switch `id` sends the flow: down into its basket when flipped,
## else on along the loop (cached, _refresh_ways()).
func way_of(id: String) -> Vector2:
	var state: Dictionary = simulation.object_states.get(id, {})
	if state.get("flipped", false):
		return Vector2.DOWN
	_refresh_ways()
	return _ways[id]


## Works out the way on along the loop at every switch, and for every
## signpost's switch, when the level or its open gates changed since the
## last time (see _ways).
func _refresh_ways() -> void:
	var level := simulation.level
	var gates: Array = simulation.train.open_gates if simulation.train != null else []
	if level == _ways_level and gates == _ways_gates:
		return
	_ways.clear()
	for id in level.switches:
		_ways[id] = _way_along_loop(level, id, gates)
	for id in level.signposts:
		var switch_id: String = level.signposts[id]["switch"]
		if not _ways.has(switch_id):
			_ways[switch_id] = _way_along_loop(level, switch_id, gates)
	_ways_level = level
	_ways_gates = gates.duplicate()


## The way on along `level`'s loop with `gates` open at switch `id`, a unit
## vector: right when the level has no such switch or no loop.
func _way_along_loop(level: LevelData, id: String, gates: Array) -> Vector2:
	var switch: Dictionary = level.switches.get(id, {})
	var loop := level.loop
	if switch.is_empty() or loop == null:
		return Vector2.RIGHT
	var at: float = loop.closest((switch["box"] as Rect2).get_center(), gates)["distance"]
	var ahead := loop.position_at(at + 40.0, gates) - loop.position_at(at, gates)
	return ahead.normalized() if ahead.length() > 0.001 else Vector2.RIGHT


func _arrow(from: Vector2, way: Vector2) -> void:
	var tip := from + way * ARROW_LENGTH
	draw_line(from, tip, ARROW_COLOR, 4.0)
	draw_line(tip, tip - way.rotated(0.5) * 14.0, ARROW_COLOR, 4.0)
	draw_line(tip, tip - way.rotated(-0.5) * 14.0, ARROW_COLOR, 4.0)


## Basket `basket` (id `id`, state `state`)'s quota slots in a row above its
## box: an outline each, filled from the left by the weight in it (all once
## FIRED), swelling with the reward pulse. Drawn as two instanced draws, the
## filled slots' discs (draw_circle()'s) then every outline (draw_arc()'s),
## where each slot drew its disc then its outline: the same picture while a
## slot's outline (its reach) stays clear of the next slot's disc (at rest the
## gap is OUTLINE_GAP + OUTLINE_RADIUS minus the outline's half width and
## feather, about 6 px). The reward pulse swells them until it doesn't, and
## then they are drawn slot by slot, as before.
# @spec-link [[req_platform_and_performance_targets]]
func _basket(id: String, basket: Dictionary, state: Dictionary) -> void:
	var box: Rect2 = basket["box"]
	var quota: int = basket["quota"]
	var weight: int = state.get("weight", 0)
	var phase: String = state.get("phase", FrontierSets.FILLING)
	var step := OUTLINE_RADIUS * 2.0 + OUTLINE_GAP
	var left := box.get_center().x - step * (quota - 1) * 0.5
	var y := box.position.y - OUTLINE_LIFT
	var rewarding := phase == FrontierSets.REWARD
	var pulse := 1.0
	if rewarding:
		pulse = 1.0 + 0.25 * sin(float(simulation.tick - int(state.get("since", 0))) * 0.3)
	var radius := OUTLINE_RADIUS * pulse
	var color := REWARD_COLOR if rewarding else FILL_COLOR
	var filled := quota if phase == FrontierSets.FIRED else weight
	var discs: ShapeInstances = _slots[id][0]
	var outlines: ShapeInstances = _slots[id][1]
	discs.clear()
	outlines.clear()
	outlines.set_ring(radius, OUTLINE_WIDTH, OUTLINE_SEGMENTS, true)
	if radius + outlines.reach >= step:
		for k in quota:
			var at := Vector2(left + step * k, y)
			if k < filled:
				draw_circle(at, radius, color)
			draw_arc(at, radius, 0.0, TAU, OUTLINE_SEGMENTS, OUTLINE_COLOR, OUTLINE_WIDTH, true)
	else:
		discs.set_disc(radius)
		discs.self_modulate = color
		for k in quota:
			var at := Vector2(left + step * k, y)
			if k < filled:
				discs.add(at)
			outlines.add(at)
	discs.commit()
	outlines.commit()


## A burst of rings over the view, from the tick it began (deterministic),
## on the overlay.
func _celebration() -> void:
	var view := Fusion.view_rect(simulation.view)
	var age := float(simulation.tick - simulation.frontier.celebration_since) / Simulation.TICK_RATE
	var share := clampf(age / FrontierSets.CELEBRATION_SECONDS, 0.0, 1.0)
	for k in 12:
		var spot := view.position + view.size * Vector2(fmod(0.13 + k * 0.37, 1.0), fmod(0.29 + k * 0.53, 1.0))
		var radius := (20.0 + 120.0 * fmod(age + k * 0.23, 1.0)) / simulation.view.zoom
		var color: Color = CELEBRATION_COLORS[k % CELEBRATION_COLORS.size()]
		_overlay.draw_arc(spot, radius, 0.0, TAU, 32, Color(color, 1.0 - share), 5.0 / simulation.view.zoom, true)


## The lasting mark at `at` (the start of the loop, at a base slime's centre
## height): bunting, a string of pennants in the celebration's colours
## between two thin posts standing on the ground. Placeholder art: its real
## look is ux-writer's (ux D4 names bunting as an example). On the overlay.
func _mark(at: Vector2) -> void:
	var ground := at.y + PlaceholderArt.SLIME_RADIUS
	var left := Vector2(at.x - MARK_HALF_WIDTH, ground - MARK_HEIGHT)
	var right := Vector2(at.x + MARK_HALF_WIDTH, ground - MARK_HEIGHT)
	_overlay.draw_line(Vector2(left.x, ground), left, MARK_POST_COLOR, 4.0)
	_overlay.draw_line(Vector2(right.x, ground), right, MARK_POST_COLOR, 4.0)
	var string := PackedVector2Array()
	for k in MARK_PENNANTS + 1:
		var t := float(k) / MARK_PENNANTS
		string.append(left.lerp(right, t) + Vector2(0.0, MARK_SAG * 4.0 * t * (1.0 - t)))
	_overlay.draw_polyline(string, MARK_POST_COLOR, 2.0, true)
	for k in MARK_PENNANTS:
		var a := string[k]
		var b := string[k + 1]
		var tip := (a + b) * 0.5 + Vector2(0.0, MARK_PENNANT_DROP)
		var color: Color = CELEBRATION_COLORS[k % CELEBRATION_COLORS.size()]
		_overlay.draw_colored_polygon(PackedVector2Array([a, b, tip]), color)

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
# @spec-link [[req_switch_basket_gate_set]]
# @spec-link [[rule_signpost_at_every_fork]]
# @spec-link [[req_level_completion_celebration]]

const OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const FILL_COLOR := Color(1.0, 0.85, 0.3, 0.9)
## One quota outline's radius and the gap between two, level pixels.
const OUTLINE_RADIUS := 14.0
const OUTLINE_GAP := 8.0
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

## The way on along the loop at each switch (id -> unit Vector2, see
## way_of()), worked out for level _ways_level with gates _ways_gates open:
## the loop doesn't move, so only a new level or a gate opening changes it.
var _ways := {}
var _ways_level: LevelData = null
var _ways_gates: Array = []


func _init() -> void:
	z_index = 5


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
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
		_basket(level.baskets[id], states.get(id, {}))
	if simulation.frontier.celebration_showing(simulation):
		_celebration()
	var mark: Variant = mark_at()
	if mark != null:
		_mark(mark)


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


func _basket(basket: Dictionary, state: Dictionary) -> void:
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
	for k in quota:
		var at := Vector2(left + step * k, y)
		if phase == FrontierSets.FIRED or k < weight:
			draw_circle(at, OUTLINE_RADIUS * pulse, REWARD_COLOR if rewarding else FILL_COLOR)
		draw_arc(at, OUTLINE_RADIUS * pulse, 0.0, TAU, 24, OUTLINE_COLOR, 2.0, true)


## A burst of rings over the view, from the tick it began (deterministic).
func _celebration() -> void:
	var view := Fusion.view_rect(simulation.view)
	var age := float(simulation.tick - simulation.frontier.celebration_since) / Simulation.TICK_RATE
	var share := clampf(age / FrontierSets.CELEBRATION_SECONDS, 0.0, 1.0)
	for k in 12:
		var spot := view.position + view.size * Vector2(fmod(0.13 + k * 0.37, 1.0), fmod(0.29 + k * 0.53, 1.0))
		var radius := (20.0 + 120.0 * fmod(age + k * 0.23, 1.0)) / simulation.view.zoom
		var color: Color = CELEBRATION_COLORS[k % CELEBRATION_COLORS.size()]
		draw_arc(spot, radius, 0.0, TAU, 32, Color(color, 1.0 - share), 5.0 / simulation.view.zoom, true)


## The lasting mark at `at` (the start of the loop, at a base slime's centre
## height): bunting, a string of pennants in the celebration's colours
## between two thin posts standing on the ground. Placeholder art: its real
## look is ux-writer's (ux D4 names bunting as an example).
func _mark(at: Vector2) -> void:
	var ground := at.y + PlaceholderArt.SLIME_RADIUS
	var left := Vector2(at.x - MARK_HALF_WIDTH, ground - MARK_HEIGHT)
	var right := Vector2(at.x + MARK_HALF_WIDTH, ground - MARK_HEIGHT)
	draw_line(Vector2(left.x, ground), left, MARK_POST_COLOR, 4.0)
	draw_line(Vector2(right.x, ground), right, MARK_POST_COLOR, 4.0)
	var string := PackedVector2Array()
	for k in MARK_PENNANTS + 1:
		var t := float(k) / MARK_PENNANTS
		string.append(left.lerp(right, t) + Vector2(0.0, MARK_SAG * 4.0 * t * (1.0 - t)))
	draw_polyline(string, MARK_POST_COLOR, 2.0, true)
	for k in MARK_PENNANTS:
		var a := string[k]
		var b := string[k + 1]
		var tip := (a + b) * 0.5 + Vector2(0.0, MARK_PENNANT_DROP)
		var color: Color = CELEBRATION_COLORS[k % CELEBRATION_COLORS.size()]
		draw_colored_polygon(PackedVector2Array([a, b, tip]), color)

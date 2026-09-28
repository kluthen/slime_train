class_name FrontierView
extends Node2D
## Draws what the simulation says about the frontier sets (FrontierSets),
## above the level's placeholder boxes: each basket's quota outlines, filled
## by the weight in it (a size-3 slime fills 3); the reward while it plays;
## each switch's shut trapdoor and which way it sends the flow; each
## signpost's arrow, the way its switch sends the flow; each gate's box while
## closed and its lid once the old slide entrance is closed; and the level's
## one-time celebration. It only reads the simulation. Placeholder art until
## the ui_ux tree settles the look. Place it at the world origin.
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

## The simulation drawn.
var simulation: Simulation = null


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
		_arrow((switch["box"] as Rect2).get_center(), _way(id))
	for id in level.signposts:
		var signpost: Dictionary = level.signposts[id]
		_arrow(signpost["position"] + Vector2(0.0, -74.0), _way(signpost["switch"]))
	for id in level.gates:
		var gate: Dictionary = level.gates[id]
		var state: Dictionary = simulation.gate_states.get(id, {})
		if not state.get("open", false):
			draw_rect(gate["box"], GATE_COLOR)
		if state.get("entrance_closed", false) and (gate["lid"] as Rect2).has_area():
			draw_rect(gate["lid"], DOOR_COLOR)
	for id in level.baskets:
		_basket(level.baskets[id], states.get(id, {}))
	if simulation.frontier.celebration_playing(simulation.tick):
		_celebration()


## The way switch `id` sends the flow: down into its basket when flipped,
## else on along the loop.
func _way(id: String) -> Vector2:
	var state: Dictionary = simulation.object_states.get(id, {})
	if state.get("flipped", false):
		return Vector2.DOWN
	var switch: Dictionary = simulation.level.switches.get(id, {})
	var loop := simulation.level.loop
	if switch.is_empty() or loop == null:
		return Vector2.RIGHT
	var gates: Array = simulation.train.open_gates if simulation.train != null else []
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

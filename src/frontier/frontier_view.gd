class_name FrontierView
extends Node2D
## Draws what the simulation says about the frontier sets (FrontierSets),
## above the level's placeholder boxes: each basket's quota (QuotaDisplay:
## outlines up to 10, quota pies above), filled in the colours of the slimes
## in it (a size-3 slime fills 3), pulsing through the reward, emptying with
## the release and gone once the basket is inert (fired and empty, ux D4 Q10);
## each switch's shut trapdoor and which way it sends the flow; each
## signpost's arrow, the way its switch sends the flow; each gate's box while
## closed and its lid once the old slide entrance is closed; the level's
## one-time celebration (hidden at bedtime, when it stands still); and,
## once it has played, the level's lasting mark at the start of the loop
## (item 23.11). It only reads the simulation. Placeholder art until the
## ui_ux tree settles the look. Place it at the world origin.
## Each basket's slots are instanced draws (ShapeInstances children: the
## filled outlines' discs, one draw per species, then every outline's or
## pie's rim), a basket's pie slices are triangles of this node's own drawing
## (one call for every pie), and the celebration and the mark are drawn on a
## last child (the overlay), so they stay above them.
# @spec-link [[req_switch_basket_gate_set]]
# @spec-link [[req_level_completion_celebration]]

## A quota outline's and a quota pie's rim point counts (antialiased; the
## sizes and widths are QuotaDisplay's).
const OUTLINE_SEGMENTS := 24
const PIE_RIM_SEGMENTS := 48
## How much the reward pulse swells a basket's outlines or pies, and how fast
## (radians a tick).
const PULSE_SWELL := 0.25
const PULSE_RATE := 0.3
const DOOR_COLOR := Color(0.55, 0.45, 0.35)
const GATE_COLOR := Color(0.5, 0.5, 0.6, 0.9)
const ARROW_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const ARROW_LENGTH := 44.0
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

## Per basket id, its slots' instanced draws, children before _overlay:
## Species.COUNT disc draws (the filled outlines of species 0 to 5, each
## coloured its species), then every outline's or pie's rim, made for level
## _slots_level (_sync_slots()).
# @spec-link [[req_platform_and_performance_targets]]
var _slots := {}
var _slots_level: LevelData = null
## Per basket id with pies, its pies' slices and dividers, drawn in one call
## (_pies()), and what they were built from: [the radius, _units_key]. They
## are rebuilt only when that changes, so a frame the celebration redraws
## reuses them.
# @spec-link [[req_platform_and_performance_targets]]
var _pie_draws := {}
## Per basket id, the species filling each unit of its quota
## (QuotaDisplay.unit_species(), -1 empty), from the slimes in it; worked
## out again only when _units_key (the simulation, the level and every
## basket's weight) changes, so not every frame of the reward pulse.
# @spec-link [[req_switch_basket_gate_set]]
var _units := {}
var _units_key := []
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
# @spec-link [[rule_signpost_at_every_fork]]
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
	_refresh_units()
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
	_pie_draws.clear()
	_slots_level = level
	if level == null:
		return
	for id in level.baskets:
		var draws := []
		for species in Species.COUNT:
			var discs := ShapeInstances.new()
			discs.name = "BasketDiscs%d%s" % [_slots.size(), Species.letter(species)]
			discs.self_modulate = Species.color(species)
			add_child(discs)
			draws.append(discs)
		var outlines := ShapeInstances.new()
		outlines.name = "BasketOutlines%d" % _slots.size()
		outlines.self_modulate = QuotaDisplay.OUTLINE_COLOR
		add_child(outlines)
		draws.append(outlines)
		_slots[id] = draws
	move_child(_overlay, -1)


## Basket `id`'s instanced draws: Species.COUNT disc draws (index: the
## species), then the rims (index Species.COUNT) (see _slots).
func basket_slots(id: String) -> Array:
	return _slots[id]


## Basket `id`'s pie slices and dividers as last drawn (see _pie_draws);
## empty when it has no pies or showed none.
func pie_triangles(id: String) -> QuotaDisplay.Triangles:
	return _pie_draws[id][1] if _pie_draws.has(id) else QuotaDisplay.Triangles.new()


## Works out _units again when the simulation, the level or a basket's weight
## changed since the last time: each slime in a basket (SlimeBodies.IN_BASKET)
## belongs to the basket whose box is nearest its centre (holding it: 0), the
## same rule FrontierSets weighs them by, and fills its units in ascending id
## order. The weights then match the units filled, as FrontierSets sets
## every basket's weight from the slimes in it each tick.
# @spec-link [[req_switch_basket_gate_set]]
func _refresh_units() -> void:
	var level := simulation.level
	var key := [simulation.get_instance_id(), level.get_instance_id()]
	for id in level.baskets:
		key.append((simulation.object_states.get(id, {}) as Dictionary).get("weight", 0))
	if key == _units_key:
		return
	_units_key = key
	var ids := PackedStringArray(level.baskets.keys())
	ids.sort()
	var species := {}
	var sizes := {}
	for id in ids:
		species[id] = PackedInt32Array()
		sizes[id] = PackedInt32Array()
	var bodies := simulation.slimes
	for s in bodies.slime_count:
		if bodies.state[s] != SlimeBodies.IN_BASKET:
			continue
		var id := _basket_nearest(level, ids, bodies.centre_of(bodies.id[s]))
		species[id].append(bodies.species[s])
		sizes[id].append(bodies.size[s])
	_units.clear()
	for id in ids:
		_units[id] = QuotaDisplay.unit_species(level.baskets[id]["quota"], species[id], sizes[id])


## Of baskets `ids` (sorted) of `level`, the one whose box is nearest `at`
## (0 inside it), the first on a tie.
static func _basket_nearest(level: LevelData, ids: PackedStringArray, at: Vector2) -> String:
	var best := ""
	var best_gap := INF
	for id in ids:
		var box: Rect2 = level.baskets[id]["box"]
		var gap := at.distance_to(at.clamp(box.position, box.end))
		if gap < best_gap:
			best_gap = gap
			best = id
	return best


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


## Basket `basket` (id `id`, state `state`)'s quota (QuotaDisplay): its
## outlines or pies in a row above its box, filled from the first by the
## slimes in it (_units), each unit in its slime's species colour, swelling
## with the reward pulse; nothing once the basket is inert (FIRED and empty:
## its release done). The outlines are instanced draws, the filled ones'
## discs then every outline (draw_circle()'s, draw_arc()'s), where each slot
## drew its disc then its outline: the same picture while a slot's outline
## (its reach) stays clear of the next slot's disc (at rest the gap is
## OUTLINE_GAP + OUTLINE_RADIUS minus the outline's half width and feather,
## about 6 px). The reward pulse swells them until it doesn't, and then they
## are drawn slot by slot, as before. A pie's slices and dividers are one
## triangle list (_pie_draws), its rim in the rims' instanced draw.
# @spec-link [[req_switch_basket_gate_set]]
# @spec-link [[req_platform_and_performance_targets]]
func _basket(id: String, basket: Dictionary, state: Dictionary) -> void:
	var quota: int = basket["quota"]
	var phase: String = state.get("phase", FrontierSets.FILLING)
	var units: PackedInt32Array = _units[id]
	var draws: Array = _slots[id]
	for node: ShapeInstances in draws:
		node.clear()
	var inert := phase == FrontierSets.FIRED and (units.is_empty() or units[0] < 0)
	if inert:
		_pie_draws.erase(id)
	else:
		var pulse := 1.0
		if phase == FrontierSets.REWARD:
			pulse += PULSE_SWELL * sin(float(simulation.tick - int(state.get("since", 0))) * PULSE_RATE)
		var radius := QuotaDisplay.radius(quota) * pulse
		var centres := QuotaDisplay.centres(basket["box"], quota)
		if QuotaDisplay.uses_pies(quota):
			_pies(id, quota, centres, radius, units, draws[Species.COUNT])
		else:
			_outlines(quota, centres, radius, units, draws)
	for node: ShapeInstances in draws:
		node.commit()


## A basket's quota outlines at `centres`, of radius `radius`, unit k filled
## by species `units[k]` (-1: empty), into its instanced draws `draws` (see
## _basket()).
func _outlines(quota: int, centres: PackedVector2Array, radius: float, units: PackedInt32Array,
		draws: Array) -> void:
	var outlines: ShapeInstances = draws[Species.COUNT]
	outlines.set_ring(radius, QuotaDisplay.OUTLINE_WIDTH, OUTLINE_SEGMENTS, true)
	if radius + outlines.reach >= QuotaDisplay.step(quota):
		for k in quota:
			if units[k] >= 0:
				draw_circle(centres[k], radius, Species.color(units[k]))
			draw_arc(centres[k], radius, 0.0, TAU, OUTLINE_SEGMENTS, QuotaDisplay.OUTLINE_COLOR,
					QuotaDisplay.OUTLINE_WIDTH, true)
		return
	for k in quota:
		if units[k] >= 0:
			var discs: ShapeInstances = draws[units[k]]
			discs.set_disc(radius)
			discs.add(centres[k])
		outlines.add(centres[k])


## A basket's quota pies at `centres`, of radius `radius`, slice k (counted
## across the pies) filled by species `units[k]` (-1: empty): the slices and
## dividers as one triangle list (built again only when the radius or
## _units_key changed, _pie_draws), the rims into `rims`.
func _pies(id: String, quota: int, centres: PackedVector2Array, radius: float,
		units: PackedInt32Array, rims: ShapeInstances) -> void:
	rims.set_ring(radius, QuotaDisplay.PIE_RIM_WIDTH, PIE_RIM_SEGMENTS, true)
	var slices := QuotaDisplay.groups(quota)
	for g in slices.size():
		rims.add(centres[g])
	var key := [radius, _units_key]
	if not _pie_draws.has(id) or _pie_draws[id][0] != key:
		var triangles := QuotaDisplay.Triangles.new()
		if _pie_draws.has(id):
			triangles = _pie_draws[id][1]
			triangles.clear()
		var first := 0
		for g in slices.size():
			triangles.add_pie(centres[g], radius, slices[g], units, first)
			first += slices[g]
		_pie_draws[id] = [key, triangles]
	var drawn: QuotaDisplay.Triangles = _pie_draws[id][1]
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), drawn.indices, drawn.points, drawn.colors)


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

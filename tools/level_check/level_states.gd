class_name LevelStates
extends RefCounted
## A level's gate states, for the tools (the level-rules checker, the
## fixture maker): the level as the loop first reaches section n, with the
## gates before it open as after their baskets fired. Generic: the gates
## come from the loop's return routes, the baskets from the level's rules and
## the switches from the baskets they point at, never from stable-ID names.
# @spec-link [[req_switch_basket_gate_set]]


## The gates open once the loop reaches `section`: the gates of the return
## routes of the sections before it (LoopData segment "gate"), in loop
## order. A return route with no gate adds none.
static func gates_before(data: LevelData, section: int) -> Array:
	var gates := []
	if data == null or data.loop == null:
		return gates
	for segment in data.loop.segments:
		if segment["kind"] == LoopData.RETURN and segment["section"] < section:
			var gate: String = segment["gate"]
			if not gate.is_empty() and not gate in gates:
				gates.append(gate)
	return gates


## The basket whose rule opens `gate` ("when basket full -> then gate
## open", data.rules), or "".
static func basket_opening(data: LevelData, gate: String) -> String:
	for rule in data.rules:
		var then: Dictionary = rule.get("then", {})
		var when: Dictionary = rule.get("when", {})
		if then.get("object", "") == gate and then.get("action", "") == "open" \
				and when.get("event", "") == "full" and data.baskets.has(when.get("object", "")):
			return when["object"]
	return ""


## The switch pointing at `basket` (data.switches[..]["basket"]), or "" (the
## smaller ID when several do).
static func switch_of(data: LevelData, basket: String) -> String:
	var ids := data.switches.keys()
	ids.sort()
	for id in ids:
		if data.switches[id]["basket"] == basket:
			return id
	return ""


## Opens `gates` in `sim` as after their baskets fired: for each gate, its
## basket's switch flipped with its trapdoor shut, the basket FIRED since
## tick 0, the gate open with its old entrance closed; then the train's
## loop grows through them. Returns the problems (a gate no basket's rule
## opens, a basket no switch points at), empty when every gate opened.
static func open_gates(sim: Simulation, data: LevelData, gates: Array) -> PackedStringArray:
	var problems := PackedStringArray()
	for gate in gates:
		var basket := basket_opening(data, gate)
		if basket.is_empty():
			problems.append("no basket's rule opens gate %s" % gate)
		else:
			var switch := switch_of(data, basket)
			if switch.is_empty():
				problems.append("no switch points at basket %s (it opens gate %s)" % [basket, gate])
			else:
				sim.object_states[switch]["flipped"] = true
				sim.object_states[switch]["trapdoor_shut"] = true
			sim.object_states[basket]["phase"] = FrontierSets.FIRED
			sim.object_states[basket]["since"] = 0
		if sim.gate_states.has(gate):
			sim.gate_states[gate]["open"] = true
			sim.gate_states[gate]["entrance_closed"] = true
	sim.train.set_open_gates(gates)
	return problems


## A fresh simulation of the level (the first slime awake, every sleeper
## asleep), on its baked `terrain`, seeded with `run_seed`: the game's
## state with no save.
static func fresh_simulation(level_data: LevelData, terrain: TerrainSegments, run_seed: int) -> Simulation:
	var sim := Simulation.new(run_seed)
	sim.slimes.terrain = terrain
	sim.load_level(level_data)
	return sim

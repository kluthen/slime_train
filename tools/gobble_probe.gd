extends SceneTree
## The gobble probe (O91): slimes that can't fuse lodged inside each other,
## found headless on a test-level fixture stepped with the game's own step
## (game.step_simulation, as --run-ticks does). Read only: the final STATE
## hash is a plain run's. Not a test.
##
## Run:   godot --headless --no-header --path . -s res://tools/gobble_probe.gd --
##            [--fixture=s3-basket-59of60] [--seed=1] [--ticks=18000]
##            [--every=10] [--tick=native|gdscript]
##
## Every tick, each slime's last event is recorded: born (a new id: a split
## or a creation), unpark, park, a state change, a calm change, a jump (its
## centre moved more than JUMP px in one tick: a teleport). Every --every
## ticks, every pair of simulated (not parked) slimes that can't fuse (another species, or sizes
## adding up past SlimeBodies.MAX_SIZE) is checked: it overlaps when its
## centres are closer than CLOSE_SHARE of the smaller ring radius, or when
## INSIDE_SHARE of the smaller ring's points are inside the other's ring.
##
## Output:
##   GOBBLE_START  a pair starts overlapping: tick, ids, species, sizes,
##                 states, calms, distance, inside share, each one's last event
##   GOBBLE_END    a pair stops overlapping: tick, ids, how long (ticks), the
##                 deepest share seen, whether the stuck rule moved one
##   GOBBLE_TOT    totals: overlaps, the longest, those lasting LONG ticks or
##                 more, stuck moves logged, the fastest simulated slime at a
##                 check and the checks with one faster than FAST (pops)
##   STATE         the final tick and state hash

const CLOSE_SHARE := 0.5
const INSIDE_SHARE := 0.5
const JUMP := 40.0
## An overlap lasting this many ticks or more counts as lasting.
const LONG := 120
## A simulated slime faster than this at a check counts (a pop), px/s.
const FAST := 900.0

var fixture := "s3-basket-59of60"
var seed_n := 1
var ticks := 18000
var every := 10
var tick_arg := ""
## Ticks at which every slime is printed (GOBBLE_SNAP), --snap=T[,T...].
var snaps := PackedInt32Array()

## id -> [tick, kind, detail]
var _last := {}
## id -> [centre, calm, state]
var _seen := {}
## Vector2i pair -> {"since", "deep", "close"}
var _open := {}
var _total := 0
var _long := 0
var _longest := 0
## The fastest simulated slime seen at a check, px/s, and the checks where
## one went faster than FAST.
var _top_speed := 0.0
var _fast_checks := 0


func _initialize() -> void:
	var problem := _parse()
	if problem != "":
		printerr("gobble_probe: ", problem)
		quit(2)
		return
	var game: Node = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var args := ["--test-mode", "--level=test", "--fixture=" + fixture, "--seed=%d" % seed_n]
	var parsed: Dictionary = load("res://src/test_mode/test_mode.gd").config_from_args(PackedStringArray(args))
	if not parsed["errors"].is_empty():
		printerr("gobble_probe: ", parsed["errors"])
		quit(2)
		return
	var errs: PackedStringArray = game.enable_test_mode(parsed["config"])
	if not errs.is_empty():
		printerr("gobble_probe: ", errs)
		quit(2)
		return
	_run(game)
	quit(0)


## Reads the user arguments; returns the problem, or "" when all are valid.
func _parse() -> String:
	for arg in OS.get_cmdline_user_args():
		var p := arg.trim_prefix("--").split("=", true, 1)
		if p.size() != 2:
			return "expected --name=value, got '%s'" % arg
		match p[0]:
			"fixture":
				fixture = p[1]
			"seed":
				seed_n = int(p[1])
			"ticks":
				ticks = int(p[1])
			"every":
				every = maxi(int(p[1]), 1)
			"tick":
				tick_arg = p[1]
			"snap":
				for t in p[1].split(","):
					snaps.append(int(t))
			_:
				return "unknown argument '%s'" % arg
	return ""


## Steps `game` for `ticks` ticks, recording events every tick and checking
## pairs every `every` ticks (see the class doc).
func _run(game: Node) -> void:
	var sim: Simulation = game.simulation
	var bodies: SlimeBodies = sim.slimes
	print("GOBBLE fixture=%s seed=%d tick0=%d slimes=%d native=%s" % [fixture, seed_n, sim.tick,
			bodies.slime_count, bodies.uses_native()])
	_record(sim)
	var stuck_moves := 0
	for i in ticks:
		game.step_simulation()
		_record(sim)
		for e in sim.stuck_slimes.stuck:
			if e["tick"] == sim.tick - 1 and e["moved"]:
				stuck_moves += 1
				print("GOBBLE_STUCK tick=%d id=%d other=%d" % [e["tick"], e["id"], e["other"]])
		if sim.tick % every == 0:
			_check(sim)
		if sim.tick in snaps:
			_snap(sim)
	for pair: Vector2i in _open:
		_end(sim, pair, true)
	print("GOBBLE_TOT tick=%d overlaps=%d lasting=%d longest=%d stuck_moves=%d top_speed=%.0f fast_checks=%d" % [
			sim.tick, _total, _long, _longest, stuck_moves, _top_speed, _fast_checks])
	print("STATE tick=%d hash=%s" % [sim.tick, sim.state_hash()])


## Records each slime's last event this tick (see the class doc).
func _record(sim: Simulation) -> void:
	var bodies := sim.slimes
	var now := {}
	for s in bodies.slime_count:
		var sid := bodies.id[s]
		var c := bodies.centre_of(sid)
		var cl := int(bodies.calm[s])
		var st := int(bodies.state[s])
		now[sid] = [c, cl, st]
		if not _seen.has(sid):
			_last[sid] = [sim.tick, "born", "at %s size %d" % [_v(c), bodies.size[s]]]
			continue
		var was: Array = _seen[sid]
		if was[1] != cl:
			var kind := "calm"
			if cl == SlimeBodies.PARKED:
				kind = "park"
			elif was[1] == SlimeBodies.PARKED:
				kind = "unpark"
			_last[sid] = [sim.tick, kind, "%s->%s at %s" % [SlimeBodies.CALM_NAMES[was[1]],
					SlimeBodies.CALM_NAMES[cl], _v(c)]]
		if was[2] != st:
			_last[sid] = [sim.tick, "state", "%s->%s at %s" % [SlimeBodies.STATE_NAMES[was[2]],
					SlimeBodies.STATE_NAMES[st], _v(c)]]
		var d: float = (c - was[0]).length()
		if d > JUMP:
			_last[sid] = [sim.tick, "jump", "%.0f px %s->%s (%s)" % [d, _v(was[0]), _v(c),
					SlimeBodies.CALM_NAMES[cl]]]
	_seen = now


## Checks every pair that can't fuse (see the class doc).
func _check(sim: Simulation) -> void:
	var bodies := sim.slimes
	var n := bodies.slime_count
	var found := {}
	var cs := PackedVector2Array()
	cs.resize(n)
	var top := 0.0
	for s in n:
		cs[s] = bodies.centre_of(bodies.id[s])
		if bodies.calm[s] == SlimeBodies.ACTIVE:
			top = maxf(top, bodies.velocity_of(bodies.id[s]).length())
	_top_speed = maxf(_top_speed, top)
	if top > FAST:
		_fast_checks += 1
	for s in n:
		if bodies.calm[s] == SlimeBodies.PARKED:
			continue
		for t in range(s + 1, n):
			if bodies.calm[t] == SlimeBodies.PARKED:
				continue
			if bodies.species[s] == bodies.species[t] and bodies.size[s] + bodies.size[t] <= SlimeBodies.MAX_SIZE:
				continue
			var rs := minf(bodies.ring_radius[s], bodies.ring_radius[t])
			var d := cs[s].distance_to(cs[t])
			if d > bodies.ring_radius[s] + bodies.ring_radius[t]:
				continue
			var small := s if bodies.ring_radius[s] <= bodies.ring_radius[t] else t
			var big := t if small == s else s
			var share := _inside(bodies, small, big)
			if d >= rs * CLOSE_SHARE and share < INSIDE_SHARE:
				continue
			var pair := Vector2i(bodies.id[s], bodies.id[t])
			found[pair] = true
			if not _open.has(pair):
				_open[pair] = {"since": sim.tick, "deep": share, "close": d}
				_total += 1
				print("GOBBLE_START tick=%d a=%s b=%s d=%.1f inside=%.2f" % [sim.tick,
						_who(bodies, s), _who(bodies, t), d, share])
			else:
				_open[pair]["deep"] = maxf(_open[pair]["deep"], share)
				_open[pair]["close"] = minf(_open[pair]["close"], d)
	for pair: Vector2i in _open.keys():
		if not found.has(pair):
			_end(sim, pair, false)


## Closes `pair`'s overlap (`still`: open at the run's end).
func _end(sim: Simulation, pair: Vector2i, still: bool) -> void:
	var o: Dictionary = _open[pair]
	var lasted: int = sim.tick - o["since"]
	_longest = maxi(_longest, lasted)
	if lasted >= LONG:
		_long += 1
	print("GOBBLE_END tick=%d ids=%d,%d lasted=%d deep=%.2f closest=%.1f%s" % [sim.tick, pair.x, pair.y,
			lasted, o["deep"], o["close"], " (still open)" if still else ""])
	if not still:
		_open.erase(pair)


## The share of slime `a`'s ring points inside `b`'s ring (indices).
func _inside(bodies: SlimeBodies, a: int, b: int) -> float:
	var ring := bodies.pos.slice(bodies.first[b], bodies.first[b] + bodies.npts[b])
	var inside := 0
	for j in range(bodies.first[a], bodies.first[a] + bodies.npts[a]):
		if Geometry2D.is_point_in_polygon(bodies.pos[j], ring):
			inside += 1
	return float(inside) / bodies.npts[a]


## One slime as text: id, species, size, state, calm, held, last event.
func _who(bodies: SlimeBodies, s: int) -> String:
	var sid := bodies.id[s]
	return "[id=%d sp=%d sz=%d %s/%s held=%d last=%s]" % [sid, bodies.species[s], bodies.size[s],
			SlimeBodies.STATE_NAMES[bodies.state[s]], SlimeBodies.CALM_NAMES[bodies.calm[s]], bodies.held[s],
			str(_last.get(sid, []))]


## Prints every slime (GOBBLE_SNAP): id, species, size, state, calm, held,
## supported, centre, velocity, train distance (-1: not tracked).
func _snap(sim: Simulation) -> void:
	var bodies := sim.slimes
	for s in bodies.slime_count:
		var sid := bodies.id[s]
		var dist := sim.train.distance_of(sid) if sim.train.tracks(sid) else -1.0
		print("GOBBLE_SNAP tick=%d id=%d sp=%d sz=%d %s/%s held=%d sup=%d c=%s v=%s dist=%.1f n=%d last=%s" % [
				sim.tick, sid, bodies.species[s], bodies.size[s], SlimeBodies.STATE_NAMES[bodies.state[s]],
				SlimeBodies.CALM_NAMES[bodies.calm[s]], bodies.held[s], bodies.supported[s],
				_v(bodies.centre_of(sid)), _v(bodies.velocity_of(sid)), dist, bodies.npts[s],
				str(_last.get(sid, []))])


static func _v(p: Vector2) -> String:
	return "(%.0f,%.0f)" % [p.x, p.y]

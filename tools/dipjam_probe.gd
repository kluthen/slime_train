extends SceneTree
## EXPERIMENT (exp/dip-jam): the train's dip-nudge jam, measured headless on
## a test-level fixture stepped with the game's own step
## (game.step_simulation, as --run-ticks does). Read only: the final STATE
## hash is a plain run's. The variant comes from SLIME_DIPJAM (Fusion.jam_v1,
## jam_v2; Train.jam_v4), the tick from SLIME_TICK. Not a test.
##
## Run:   SLIME_DIPJAM=v3 godot --headless --no-header --path . -s res://tools/dipjam_probe.gd --
##            [--fixture=stress-dense] [--seed=1] [--ticks=3600] [--late-from=0]
##            [--hold-view=X,Y --hold-from=T]
##
## --hold-view pins the camera there after every step from tick --hold-from
## on (default 0), as exp/geyser's probe does: the idle camera chases slimes
## away from the loop's start and parks the queue (Offscreen), which moves
## then at the off-screen pace, so the flow measured depends on the camera.
## For s3-basket-59of60: 720,361 from 9000 (from 0, basket 3 never fires).
##
## Output (one line each):
##   DJ        fixture, seed, variant, tick kind
##   DJ_CEN    every WINDOW ticks: the train slimes the dip nudge holds now,
##             gathering and holding; active train slimes
##   DJ_TOT    hops (train hops taken), short (their share landing short,
##             Train's counter), adv_med (median progress advance of the
##             landed train hops, px), gather_mean / gather_max (train slimes
##             held by gathering, per tick), hold_mean, speed (mean progress
##             speed of the active train slimes, px/s), front (the front-most
##             active train slime at each window's start: its advance over the
##             window, px/s, mean over windows), slow (share of the train
##             slimes active through a window that advanced less than SLOW px
##             in it), fus_min (fusions per minute), bumps, creep (share of
##             grounded slope ticks, see CREEP, a train slime between hops
##             slides back faster than CREEP_SPEED), creep_v (their mean back
##             speed, px/s), stall, stuck
##   DJ_LATE   from --late-from on, per WINDOW ticks: arr (laps completed:
##             the return route's end), x240 and x750 (forward crossings of
##             those loop distances: the train's flow off the loop's start)
##   STATE     the final tick and state hash
# @spec-link [[req_platform_and_performance_targets]]

const WINDOW := 600
## A progress step bigger than this (px) is no move along the loop (a move
## to the start, a new record): not counted.
const MAX_STEP := 400.0
## A train slime advancing less than this over a window is slow, px.
const SLOW := 60.0
## The slope range (rise over run) the creep is measured on, and the back
## speed along the route that counts as creeping, px/s.
const CREEP_FROM := 0.2
const CREEP_SPEED := 5.0
const CROSS_AT := [240.0, 750.0]

var fixture := "stress-dense"
var seed_n := 1
var ticks := 3600
var late_from := 0
var hold_view := Vector2.INF
var hold_from := 0


func _initialize() -> void:
	var problem := _parse()
	if problem != "":
		printerr("dipjam_probe: ", problem)
		quit(2)
		return
	var game: Node = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var parsed: Dictionary = load("res://src/test_mode/test_mode.gd").config_from_args(PackedStringArray(
			["--test-mode", "--level=test", "--fixture=" + fixture, "--seed=%d" % seed_n]))
	if not parsed["errors"].is_empty():
		printerr("dipjam_probe: ", parsed["errors"])
		quit(2)
		return
	var errs: PackedStringArray = game.enable_test_mode(parsed["config"])
	if not errs.is_empty():
		printerr("dipjam_probe: ", errs)
		quit(2)
		return
	_run(game)
	quit(0)


## Reads the user arguments; returns the problem, or "" when valid.
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
			"late-from":
				late_from = int(p[1])
			"hold-view":
				var xy := p[1].split(",")
				hold_view = Vector2(float(xy[0]), float(xy[1]))
			"hold-from":
				hold_from = int(p[1])
			_:
				return "unknown argument '%s'" % arg
	return ""


## Steps `game` for `ticks` ticks and prints the measures (see the class doc).
func _run(game: Node) -> void:
	var sim: Simulation = game.simulation
	var train: Train = sim.train
	var bodies: SlimeBodies = sim.slimes
	var fusion: Fusion = sim.fusion
	print("DJ fixture=%s seed=%d variant=%s tick=%s tick0=%d slimes=%d hold=%s from %d" % [fixture, seed_n,
			OS.get_environment("SLIME_DIPJAM"), "native" if bodies.uses_native() else "gdscript", sim.tick,
			bodies.slime_count, hold_view, hold_from])
	var hops0 := train.hops_taken
	var short0 := train.short_hops_taken
	var fused0 := fusion.fused_count
	var bumped0 := fusion.bumped_count
	var prog := {}
	var dist := {}
	var laps := {}
	var landed_seen := {}
	var advances := PackedFloat32Array()
	var gather_sum := 0
	var gather_max := 0
	var hold_sum := 0
	var speed_sum := 0.0
	var speed_n := 0
	var win_start := {}  # id -> progress at the window's start (active then)
	var win_active := {}  # id -> active every tick of the window so far
	var front_id := -1
	var front_from := 0.0
	var front_rates := PackedFloat32Array()
	var slow := 0
	var slow_n := 0
	var slope_ticks := 0
	var creep_ticks := 0
	var creep_v := 0.0
	var stall := 0
	var stuck := 0
	var late_arr := 0
	var late_cross := PackedInt32Array([0, 0])
	var late_windows := 0
	for i in ticks:
		if sim.tick % WINDOW == 0:
			_window_start(sim, win_start, win_active)
			front_id = _front(sim)
			front_from = train.progress_of(front_id) if front_id >= 0 else 0.0
		game.step_simulation()
		if hold_view != Vector2.INF and sim.tick >= hold_from:
			sim.camera.position = hold_view
		var t := sim.tick - 1
		var gathering := 0
		for why: String in fusion.nudged.values():
			if why == Fusion.NUDGE_GATHERING:
				gathering += 1
		gather_sum += gathering
		gather_max = maxi(gather_max, gathering)
		hold_sum += fusion.nudged.size() - gathering
		for id in train.tracked_ids():
			var s := bodies.index_of(id)
			var active := s >= 0 and bodies.state[s] == SlimeBodies.TRAIN and bodies.calm[s] != SlimeBodies.PARKED
			var p := train.progress_of(id)
			var d := train.distance_of(id)
			if prog.has(id) and active:
				var step: float = p - prog[id]
				if step >= 0.0 and step < MAX_STEP:
					speed_sum += step
					speed_n += 1
			if not active and win_active.has(id):
				win_active.erase(id)
			if t >= late_from:
				if laps.has(id) and train.laps_of(id) > laps[id]:
					late_arr += 1
				if dist.has(id):
					var was: float = dist[id]
					if d >= was and d - was < MAX_STEP:
						for c in CROSS_AT.size():
							if was < CROSS_AT[c] and d >= CROSS_AT[c]:
								late_cross[c] += 1
			prog[id] = p
			dist[id] = d
			laps[id] = train.laps_of(id)
			if active and bodies.supported[s] != 0 and not train.in_air(id) and bodies.hop_timer[s] > 0.05:
				var along := train.direction_at(d)
				if absf(along.y) > absf(along.x) * CREEP_FROM and absf(along.y) <= absf(along.x) * Train.GRIP_MAX_SLOPE:
					slope_ticks += 1
					var back := -bodies.velocity_of(id).dot(along)
					if back > CREEP_SPEED:
						creep_ticks += 1
						creep_v += back
		for id: int in train.last_hops:
			var last: Dictionary = train.last_hops[id]
			if last["landed"] >= 0 and landed_seen.get(id, -2) != last["landed"]:
				landed_seen[id] = last["landed"]
				advances.append(last["advance"])
		for e in train.stalled:
			if e["tick"] == t:
				stall += 1
		for e in sim.stuck_slimes.stuck:
			if e["tick"] == t and e["moved"]:
				stuck += 1
		if sim.tick % WINDOW == 0:
			var counts := _window_end(sim, win_start, win_active)
			slow += counts.x
			slow_n += counts.y
			if front_id >= 0 and train.tracks(front_id):
				var gain := train.progress_of(front_id) - front_from
				if gain >= 0.0:
					front_rates.append(gain / (WINDOW / 60.0))
			if t >= late_from:
				late_windows += 1
			var active_n := 0
			for id in train.tracked_ids():
				var s := bodies.index_of(id)
				if s >= 0 and bodies.calm[s] != SlimeBodies.PARKED:
					active_n += 1
			print("DJ_CEN tick=%d gathering=%d holding=%d active_train=%d" % [sim.tick, gathering,
					fusion.nudged.size() - gathering, active_n])
	advances.sort()
	var minutes := ticks / 3600.0
	var hops := train.hops_taken - hops0
	print(("DJ_TOT hops=%d short=%.2f adv_med=%.1f gather_mean=%.1f gather_max=%d hold_mean=%.1f speed=%.1f"
			+ " front=%.1f slow=%.2f fus_min=%.2f bumps=%d creep=%.2f creep_v=%.1f stall=%d stuck=%d") % [
			hops, float(train.short_hops_taken - short0) / maxi(hops, 1),
			advances[advances.size() / 2] if not advances.is_empty() else 0.0,
			float(gather_sum) / ticks, gather_max, float(hold_sum) / ticks, speed_sum / maxi(speed_n, 1) * 60.0,
			_mean(front_rates), float(slow) / maxi(slow_n, 1), (fusion.fused_count - fused0) / minutes,
			fusion.bumped_count - bumped0, float(creep_ticks) / maxi(slope_ticks, 1),
			creep_v / maxi(creep_ticks, 1), stall, stuck])
	var per := maxf(late_windows, 1.0)
	print("DJ_LATE from=%d windows=%d arr=%.1f x240=%.1f x750=%.1f" % [late_from, late_windows, late_arr / per,
			late_cross[0] / per, late_cross[1] / per])
	print("STATE tick=%d hash=%s" % [sim.tick, sim.state_hash()])


## The active train slimes' progress at a window's start.
func _window_start(sim: Simulation, start: Dictionary, active: Dictionary) -> void:
	start.clear()
	active.clear()
	for id in sim.train.tracked_ids():
		var s := sim.slimes.index_of(id)
		if s >= 0 and sim.slimes.state[s] == SlimeBodies.TRAIN and sim.slimes.calm[s] != SlimeBodies.PARKED:
			start[id] = sim.train.progress_of(id)
			active[id] = true


## At a window's end: (slow, counted) of the train slimes active all through it.
func _window_end(sim: Simulation, start: Dictionary, active: Dictionary) -> Vector2i:
	var out := Vector2i.ZERO
	for id: int in active:
		if not sim.train.tracks(id):
			continue
		var gain: float = sim.train.progress_of(id) - start[id]
		if gain < 0.0:
			continue
		out.y += 1
		if gain < SLOW:
			out.x += 1
	return out


## The front-most active train slime (the largest progress), or -1.
func _front(sim: Simulation) -> int:
	var best := -1
	var best_p := -INF
	for id in sim.train.tracked_ids():
		var s := sim.slimes.index_of(id)
		if s < 0 or sim.slimes.state[s] != SlimeBodies.TRAIN or sim.slimes.calm[s] == SlimeBodies.PARKED:
			continue
		var p := sim.train.progress_of(id)
		if p > best_p:
			best_p = p
			best = id
	return best


static func _mean(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxi(values.size(), 1)

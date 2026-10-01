extends SceneTree
## Throwaway probe (22e calibration sweep). Loads a fixture in test mode
## (seed 1), steps it TICKS ticks and summarises: Physics (crowd_count) mean/max,
## resting mean, largest awake cluster mean/max (sampled once a second),
## holders mean/max, resting train slimes mean, train hops / short hops,
## stalled count, and the wall time of the steps alone (probe work excluded).
## --parts: replicates Simulation.step() with a timer around each part
## (same calls, same order) and prints the mean us per tick of each.
## godot --headless --path <wt> -s probe_calib.gd -- --fixture=stress-moving [--ticks=2400] [--parts]

var fixture := "stress-moving"
var ticks := 2400
var parts := false
var part_us := {}


func _t(name: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	part_us[name] = part_us.get(name, 0) + (now - t0)
	return now


func _timed_step(game: Node) -> void:
	var sim: Simulation = game.simulation
	game.sync_view()
	sim.session.read_clock(game.test_mode.clock_at(sim.tick))
	for event in game.test_mode.inputs_for_tick(sim.tick):
		sim.push_input(event)
	var t := Time.get_ticks_usec()
	for event in sim._pending_input:
		sim._apply_input(event)
	sim._pending_input.clear()
	sim.session.advance(sim)
	t = _t("session", t)
	sim.offscreen.step(sim)
	t = _t("offscreen", t)
	var gates: Array = sim.train.open_gates if sim.train != null else []
	if sim.train != null:
		sim.train.steer(sim.slimes, Simulation.TICK_SECONDS, sim.tick, sim.fusion)
	t = _t("train.steer", t)
	sim.free_slimes.steer(sim.slimes, Simulation.TICK_SECONDS, sim.level, gates)
	t = _t("free.steer", t)
	sim.slimes.free_down = sim.phone_tilt.down()
	sim.slimes.tick(Simulation.TICK_SECONDS)
	t = _t("bodies.tick", t)
	Sleepers.wake(sim)
	sim.free_slimes.paced(sim.slimes)
	sim._face_hops()
	for p in sim.split_zones.apply(sim.slimes):
		sim.identities.split(p)
		if sim.train != null:
			sim.train.inherit(p)
		sim.free_slimes.inherit(p, sim.tick)
	t = _t("wake+split", t)
	sim.fusion.step(sim)
	t = _t("fusion", t)
	sim.frontier.step(sim)
	t = _t("frontier", t)
	gates = sim.train.open_gates if sim.train != null else []
	sim.free_slimes.follow(sim.slimes, sim.tick, sim.level, gates)
	t = _t("free.follow", t)
	if sim.train != null:
		sim.train.follow(sim.slimes, sim.tick)
	t = _t("train.follow", t)
	sim.stuck_slimes.step(sim)
	sim.camera.watch(sim.slimes, not sim.fingers_down.is_empty(), sim.screensaver, sim.session.phase == Session.BEDTIME)
	for gate_id in sim.frontier.gates_fired_open(sim):
		sim.camera.show_gate(sim.level.gates[gate_id]["box"], sim.view, sim.level.loop, gates, sim.tick)
	sim.camera.step(sim.level.loop if sim.level != null else null, gates, Simulation.TICK_SECONDS, sim.tick)
	sim._tidy()
	sim.tick += 1
	sim.hint.update(sim.tick)
	t = _t("stuck+camera+tidy", t)
	assert(not sim.session.save_due)


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var p := arg.trim_prefix("--").split("=", true, 1)
		if p[0] == "fixture": fixture = p[1]
		if p[0] == "ticks": ticks = int(p[1])
		if p[0] == "parts": parts = true
	var game: Node = load("res://src/main.tscn").instantiate()
	game.save_store = null
	root.add_child(game)
	await process_frame
	var errs = game.enable_test_mode({"seed": 1, "time_scale": 0, "fixture": fixture})
	if not errs.is_empty():
		print("ERR ", errs)
		quit(1)
		return
	var sim: Simulation = game.simulation
	var b: SlimeBodies = sim.slimes
	print("fixture=%s tick0=%d slimes=%d consts=(%d, %.0f, %.0f) parts=%s" % [fixture, sim.tick, b.slime_count,
			Train.HOLD_CROWD, Train.HOLD_CROWD_RADIUS, Train.JAM_GAP, parts])
	var hops0: int = sim.train.hops_taken
	var short0: int = sim.train.short_hops_taken
	var stalled0: int = sim.train.stalled.size()
	var step_us := 0
	var phys_sum := 0; var phys_max := 0
	var rest_sum := 0
	var hold_sum := 0; var hold_max := 0
	var trest_sum := 0
	var cl_sum := 0; var cl_max := 0; var cl_n := 0
	var hold_secs_nonzero := 0
	var last_hops := hops0
	var zero_hop_secs := 0
	var hold_began := {}  # id -> tick the hold began
	var ends_cap := 0; var ends_recheck := 0; var ends_other := 0; var dur_sum := 0
	for t in ticks:
		var t0 := Time.get_ticks_usec()
		if parts:
			_timed_step(game)
		else:
			game.step_simulation()
		step_us += Time.get_ticks_usec() - t0
		var phys := b.crowd_count()
		phys_sum += phys; phys_max = maxi(phys_max, phys)
		var rest := 0; var holding := 0; var trest := 0
		for s in b.slime_count:
			if b.calm[s] == SlimeBodies.RESTING:
				rest += 1
			if b.state[s] == SlimeBodies.TRAIN:
				if sim.train.is_holding(b.id[s]):
					holding += 1
				if b.calm[s] == SlimeBodies.RESTING:
					trest += 1
		var now_holding := {}
		for s in b.slime_count:
			if b.state[s] == SlimeBodies.TRAIN and sim.train.is_holding(b.id[s]):
				now_holding[b.id[s]] = sim.train.hold_began_at(b.id[s])
		for i in hold_began:
			if not now_holding.has(i) or now_holding[i] != hold_began[i]:
				var dur: int = sim.tick - hold_began[i]
				dur_sum += dur
				if b.index_of(i) < 0 or b.state[b.index_of(i)] != SlimeBodies.TRAIN:
					ends_other += 1
				elif dur >= Train.HOLD_CAP_TICKS:
					ends_cap += 1
				else:
					ends_recheck += 1
		hold_began = now_holding
		rest_sum += rest; hold_sum += holding; hold_max = maxi(hold_max, holding); trest_sum += trest
		if (t + 1) % 60 == 0:
			var cl := DebugCounts.largest_cluster(b)
			cl_sum += cl; cl_max = maxi(cl_max, cl); cl_n += 1
			if sim.train.hops_taken == last_hops:
				zero_hop_secs += 1
			last_hops = sim.train.hops_taken
	var hops: int = sim.train.hops_taken - hops0
	var short: int = sim.train.short_hops_taken - short0
	print("RESULT fixture=%s consts=(%d,%.0f,%.0f) physics_mean=%.1f physics_max=%d resting_mean=%.1f cluster_mean=%.1f cluster_max=%d holders_mean=%.2f holders_max=%d train_resting_mean=%.2f hops=%d short=%d short_share=%.1f stalled=%d zero_hop_secs=%d bodies_end=%d wall_ms=%d"
			% [fixture, Train.HOLD_CROWD, Train.HOLD_CROWD_RADIUS, Train.JAM_GAP, phys_sum / float(ticks), phys_max,
			rest_sum / float(ticks), cl_sum / float(cl_n), cl_max, hold_sum / float(ticks), hold_max,
			trest_sum / float(ticks), hops, short, 100.0 * short / maxf(hops, 1), sim.train.stalled.size() - stalled0,
			zero_hop_secs, b.slime_count, step_us / 1000])
	var ends := ends_cap + ends_recheck + ends_other
	print("HOLD_ENDS total=%d cap=%d recheck=%d other=%d mean_dur_ticks=%.1f still_holding=%d" % [ends, ends_cap, ends_recheck, ends_other, dur_sum / maxf(ends, 1), hold_began.size()])
	if parts:
		var line := "PARTS us/tick:"
		for k in part_us:
			line += " %s=%.0f" % [k, part_us[k] / float(ticks)]
		print(line)
	print("STATE_HASH_HINT tick=%d hops=%d" % [sim.tick, sim.train.hops_taken])
	quit(0)

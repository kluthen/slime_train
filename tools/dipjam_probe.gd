extends SceneTree
## The train-flow probe (chunk 24g; first built for the dip-nudge jam, hence
## its name): how fast the train moves, climbs and takes slimes off the
## loop's start, measured headless on a test-level fixture stepped with the
## game's own step (game.step_simulation, as --run-ticks does). Read only:
## the final STATE hash is a plain run's. The tick comes from SLIME_TICK.
## Not a test.
##
## Run:   godot --headless --no-header --path . -s res://tools/dipjam_probe.gd --
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
##   DJ        fixture, seed, tick kind
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
##             speed, px/s), stall (stalled moves, out of bounds ones not
##             counted, see DJ_CLIMB), stuck
##   DJ_LATE   from --late-from on, per WINDOW ticks: arr (laps completed:
##             the return route's end), x240 and x750 (forward crossings of
##             those loop distances: the train's flow off the loop's start)
##   DJ_CLIMB  per climb (CLIMBS, loop distances): speed (mean
##             progress speed of the active train slimes on it, px/s, all
##             ticks); slide (the mean move down the route over the tick of
##             the centres of the grounded train slimes between hops on a
##             rise, creep's ticks, px/s, signed: negative is up; creep is
##             their velocity after the tick); alone (the same,
##             of those touching no slime: gravity's slide alone) and
##             alone_n (their ticks), stack (landed train hops ending on
##             top of another slime, see _on_top), landings, stall, oob (out
##             of bounds moves), lost (Offscreen's lost)
##   DJ_CLU    from --late-from on: the largest awake cluster with
##             a slime within NEAR px of the loop's start (exp/geyser's
##             probe's rule): max, mean, ticks above LIMIT (rule 23's), the
##             longest run of them (s)
##   DJ_FLOOR  per dip floor (Fusion's, k in loop order): its loop distances
##             and the route's point at its middle
##   DJ_FUS    per zone, whole run (part=all) and from --late-from on
##             (part=late): where same-species slimes meet and fuse. A pair's
##             zone is its lower id's: start (a train slime on the loop's
##             start basin, up to the top of its exit climb, CLIMBS[0]'s end),
##             dip<k> (a train slime within ZONE_MARGIN px of dip floor k
##             along the loop), route (any other train slime), free.
##             meets (new counting contacts, Fusion's), fused, bumped (per
##             minute of the part: fus_min, bump_min),
##             ended (contacts lost before 3 s), end_s (their mean length, s),
##             end_1s (their share past 1 s), dwell (train slimes in the zone
##             on screen, mean per tick; start and dips only)
##   STATE     the final tick and state hash
# @spec-link [[req_platform_and_performance_targets]]
# @spec-link [[rule_arrivals_clear_faster_than_they_arrive]]

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
## The test level's two climbs, loop distances: the start basin's
## exit (rise 0.7) and section 3's bowl's exit (rise 0.24 to 0.49).
const CLIMBS := [[460.0, 1150.0], [17580.0, 18180.0]]
const NEAR := 240.0
const LIMIT := 20
## How far off a dip floor (px along the loop) a pair still counts as the
## dip's (DJ_FUS): about a base slime's hop.
const ZONE_MARGIN := 150.0
## DJ_FUS's counters, per zone and part.
const FUS_MEETS := 0
const FUS_FUSED := 1
const FUS_BUMPED := 2
const FUS_ENDED := 3
const FUS_END_TICKS := 4
const FUS_END_1S := 5
const FUS_DWELL := 6

var fixture := "stress-dense"
var seed_n := 1
var ticks := 3600
var late_from := 0
var hold_view := Vector2.INF
var hold_from := 0
var _floors: Array[Vector2] = []
var _floors_key := "-"


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
	print("DJ fixture=%s seed=%d tick=%s tick0=%d slimes=%d hold=%s from %d" % [fixture, seed_n,
			"native" if bodies.uses_native() else "gdscript", sim.tick, bodies.slime_count, hold_view, hold_from])
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
	var climb_sum := PackedFloat64Array([0.0, 0.0])
	var climb_n := PackedInt32Array([0, 0])
	var slide_sum := 0.0
	var slide_n := 0
	var alone_sum := 0.0
	var alone_n := 0
	var cen := {}  # id -> its centre after the last tick
	var stacks := 0
	var landings := 0
	var oob := 0
	var lost := 0
	var clu_max := 0
	var clu_sum := 0.0
	var clu_n := 0
	var clu_over := 0
	var clu_run := 0
	var clu_run_max := 0
	var fus := {}  # "part|zone" -> PackedInt64Array FUS_* counters
	var start := train.position_at(0.0)
	print("DJ_LOOP length=%.0f outgoing=%.0f start=%s" % [train.length(), train.outgoing_length(), start])
	for i in ticks:
		if sim.tick % WINDOW == 0:
			_window_start(sim, win_start, win_active)
			front_id = _front(sim)
			front_from = train.progress_of(front_id) if front_id >= 0 else 0.0
		var due_soon := {}  # pair -> zone, the pairs that reach CONTACT_TICKS this tick if still touching
		var contacts_before := _contacts(fusion)
		for pair: Vector2i in contacts_before:
			if contacts_before[pair] == Fusion.CONTACT_TICKS - 1:
				due_soon[pair] = _zone(sim, pair.x)
		game.step_simulation()
		_count_fusion(sim, fus, "late" if sim.tick - 1 >= late_from else "early", due_soon, contacts_before)
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
		var touched := {}
		for pair: Vector2i in bodies.touching_pairs():
			touched[pair.x] = true
			touched[pair.y] = true
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
					for c in CLIMBS.size():
						if d >= CLIMBS[c][0] and d < CLIMBS[c][1]:
							climb_sum[c] += step
							climb_n[c] += 1
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
					if cen.has(id) and along.y < 0.0:
						var move: float = -(bodies.centre_of(id) - cen[id]).dot(along) * 60.0
						slide_sum += move
						slide_n += 1
						if not touched.has(id):
							alone_sum += move
							alone_n += 1
					if back > CREEP_SPEED:
						creep_ticks += 1
						creep_v += back
			if s >= 0:
				cen[id] = bodies.centre_of(id)
		for id: int in train.last_hops:
			var last: Dictionary = train.last_hops[id]
			if last["landed"] >= 0 and landed_seen.get(id, -2) != last["landed"]:
				landed_seen[id] = last["landed"]
				advances.append(last["advance"])
				landings += 1
				if _on_top(bodies, id):
					stacks += 1
		for e in train.stalled:
			if e["tick"] == t:
				if e["reason"] == Train.OUT_OF_BOUNDS:
					oob += 1
				else:
					stall += 1
		for e in sim.offscreen.lost:
			if e["tick"] == t:
				lost += 1
		if t >= late_from:
			var clu := _cluster_near(bodies, start)
			clu_max = maxi(clu_max, clu)
			clu_sum += clu
			clu_n += 1
			if clu > LIMIT:
				clu_over += 1
				clu_run += 1
				clu_run_max = maxi(clu_run_max, clu_run)
			else:
				clu_run = 0
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
	print(("DJ_CLIMB start=%.1f bowl=%.1f slide=%.1f alone=%.1f alone_n=%d stack=%d landings=%d"
			+ " stall=%d oob=%d lost=%d") % [climb_sum[0] / maxi(climb_n[0], 1) * 60.0,
			climb_sum[1] / maxi(climb_n[1], 1) * 60.0, slide_sum / maxi(slide_n, 1),
			alone_sum / maxi(alone_n, 1), alone_n, stacks, landings, stall, oob, lost])
	print("DJ_CLU max=%d mean=%.2f over=%d run_s=%.1f" % [clu_max, clu_sum / maxi(clu_n, 1), clu_over,
			clu_run_max / 60.0])
	_print_fusion(sim, fus, ticks, late_from)
	print("STATE tick=%d hash=%s" % [sim.tick, sim.state_hash()])



## The zone of the pair whose lower id is `slime_id` (see DJ_FUS).
func _zone(sim: Simulation, slime_id: int) -> String:
	var s := sim.slimes.index_of(slime_id)
	if s < 0:
		return "gone"
	if sim.slimes.state[s] != SlimeBodies.TRAIN or not sim.train.tracks(slime_id):
		return "free"
	var d := sim.train.distance_of(slime_id)
	if d < CLIMBS[0][1]:
		return "start"
	var floors := _dip_floors(sim)
	for k in floors.size():
		if d >= floors[k].x - ZONE_MARGIN and d <= floors[k].y + ZONE_MARGIN:
			return "dip%d" % k
	return "route"


## Fusion's dip floors for the train's open gates, recomputed when they change.
func _dip_floors(sim: Simulation) -> Array[Vector2]:
	var key := str(sim.train.open_gates)
	if key != _floors_key:
		_floors_key = key
		_floors = Fusion.dip_floors(sim.train.loop, sim.train.open_gates)
	return _floors


## Fusion's contact counts (its dump()) as pair Vector2i(lower, higher) -> ticks.
static func _contacts(fusion: Fusion) -> Dictionary:
	var out := {}
	for entry: Array in fusion.dump():
		out[Vector2i(entry[0], entry[1])] = entry[2]
	return out


static func _fus_entry(fus: Dictionary, key: String) -> PackedInt64Array:
	if not fus.has(key):
		var row := PackedInt64Array()
		row.resize(FUS_DWELL + 1)
		fus[key] = row
	return fus[key]


static func _fus_add(fus: Dictionary, part: String, zone: String, field: int, by := 1) -> void:
	var row := _fus_entry(fus, part + "|" + zone)
	row[field] += by
	fus[part + "|" + zone] = row


## After a tick (see DJ_FUS): the new contacts, the fusions and bumps of the
## pairs that were one tick short (`due_soon`), the contacts lost
## (`before`: Fusion's counts before the tick), the dwell on screen.
func _count_fusion(sim: Simulation, fus: Dictionary, part: String, due_soon: Dictionary,
		before: Dictionary) -> void:
	var bodies := sim.slimes
	var fusion := sim.fusion
	var now := _contacts(fusion)
	var touching := {}
	for pair: Vector2i in bodies.touching_pairs():
		touching[pair] = true
	for pair: Vector2i in due_soon:
		if bodies.index_of(pair.y) < 0 and bodies.index_of(pair.x) >= 0:
			_fus_add(fus, part, due_soon[pair], FUS_FUSED)
		elif touching.has(pair) and bodies.index_of(pair.y) >= 0:
			_fus_add(fus, part, due_soon[pair], FUS_BUMPED)
	for pair: Vector2i in before:
		if now.has(pair) or due_soon.has(pair):
			continue
		var zone := _zone(sim, pair.x)
		_fus_add(fus, part, zone, FUS_ENDED)
		_fus_add(fus, part, zone, FUS_END_TICKS, before[pair])
		if before[pair] >= 60:
			_fus_add(fus, part, zone, FUS_END_1S)
	for pair: Vector2i in now:
		if now[pair] == 1:
			_fus_add(fus, part, _zone(sim, pair.x), FUS_MEETS)
	for id in sim.train.tracked_ids():
		var s := bodies.index_of(id)
		if s < 0 or bodies.state[s] != SlimeBodies.TRAIN:
			continue
		var zone := _zone(sim, id)
		if (zone.begins_with("dip") or zone == "start") and Fusion.on_screen(sim.view, bodies.centre_of(id)):
			_fus_add(fus, part, zone, FUS_DWELL)


## Prints DJ_FLOOR and DJ_FUS (see the class doc).
func _print_fusion(sim: Simulation, fus: Dictionary, ticks: int, from: int) -> void:
	var floors := _dip_floors(sim)
	for k in floors.size():
		print("DJ_FLOOR k=%d from=%.0f to=%.0f at=%s" % [k, floors[k].x, floors[k].y,
				sim.train.position_at((floors[k].x + floors[k].y) * 0.5).round()])
	var span := {"early": mini(from, ticks), "late": maxi(ticks - from, 0)}
	var zones := {}
	for key: String in fus:
		zones[key.get_slice("|", 1)] = true
	var rows := {}
	for zone: String in zones:
		var total := PackedInt64Array()
		total.resize(FUS_DWELL + 1)
		for part: String in ["early", "late"]:
			if not fus.has(part + "|" + zone):
				continue
			var row: PackedInt64Array = fus[part + "|" + zone]
			for f in row.size():
				total[f] += row[f]
		rows["all|" + zone] = total
		if fus.has("late|" + zone) and from > 0:
			rows["late|" + zone] = fus["late|" + zone]
	var names := rows.keys()
	names.sort()
	for key: String in names:
		var part := key.get_slice("|", 0)
		var row: PackedInt64Array = rows[key]
		var n: int = ticks if part == "all" else span["late"]
		var minutes := maxf(n / 3600.0, 1.0 / 3600.0)
		print(("DJ_FUS part=%s zone=%s meets=%d fused=%d bumped=%d fus_min=%.2f bump_min=%.2f ended=%d"
				+ " end_s=%.2f end_1s=%.2f dwell=%.2f") % [part, key.get_slice("|", 1), row[FUS_MEETS],
				row[FUS_FUSED], row[FUS_BUMPED], row[FUS_FUSED] / minutes, row[FUS_BUMPED] / minutes,
				row[FUS_ENDED], row[FUS_END_TICKS] / 60.0 / maxi(row[FUS_ENDED], 1),
				float(row[FUS_END_1S]) / maxi(row[FUS_ENDED], 1), float(row[FUS_DWELL]) / maxi(n, 1)])


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


## Whether slime `slime_id`, just landed, rests on top of another
## slime: one whose centre is below it by more than half the two radii and
## within half of them sideways, the rings close (1.3 radii).
func _on_top(bodies: SlimeBodies, slime_id: int) -> bool:
	var c := bodies.centre_of(slime_id)
	var r := bodies.radius_of(slime_id) + SlimeBodies.EDGE
	for s in bodies.slime_count:
		var other := bodies.id[s]
		if other == slime_id:
			continue
		var o := bodies.centre_of(other)
		var both := r + bodies.ring_radius[s] + SlimeBodies.EDGE
		if o.y - c.y > both * 0.5 and absf(o.x - c.x) < both * 0.5 and o.distance_to(c) < both * 1.3:
			return true
	return false


## The largest awake cluster (DebugCounts' rule) with a member
## within NEAR px of `start` (exp/geyser's probe's).
func _cluster_near(bodies: SlimeBodies, start: Vector2) -> int:
	var physics := DebugCounts.physics_slime_ids(bodies)
	var pairs: Array = DebugCounts.touching_by_distance(bodies, physics) if bodies.candidate_pair_count() == 0 \
			else bodies.touching_pairs()
	var index := {}
	for i in physics.size():
		index[physics[i]] = i
	var parent := PackedInt32Array()
	parent.resize(physics.size())
	for i in physics.size():
		parent[i] = i
	for pair: Vector2i in pairs:
		if not (index.has(pair.x) and index.has(pair.y)):
			continue
		var a := _root(parent, index[pair.x])
		var b := _root(parent, index[pair.y])
		if a != b:
			parent[b] = a
	var size := {}
	var near := {}
	for i in physics.size():
		var r := _root(parent, i)
		size[r] = size.get(r, 0) + 1
		if bodies.centre_of(physics[i]).distance_to(start) <= NEAR:
			near[r] = true
	var best := 0
	for r in near:
		best = maxi(best, size[r])
	return best


static func _root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

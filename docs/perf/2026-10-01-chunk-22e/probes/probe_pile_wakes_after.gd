extends SceneTree
## Throwaway probe (22e AFTER): no instrumentation. Loads a fixture in test mode
## (seed 1), steps it TICKS ticks and logs, per second, the Physics / resting /
## in-basket counts, RESTING->ACTIVE transitions (calm compared tick to tick) by
## state, whole-pile wakes (11+ in one tick), the largest awake cluster,
## catches and releases, basket 3's phase, the holding train slimes and the
## resting train slimes. Basket wakes are attributed to what happened in the
## same tick (a release, the trapdoor shutting, or something else).
## godot --headless --path <repo> -s probe_pile_wakes_after.gd -- --fixture=s3-basket-59of60 [--ticks=2400]

var fixture := "s3-basket-59of60"
var ticks := 2400


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var p := arg.trim_prefix("--").split("=", true, 1)
		if p[0] == "fixture": fixture = p[1]
		if p[0] == "ticks": ticks = int(p[1])
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
	var has_b3: bool = sim.object_states.has("s3.basket")
	print("fixture=%s tick0=%d slimes=%d" % [fixture, sim.tick, b.slime_count])
	var tot := {"trans": 0, "trans_basket": 0, "trans_train": 0, "trans_other": 0, "whole_pile": 0,
			"whole_events": 0, "releases": 0, "catches": 0, "hold_slime_ticks": 0, "hold_max": 0,
			"train_rest_slime_ticks": 0}
	var basket_wake_events := {}  # cause -> [events, slimes woken]
	var basket_wake_sizes := []
	var fired_tick := -1
	var release_due := 0
	var release_blocked := 0
	var pile_active_after_fire := 0
	var pile_resting_after_fire := 0
	var sec := {}
	for t in ticks:
		var before_calm := {}
		var before_state := {}
		var inb_before := 0
		for s in b.slime_count:
			before_calm[b.id[s]] = b.calm[s]
			before_state[b.id[s]] = b.state[s]
			if b.state[s] == SlimeBodies.IN_BASKET:
				inb_before += 1
		var phase_before = sim.object_states["s3.basket"]["phase"] if has_b3 else ""
		var due: bool = has_b3 and phase_before == "fired" and inb_before > 0 and sim.tick >= int(sim.object_states["s3.basket"]["next_release"])
		game.step_simulation()
		var phase_after = sim.object_states["s3.basket"]["phase"] if has_b3 else ""
		if phase_before != "fired" and phase_after == "fired" and fired_tick < 0:
			fired_tick = sim.tick
		var woke := []
		var rel := 0
		var cat := 0
		for s in b.slime_count:
			var i := b.id[s]
			if not before_calm.has(i):
				continue
			if before_calm[i] == SlimeBodies.RESTING and b.calm[s] == SlimeBodies.ACTIVE:
				woke.append(i)
			if before_state[i] == SlimeBodies.IN_BASKET and b.state[s] != SlimeBodies.IN_BASKET:
				rel += 1
			if before_state[i] != SlimeBodies.IN_BASKET and b.state[s] == SlimeBodies.IN_BASKET:
				cat += 1
		if due:
			release_due += 1
			if rel == 0:
				release_blocked += 1
		var wb := 0
		var wt := 0
		var wo := 0
		for i in woke:
			match before_state[i]:
				SlimeBodies.IN_BASKET: wb += 1
				SlimeBodies.TRAIN: wt += 1
				_: wo += 1
		var whole := woke.size() if woke.size() >= 11 else 0
		if wb > 0:
			var cause := "release" if rel > 0 else ("phase:%s->%s" % [phase_before, phase_after] if phase_before != phase_after else ("catch" if cat > 0 else "other"))
			if not basket_wake_events.has(cause):
				basket_wake_events[cause] = [0, 0]
			basket_wake_events[cause][0] += 1
			basket_wake_events[cause][1] += wb
			basket_wake_sizes.append(wb)
			if wb >= 5:
				print("  BASKET_WAKE t=%d (%.2fs) basket=%d train=%d other=%d rel=%d cat=%d phase=%s->%s" % [sim.tick, sim.tick / 60.0, wb, wt, wo, rel, cat, phase_before, phase_after])
		# Holds and resting train slimes after the tick.
		var holding := 0
		var train_rest := 0
		var active_b := 0
		var inb := 0
		for s in b.slime_count:
			if b.state[s] == SlimeBodies.TRAIN:
				if sim.train.is_holding(b.id[s]):
					holding += 1
				if b.calm[s] == SlimeBodies.RESTING:
					train_rest += 1
			if b.state[s] == SlimeBodies.IN_BASKET:
				inb += 1
				if b.calm[s] == SlimeBodies.ACTIVE:
					active_b += 1
		if fired_tick >= 0 and inb > 0:
			if active_b > 0:
				pile_active_after_fire += 1
			else:
				pile_resting_after_fire += 1
		tot["trans"] += woke.size(); tot["trans_basket"] += wb; tot["trans_train"] += wt; tot["trans_other"] += wo
		tot["whole_pile"] += whole; tot["whole_events"] += 1 if whole > 0 else 0
		tot["releases"] += rel; tot["catches"] += cat
		tot["hold_slime_ticks"] += holding; tot["hold_max"] = maxi(tot["hold_max"], holding)
		tot["train_rest_slime_ticks"] += train_rest
		var k := int(t / 60)
		if not sec.has(k):
			sec[k] = {"trans": 0, "tb": 0, "tt": 0, "to": 0, "whole": 0, "rel": 0, "cat": 0, "pile_active": 0,
					"hold_sum": 0, "hold_max": 0, "trest_max": 0}
		var row: Dictionary = sec[k]
		row["trans"] += woke.size(); row["tb"] += wb; row["tt"] += wt; row["to"] += wo
		row["whole"] += whole; row["rel"] += rel; row["cat"] += cat
		row["pile_active"] += 1 if active_b > 0 else 0
		row["hold_sum"] += holding; row["hold_max"] = maxi(row["hold_max"], holding)
		row["trest_max"] = maxi(row["trest_max"], train_rest)
		if (t + 1) % 60 == 0:
			var rest := 0
			var inb_rest := 0
			for s in b.slime_count:
				if b.calm[s] == SlimeBodies.RESTING:
					rest += 1
					if b.state[s] == SlimeBodies.IN_BASKET:
						inb_rest += 1
			print("SEC %2d physics=%d resting=%d in_basket=%d (resting %d) trans=%d [basket %d train %d other %d] whole_pile=%d cluster=%d rel=%d cat=%d phase=%s bodies=%d pile_active_ticks=%d hold_mean=%.1f hold_max=%d train_resting=%d (max %d)"
					% [k + 1, b.crowd_count(), rest, inb, inb_rest, row["trans"], row["tb"], row["tt"], row["to"], row["whole"],
					DebugCounts.largest_cluster(b), row["rel"], row["cat"], phase_after, b.slime_count,
					row["pile_active"], row["hold_sum"] / 60.0, row["hold_max"], train_rest, row["trest_max"]])
	print("TOTAL ", tot)
	print("HOLD mean holding train slimes per tick %.2f" % [tot["hold_slime_ticks"] / float(ticks)])
	print("BASKET_WAKES by same-tick event [events, slimes woken] ", basket_wake_events)
	basket_wake_sizes.sort()
	if not basket_wake_sizes.is_empty():
		print("BASKET_WAKE_SIZES n=%d min=%d med=%d max=%d" % [basket_wake_sizes.size(), basket_wake_sizes[0], basket_wake_sizes[basket_wake_sizes.size() / 2], basket_wake_sizes[-1]])
	print("BASKET3_FIRED_TICK ", fired_tick)
	print("RELEASES due_ticks=%d blocked_ticks=%d (outlet not clear)" % [release_due, release_blocked])
	print("PILE_AFTER_FIRE active_ticks=%d resting_ticks=%d" % [pile_active_after_fire, pile_resting_after_fire])
	quit(0)

extends Node2D
## Spike 1 (throwaway): 200 ring-of-springs slimes on one screen.
##
## Run:   godot --path . spikes/soft-slimes/spike.tscn [-- options]
## Options (after "--"):
##   --mode=still|moving   still: a resting pile; moving: every slime hops
##   --points=16           points per ring for a size-1 slime (size 2: +25%, size 3: +50%)
##   --draw=blend|direct   blend: species fields + threshold shader; direct: rings on their own
##   --field-scale=1.0     resolution of the field viewports relative to the window
##   --count=200           number of slimes
##   --substeps=2          substeps per 60 Hz step
##   --iterations=1        constraint passes per substep
##   --step=frame|physics  frame (default): one sim step per rendered frame
##                         (lockstep, so fps shows the real per-frame cost);
##                         physics: the sim runs in _physics_process at 60 Hz
##   --warmup=4 --measure=5  seconds; with --bench the run quits after measuring
##   --bench               print one RESULT line and quit
##   --shot=/path.png      save a screenshot at the end of the run
##   --matrix              run the whole bench matrix in one process (still/moving x
##                         16/12/8 points x blend 1.0 / blend 0.5 / direct, then the
##                         first case again as a drift check), one RESULT line each, and quit
##   --soak=600            after the matrix (or alone), a moving run of that many seconds
##                         that prints a SOAK line every 10 s, to watch throttling
##   --draw-only           a settled still pile at 12 points with the simulation frozen while
##                         measuring, for blend 1.0 / blend 0.5 / direct: the frame is then
##                         bound by drawing, which shows the draw cost where GPU timing is missing
## On Android (no command line) the phone driver runs "--matrix --soak=600"; another
## preset can pass other options through command_line/extra_args ("-- --draw-only").
## Keys: Space toggles still/moving, D toggles blend/direct, P cycles 8/12/16 points.

const SlimeSim := preload("res://spikes/soft-slimes/slime_sim.gd")
const FIELD_SHADER := preload("res://spikes/soft-slimes/field.gdshader")
const BLEND_SHADER := preload("res://spikes/soft-slimes/blend.gdshader")
const DIRECT_SHADER := preload("res://spikes/soft-slimes/direct.gdshader")

## Six flat placeholder species colours, spread in lightness.
const PALETTE: Array[Color] = [
	Color("f4d63b"), # yellow (lightest)
	Color("8fd95a"), # green
	Color("4fc6de"), # cyan
	Color("f28a3a"), # orange
	Color("d4549c"), # pink
	Color("5a47b3"), # indigo (darkest)
]
const ONE_HOT: Array[Color] = [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]

const BASE_RADIUS := 18.0 # visible radius of a size-1 slime, logical px
const SKIRT := 6.0        # width of the soft field edge; visible edge sits at SKIRT/2
const SEED := 20260928

var mode := "moving"
var points := 16
var draw_mode := "blend"
var field_scale := 1.0
var count := 200
var substeps := 2
var iterations := 1
var warmup := 4.0
var measure := 5.0
var bench := false
var lockstep := true
var shot := ""
var matrix := false
var soak := 0.0
var draw_only := false
## Stops stepping the simulation once measuring starts (draw-only cases).
var freeze_when_measuring := false
## Warm-up also waits for this many ticks, so a slow device still lets the
## still pile settle before measuring (the matrix sets it).
var warmup_ticks := 0

# Phone driver: the queue of cases still to run (see _plan_cases).
var cases: Array[Dictionary] = []
var case_label := ""
var soaking := false
var soak_window := 0.0
var soak_frames := 0
var soak_sim_usec := 0
var soak_ticks := 0
var soak_gpu_ms := 0.0

var sim
var world_size := Vector2.ZERO

# Drawing.
var painters: Array[Node2D] = []
var painter_indices: Array[PackedInt32Array] = []
var colors := PackedColorArray()
var field_views: Array[SubViewport] = []
var composite: ColorRect
var hud: Label

# Measurement.
var elapsed := 0.0
var measuring := false
var done := false
var frames := 0
var measured_time := 0.0
var sim_usec := 0
var sim_ticks := 0
var draw_usec := 0
var gpu_ms_sum := 0.0
var cpu_render_ms_sum := 0.0
var hud_timer := 0.0
var hud_frames := 0
var ticks_since_build := 0


func _ready() -> void:
	_parse_args()
	if OS.has_feature("android") and OS.get_cmdline_user_args().is_empty():
		matrix = true
		soak = 600.0
	if matrix or soak > 0.0 or draw_only:
		_plan_cases()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.set_default_clear_color(Color("cfe8f5"))
	world_size = get_viewport_rect().size
	var ground := ColorRect.new()
	ground.color = Color("6b5a4a")
	ground.position = Vector2(0, world_size.y - 40.0)
	ground.size = Vector2(world_size.x, 40.0)
	add_child(ground)
	hud = Label.new()
	hud.position = Vector2(8, 4)
	hud.add_theme_color_override("font_color", Color.BLACK)
	_build_sim()
	_build_drawing()
	add_child(hud)
	get_viewport().size_changed.connect(_on_resized)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	print("SPIKE renderer=%s adapter=%s api=%s window=%s world=%s" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(),
		DisplayServer.window_get_size(), world_size])
	print("DEVICE model=%s cpu=%s cores=%d screen=%s window=%s viewport=%s refresh=%.0f scale=%.2f" % [
		OS.get_model_name(), OS.get_processor_name(), OS.get_processor_count(),
		DisplayServer.screen_get_size(), DisplayServer.window_get_size(), get_viewport().size,
		DisplayServer.screen_get_refresh_rate(), DisplayServer.screen_get_scale()])
	if not cases.is_empty():
		_next_case()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		var key := kv[0]
		var val := kv[1] if kv.size() > 1 else ""
		match key:
			"mode": mode = val
			"points": points = int(val)
			"draw": draw_mode = val
			"field-scale": field_scale = float(val)
			"count": count = int(val)
			"substeps": substeps = int(val)
			"iterations": iterations = int(val)
			"warmup": warmup = float(val)
			"measure": measure = float(val)
			"bench": bench = true
			"step": lockstep = val != "physics"
			"shot": shot = val
			"matrix": matrix = true
			"soak": soak = float(val)
			"draw-only": draw_only = true


## The phone driver's cases, in the order run_bench.sh runs them for one
## renderer, then the first case again (drift check), then the soak.
func _plan_cases() -> void:
	bench = true
	warmup_ticks = 400
	if matrix:
		for m in ["still", "moving"]:
			for p in [16, 12, 8]:
				cases.append({mode = m, points = p, draw = "blend", scale = 1.0})
				cases.append({mode = m, points = p, draw = "blend", scale = 0.5})
				cases.append({mode = m, points = p, draw = "direct", scale = 1.0})
		var again: Dictionary = cases[0].duplicate()
		again.label = "repeat"
		cases.append(again)
	if draw_only:
		for d in [["blend", 1.0], ["blend", 0.5], ["direct", 1.0]]:
			cases.append({mode = "still", points = 12, draw = d[0], scale = d[1], label = "draw-only"})
	if soak > 0.0:
		cases.append({mode = "moving", points = 12, draw = "blend", scale = 1.0, label = "soak"})


## Starts the next queued case from a fresh pile; quits when none is left.
func _next_case() -> void:
	if cases.is_empty():
		print("MATRIX done")
		get_tree().quit()
		return
	var c: Dictionary = cases.pop_front()
	mode = c.mode
	points = c.points
	draw_mode = c.draw
	field_scale = c.scale
	case_label = c.get("label", "")
	soaking = case_label == "soak"
	freeze_when_measuring = case_label == "draw-only"
	if soaking:
		measure = soak
	_build_sim()
	_build_drawing()
	elapsed = 0.0
	measuring = false
	done = false
	frames = 0
	measured_time = 0.0
	sim_usec = 0
	sim_ticks = 0
	draw_usec = 0
	gpu_ms_sum = 0.0
	cpu_render_ms_sum = 0.0
	ticks_since_build = 0


func _points_for(size: int) -> int:
	return points + int(round(points * 0.25 * (size - 1)))


func _build_sim() -> void:
	sim = SlimeSim.new()
	sim.substeps = substeps
	sim.iterations = iterations
	sim.hopping = mode == "moving"
	var floor_y := world_size.y - 40.0
	sim.setup_world(world_size.x, floor_y, SEED)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# Sizes: 60% size 1, 25% size 2, 15% size 3. Shuffled so the pile mixes.
	var sizes: Array[int] = []
	for i in count:
		var r := i % 20
		sizes.append(1 if r < 12 else (2 if r < 17 else 3))
	for i in range(sizes.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := sizes[i]
		sizes[i] = sizes[j]
		sizes[j] = tmp
	# Shelf-pack from the floor upwards; the upper rows start above the
	# screen and fall into the pile.
	var x := 4.0
	var y := floor_y
	var row_h := 0.0
	for i in count:
		var size := sizes[i]
		var vis_r := BASE_RADIUS * sqrt(float(size))
		var d := vis_r * 2.0 + 2.0
		if x + d > world_size.x - 4.0:
			x = 4.0
			y -= row_h
			row_h = 0.0
		var ring_r := vis_r - SKIRT * 0.5
		sim.add_slime(Vector2(x + d * 0.5, y - d * 0.5), size, rng.randi_range(0, 5),
			_points_for(size), ring_r)
		x += d
		row_h = maxf(row_h, d)


func _build_drawing() -> void:
	for p in painters:
		p.queue_free()
	for v in field_views:
		v.queue_free()
	if composite:
		composite.queue_free()
		composite = null
	painters.clear()
	painter_indices.clear()
	field_views.clear()

	var n: int = sim.pos.size()
	var s_count: int = sim.slime_count
	colors.resize(n * 2 + s_count)
	for s in s_count:
		var sp: int = sim.species[s]
		var c: Color = PALETTE[sp] if draw_mode == "direct" else ONE_HOT[sp % 3]
		var f: int = sim.first[s]
		for j in range(f, f + sim.npts[s]):
			colors[j] = Color(c, 1.0)
			colors[n + j] = Color(c, 0.0)
		colors[2 * n + s] = Color(c, 1.0)

	if draw_mode == "direct":
		var painter := Node2D.new()
		var mat := ShaderMaterial.new()
		mat.shader = DIRECT_SHADER
		painter.material = mat
		add_child(painter)
		painters.append(painter)
		painter_indices.append(_indices_for(func(_sp: int) -> bool: return true))
	else:
		var px := _field_px()
		var palette := PackedVector3Array()
		for c in PALETTE:
			palette.append(Vector3(c.r, c.g, c.b))
		for group in 2:
			var sv := SubViewport.new()
			sv.size = px
			sv.transparent_bg = true
			sv.disable_3d = true
			sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(sv)
			sv.canvas_transform = _field_transform()
			field_views.append(sv)
			RenderingServer.viewport_set_measure_render_time(sv.get_viewport_rid(), true)
			var painter := Node2D.new()
			var mat := ShaderMaterial.new()
			mat.shader = FIELD_SHADER
			painter.material = mat
			sv.add_child(painter)
			painters.append(painter)
			var g := group
			painter_indices.append(_indices_for(func(sp: int) -> bool: return sp / 3 == g))
		composite = ColorRect.new()
		composite.size = get_viewport_rect().size
		var cmat := ShaderMaterial.new()
		cmat.shader = BLEND_SHADER
		cmat.set_shader_parameter("field_a", field_views[0].get_texture())
		cmat.set_shader_parameter("field_b", field_views[1].get_texture())
		cmat.set_shader_parameter("palette", palette)
		composite.material = cmat
		add_child(composite)
		move_child(composite, 1) # above the ground, below the HUD


## The field viewports cover the window at `field_scale` of its resolution,
## with the same world-to-pixel mapping as the main viewport.
func _field_px() -> Vector2i:
	return Vector2i((Vector2(get_viewport().size) * field_scale).round())


func _field_transform() -> Transform2D:
	return Transform2D().scaled(Vector2(field_scale, field_scale)) * get_viewport().get_final_transform()


func _on_resized() -> void:
	for sv in field_views:
		sv.size = _field_px()
		sv.canvas_transform = _field_transform()
	if composite:
		composite.size = get_viewport_rect().size


## Static index buffer: a fan for the ring's inside and a quad strip for the
## skirt, for the slimes whose species passes `keep`.
func _indices_for(keep: Callable) -> PackedInt32Array:
	var idx := PackedInt32Array()
	var n: int = sim.pos.size()
	for s in sim.slime_count:
		if not keep.call(sim.species[s]):
			continue
		var f: int = sim.first[s]
		var cnt: int = sim.npts[s]
		var c: int = 2 * n + s
		for i in cnt:
			var a := f + i
			var b := f + (i + 1) % cnt
			idx.append_array([c, a, b, a, n + a, n + b, a, n + b, b])
	return idx


func _physics_process(_delta: float) -> void:
	if not lockstep:
		_sim_step()


func _sim_step() -> void:
	if freeze_when_measuring and measuring:
		return
	var t0 := Time.get_ticks_usec()
	sim.step()
	ticks_since_build += 1
	if measuring:
		sim_usec += Time.get_ticks_usec() - t0
		sim_ticks += 1
		if soaking:
			soak_sim_usec += Time.get_ticks_usec() - t0
			soak_ticks += 1


func _process(delta: float) -> void:
	if lockstep:
		_sim_step()
	var t0 := Time.get_ticks_usec()
	_rebuild_mesh()
	var t1 := Time.get_ticks_usec()
	elapsed += delta
	if measuring and not done:
		frames += 1
		measured_time += delta
		draw_usec += t1 - t0
		var vp := get_viewport().get_viewport_rid()
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var cpu := RenderingServer.viewport_get_measured_render_time_cpu(vp)
		for sv in field_views:
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(sv.get_viewport_rid())
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(sv.get_viewport_rid())
		gpu_ms_sum += gpu
		cpu_render_ms_sum += cpu
		if soaking:
			_soak_sample(delta, gpu)
	if not measuring and elapsed >= warmup and ticks_since_build >= warmup_ticks:
		measuring = true
	if measuring and not done and measured_time >= measure:
		done = true
		_report()
	hud_timer += delta
	hud_frames += 1
	if hud_timer >= 0.5:
		hud.text = "%d fps | %s | %d pts | %s | contact tests %d" % [
			int(hud_frames / hud_timer), "moving" if sim.hopping else "still", points,
			draw_mode, sim.contact_tests]
		hud_timer = 0.0
		hud_frames = 0


## One SOAK line per 10 s window of the soak run: fps, sim ms per tick and GPU
## ms over that window, with the time since the soak started measuring.
func _soak_sample(delta: float, gpu: float) -> void:
	soak_window += delta
	soak_frames += 1
	soak_gpu_ms += gpu
	if soak_window < 10.0:
		return
	print("SOAK t=%.0f fps=%.1f sim_ms_per_tick=%.3f render_gpu_ms=%.3f" % [
		measured_time, soak_frames / soak_window,
		soak_sim_usec / 1000.0 / maxi(soak_ticks, 1), soak_gpu_ms / soak_frames])
	soak_window = 0.0
	soak_frames = 0
	soak_sim_usec = 0
	soak_ticks = 0
	soak_gpu_ms = 0.0


func _rebuild_mesh() -> void:
	var pos: PackedVector2Array = sim.pos
	var n := pos.size()
	var verts := pos.duplicate()
	verts.resize(n * 2 + sim.slime_count)
	var first: PackedInt32Array = sim.first
	var npts: PackedInt32Array = sim.npts
	var centre: PackedVector2Array = sim.centre
	for s in sim.slime_count:
		var f: int = first[s]
		var last: int = f + npts[s] - 1
		var pp: Vector2 = pos[last]
		var cur: Vector2 = pos[f]
		for j in range(f, last + 1):
			var nx: Vector2 = pos[j + 1] if j < last else pos[f]
			var d := nx - pp
			var nrm := Vector2(d.y, -d.x).normalized()
			verts[n + j] = cur + nrm * SKIRT
			pp = cur
			cur = nx
		verts[2 * n + s] = centre[s]
	for i in painters.size():
		var item := painters[i].get_canvas_item()
		RenderingServer.canvas_item_clear(item)
		RenderingServer.canvas_item_add_triangle_array(item, painter_indices[i], verts, colors)


func _report() -> void:
	var fps := frames / measured_time
	var sim_ms := sim_usec / 1000.0 / maxi(sim_ticks, 1)
	var line := "RESULT%s renderer=%s window=%dx%d step=%s mode=%s points=%d draw=%s field_scale=%.2f slimes=%d total_points=%d substeps=%d iterations=%d fps=%.1f frame_ms=%.3f sim_ms_per_tick=%.3f sim_ms_per_frame=%.3f draw_build_ms=%.3f render_cpu_ms=%.3f render_gpu_ms=%.3f contact_tests=%d" % [
		(" case=" + case_label) if case_label != "" else "",
		RenderingServer.get_current_rendering_method(), get_viewport().size.x, get_viewport().size.y,
		"frame" if lockstep else "physics", "moving" if sim.hopping else "still",
		points, draw_mode, field_scale, sim.slime_count, sim.pos.size(), substeps, iterations,
		fps, 1000.0 / fps, sim_ms, sim_usec / 1000.0 / frames, draw_usec / 1000.0 / frames,
		cpu_render_ms_sum / frames, gpu_ms_sum / frames, sim.contact_tests]
	print(line)
	if shot != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("SHOT ", shot)
	if not cases.is_empty() or matrix or soak > 0.0 or draw_only:
		_next_case()
	elif bench:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			sim.hopping = not sim.hopping
		KEY_D:
			draw_mode = "direct" if draw_mode == "blend" else "blend"
			_build_drawing()
		KEY_P:
			points = {8: 12, 12: 16, 16: 8}.get(points, 16)
			_build_sim()
			_build_drawing()

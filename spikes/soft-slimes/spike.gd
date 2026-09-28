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


func _ready() -> void:
	_parse_args()
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
	var t0 := Time.get_ticks_usec()
	sim.step()
	if measuring:
		sim_usec += Time.get_ticks_usec() - t0
		sim_ticks += 1


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
	if not measuring and elapsed >= warmup:
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
	var line := "RESULT renderer=%s window=%dx%d step=%s mode=%s points=%d draw=%s field_scale=%.2f slimes=%d total_points=%d substeps=%d iterations=%d fps=%.1f frame_ms=%.3f sim_ms_per_tick=%.3f sim_ms_per_frame=%.3f draw_build_ms=%.3f render_cpu_ms=%.3f render_gpu_ms=%.3f contact_tests=%d" % [
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
	if bench:
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

extends Node2D
## Spike (chunk 2): compares ways to draw crisp curved terrain in Godot 4.7.
## Throwaway code. See docs/dev/spike-vector-look.md for the outcome.
##
## Run with:
##   godot --path /home/bastien/work/slime_train spikes/vector-look/spike.tscn
##
## Steps through: an SVG imported as a texture (Sprite2D) vs. a Curve2D
## tessellated into Polygon2D + Line2D at runtime, at camera zooms
## 0.5x/1x/2x/4x, saving a screenshot of each to spikes/vector-look/out/,
## then times a frame with 50 terrain pieces on screen for each approach.

const OUT_DIR := "res://spikes/vector-look/out/"
const SVG_PATH := "res://spikes/vector-look/terrain.svg"
const ZOOM_LEVELS := [0.5, 1.0, 2.0, 4.0]

# The same control points drive both the code-drawn curve and terrain.svg
# (the SVG's path was generated from these points off-line, see
# docs/dev/spike-vector-look.md), so the two approaches are visually
# comparable.
const CONTROL_POINTS := [
	Vector2(-80, 20), Vector2(-60, -70), Vector2(10, -95), Vector2(70, -50),
	Vector2(85, 25), Vector2(35, 75), Vector2(-45, 65),
]

var camera: Camera2D
var approach_root: Node2D
var curve: Curve2D
var poly: Polygon2D
var line: Line2D


func _ready() -> void:
	# Uncap frame rate so the 50-piece timing reflects draw cost, not vsync.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var background := ColorRect.new()
	background.color = Color(0.85, 0.9, 0.95)
	background.size = Vector2(4000, 4000)
	background.position = Vector2(-2000, -2000)
	add_child(background)

	camera = Camera2D.new()
	add_child(camera)
	camera.enabled = true
	camera.make_current()

	approach_root = Node2D.new()
	add_child(approach_root)

	await run_spike()
	print("SPIKE DONE")
	get_tree().quit()


func set_camera_zoom_factor(factor: float) -> void:
	# "4x zoom" means objects appear 4x bigger. In Godot 4, Camera2D.zoom
	# values above 1 zoom IN (bigger objects); below 1 zoom OUT. So the
	# camera zoom is the factor itself.
	camera.zoom = Vector2(factor, factor)


func clear_approach_root() -> void:
	for c in approach_root.get_children():
		c.queue_free()
	await get_tree().process_frame


func build_curve() -> Curve2D:
	var c := Curve2D.new()
	var n := CONTROL_POINTS.size()
	var tangents: Array[Vector2] = []
	for i in range(n):
		var prev: Vector2 = CONTROL_POINTS[(i - 1 + n) % n]
		var nxt: Vector2 = CONTROL_POINTS[(i + 1) % n]
		tangents.append((nxt - prev) * 0.25)
	for i in range(n):
		c.add_point(CONTROL_POINTS[i], -tangents[i], tangents[i])
	# Close the loop: repeat the first point so the last segment curves too.
	c.add_point(CONTROL_POINTS[0], -tangents[0], tangents[0])
	return c


func build_svg_piece() -> Node2D:
	var spr := Sprite2D.new()
	spr.texture = load(SVG_PATH)
	return spr


func build_tessellated_piece(zoom_factor: float) -> Node2D:
	var holder := Node2D.new()
	var c := build_curve()
	# Retessellate more finely the more zoomed in, so the curve stays
	# smooth instead of showing its straight tessellation segments.
	c.bake_interval = clamp(4.0 / zoom_factor, 0.5, 8.0)
	var pts := c.get_baked_points()

	var p := Polygon2D.new()
	p.color = Color(0.04, 0.04, 0.04)
	p.polygon = pts
	holder.add_child(p)

	var l := Line2D.new()
	l.width = 3.0
	l.default_color = Color(0.18, 0.72, 0.64)
	l.antialiased = true
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.points = pts
	holder.add_child(l)
	return holder


func capture(name: String, zoom_factor: float = 1.0) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	# Crop tight around the (screen-centered) piece so the comparison is
	# readable instead of a mostly-empty window.
	var half := int(140.0 * zoom_factor + 40.0)
	var size := img.get_size()
	var center := size / 2
	var rect := Rect2i(center.x - half, center.y - half, half * 2, half * 2)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, size))
	var cropped := img.get_region(rect)
	cropped.save_png(OUT_DIR + name + ".png")
	print("saved ", name)


func run_spike() -> void:
	# --- Approach 1: SVG imported as a texture (Sprite2D). ---
	await clear_approach_root()
	approach_root.add_child(build_svg_piece())
	for zoom in ZOOM_LEVELS:
		set_camera_zoom_factor(zoom)
		await capture("svg_%sx" % str(zoom), zoom)

	# --- Approach 2: Curve2D tessellated into Polygon2D + Line2D. ---
	await clear_approach_root()
	var piece := build_tessellated_piece(1.0)
	approach_root.add_child(piece)
	poly = piece.get_child(0)
	line = piece.get_child(1)
	for zoom in ZOOM_LEVELS:
		set_camera_zoom_factor(zoom)
		# Rebuild at a bake interval suited to this zoom (retessellate).
		var new_piece := build_tessellated_piece(zoom)
		piece.queue_free()
		approach_root.add_child(new_piece)
		piece = new_piece
		await capture("tessellated_%sx" % str(zoom), zoom)

	# --- Approach 3: a vector plugin. Skipped: see docs/dev/spike-vector-look.md. ---

	# --- Frame cost: 50 terrain pieces on screen. ---
	set_camera_zoom_factor(0.35)
	await measure_frame_cost("svg", build_svg_piece)
	await measure_frame_cost("tessellated", build_tessellated_piece.bind(1.0))


func measure_frame_cost(label: String, factory: Callable) -> void:
	await clear_approach_root()
	var cols := 10
	var rows := 5
	var spacing := Vector2(220, 220)
	for i in range(cols * rows):
		var piece: Node2D = factory.call()
		piece.position = Vector2(
			(i % cols - cols / 2.0) * spacing.x,
			(i / cols - rows / 2.0) * spacing.y
		)
		approach_root.add_child(piece)

	# Let things settle, then time a run of frames.
	for i in range(5):
		await get_tree().process_frame
	var frames := 60
	var start := Time.get_ticks_usec()
	for i in range(frames):
		await get_tree().process_frame
	var elapsed_us := Time.get_ticks_usec() - start
	var avg_ms := (elapsed_us / float(frames)) / 1000.0
	print("%s: 50 pieces, avg frame time %.3f ms (%.0f fps-equivalent)" % [
		label, avg_ms, 1000.0 / avg_ms
	])

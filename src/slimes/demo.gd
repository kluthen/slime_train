extends Node2D
## Slime body demo (chunk 5): every species (A-F) in every size (1-3)
## hopping on a flat floor between two walls, some landing on a curved
## terrain piece. Uses the real Simulation, SlimeBodies and SlimeRenderer;
## the only demo-only logic is turning slimes round near the walls.
##
## Run:   godot --path . src/slimes/demo.tscn [-- options]
## Options (after "--"):
##   --draw=blend|direct   the renderer's mode (default: blend, direct headless)
##   --seed=N              the simulation seed (default 20260928)
##   --shot=/path.png      save a screenshot after --shot-after seconds, then quit
##   --shot-after=4        seconds
## Keys: D toggles blend/direct, Space pauses.

const DEFAULT_SEED := 20260928
## Slimes whose centre is past these turn round.
const TURN_LEFT_X := 1040.0
const TURN_RIGHT_X := 110.0

var simulation: Simulation
var renderer: SlimeRenderer

var _clock := FixedStep.new()
var _paused := false
var _shot := ""
var _shot_after := 4.0
var _elapsed := 0.0
var _hud: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("cfe8f5"))
	var draw_mode := SlimeRenderer.default_mode()
	var seed_value := DEFAULT_SEED
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"draw":
				draw_mode = SlimeRenderer.DIRECT if value == "direct" else SlimeRenderer.BLEND
			"seed":
				seed_value = int(value)
			"shot":
				_shot = value
			"shot-after":
				_shot_after = float(value)
	simulation = Simulation.new(seed_value)
	var slimes := simulation.slimes
	slimes.terrain = SlimeWorld.terrain_from(self)
	for i in Species.COUNT * SlimeBodies.MAX_SIZE:
		var species := i / SlimeBodies.MAX_SIZE
		var size := 1 + i % SlimeBodies.MAX_SIZE
		var at := Vector2(80.0 + i * 57.0, 300.0 - (i % 2) * 110.0)
		var slime := slimes.create(species, size, at)
		slimes.set_heading(slime, 1.0 if i % 2 == 0 else -1.0)
	renderer = SlimeRenderer.new()
	renderer.name = "Slimes"
	renderer.draw_mode = draw_mode
	renderer.bodies = slimes
	add_child(renderer)
	_hud = Label.new()
	_hud.position = Vector2(24, 12)
	_hud.add_theme_color_override("font_color", Color.BLACK)
	add_child(_hud)


func _process(delta: float) -> void:
	if not _paused:
		for i in _clock.advance(delta, 8):
			_steer()
			simulation.step()
	_hud.text = "Slime bodies: 6 species x 3 sizes | %s | tick %d | D: blend/direct, Space: pause" % [
		"blend" if renderer.draw_mode == SlimeRenderer.BLEND else "direct", simulation.tick]
	_elapsed += delta
	if _shot != "" and _elapsed >= _shot_after:
		var path := _shot
		_shot = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_D:
			renderer.draw_mode = SlimeRenderer.DIRECT if renderer.draw_mode == SlimeRenderer.BLEND else SlimeRenderer.BLEND
		KEY_SPACE:
			_paused = not _paused


## Demo only: slimes near a wall turn round (following the loop is chunk 6).
func _steer() -> void:
	var slimes := simulation.slimes
	for slime in slimes.ids():
		var x := slimes.centre_of(slime).x
		if x > TURN_LEFT_X:
			slimes.set_heading(slime, -1.0)
		elif x < TURN_RIGHT_X:
			slimes.set_heading(slime, 1.0)

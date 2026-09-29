class_name ParentGate
extends CanvasLayer
## The parent layer: the parent buttons and the parent surfaces behind them,
## as one state machine over the running game. Nothing it does pauses the
## simulation or the session timer.
##
## States (`state`):
## - HIDDEN: nothing shows; a parent-zone press reveals the buttons (once
##   setup is done) and still reaches the simulation (its ripple).
## - BUTTONS: the parent buttons (wake early, leave, settings) in a row from
##   the top-right corner (ParentLayout). They hide after HIDE_STEPS with no
##   press.
## - PROMPT: the code prompt (ParentCodePrompt), for `pending_action` (a
##   button's action); the right code runs it (act()).
## - SETTINGS: settings (ParentSettings: they fill the screen, close after
##   30 s idle, and hold the change of code and the level save's delete).
## - SETUP: setup (ParentSetup: first launch, the store has no code; it
##   fills the screen and closes for good once it saves the code). A gate
##   made on a store with no code opens it at once, before the first tap.
## PROMPT, SETTINGS and SETUP are ParentSurfaces registered with
## add_surface(); the gate routes the input and the steps to the open one.
## A later unit adds or replaces a surface with add_surface(State.X, its
## surface) in _build(), and enters it with open_state(State.X).
##
## The game root (src/main.gd, `game`) wires it in three places: intercept()
## first for every input event (unless test mode blocks real input),
## advance() once per simulation step (step_simulation, so normal play and
## test mode's run_ticks both drive it), and `simulation` set on every
## simulation swap. It reads the simulation's view (the screen, its
## millimetres) and session (the phase), and asks the game for its wall clock
## (now_wall_ms(), for the wrong-code wait) and to run an action (act()).
##
## Input: intercept() hit-tests the gate's own rects on touches and on real
## (not emulated) left mouse clicks, like the debug overlay; its controls
## ignore the mouse. A press it takes is swallowed with its matching release;
## a press it lets through reaches the simulation (and its release too).
# @spec-link [[req_parent_gate_and_access]]

enum State { HIDDEN, BUTTONS, PROMPT, SETTINGS, SETUP }

## Above the debug overlay (50), below test mode's layer (128).
const LAYER := 60
## The parent buttons hide after this many simulation steps with no press
## (5 s: specs/tuning.md, D113).
const HIDE_STEPS := 300
## The parent buttons' actions (their ParentText keys and `pending_action`).
const WAKE_EARLY := "wake_early"
const LEAVE := "leave"
const SETTINGS := "settings"
## The buttons by slot, from the right (ParentLayout.button_rect).
const SLOTS := [SETTINGS, LEAVE, WAKE_EARLY]

var state := State.HIDDEN
## The action the open code prompt is for ("" when none).
var pending_action := ""
## The app's parent store: the buttons reveal only once it has a code.
var store: ParentStore = null
## The running simulation (the game root sets it on every swap); an open
## surface is laid out for it at once.
var simulation: Simulation = null:
	set(value):
		simulation = value
		if simulation != null and state != State.HIDDEN:
			_lay_out()
## The game root (src/main.gd): its wall clock and the actions. Loosely typed:
## the root has no class name.
var game: Node = null
## Action -> its Button (drawn only: input comes through intercept()).
var buttons := {}
## State -> its ParentSurface.
var surfaces := {}

## The row holding the buttons.
var _row: Control = null
## Simulation steps left before the buttons hide.
var _steps_left := 0
## The presses swallowed whose release must be swallowed too ("touch:<index>", "mouse").
var _swallowed := {}


## A gate on `parent_store` for the game root `game_root`: hidden, or on
## setup at once when the store has no code (first launch: setup comes before
## anything else, and whoever holds the phone creates the code).
# @spec-link [[req_parent_gate_and_access]]
# @spec-link [[req_actor_roles_and_permissions]]
func _init(parent_store: ParentStore, game_root: Node) -> void:
	assert(parent_store != null, "ParentGate: a parent store is required (no store: no gate)")
	assert(game_root != null, "ParentGate: the game root is required")
	store = parent_store
	game = game_root
	name = "ParentGate"
	layer = LAYER
	_build()
	if not store.has_code():
		open_state(State.SETUP)


## Keeps the open surface laid out for the screen, frame by frame.
func _process(_delta: float) -> void:
	if state != State.HIDDEN and simulation != null:
		_lay_out()


## The game root asks this first for every input event: true means the
## parent layer took it and nothing else may get it. The parent zone takes a
## tap before anything else and never calls: while hidden, a parent-zone press
## reveals the buttons and still goes on to the simulation (its ripple).
# @spec-link [[req_controls_tap_zones]]
# @spec-link [[req_parent_gate_and_access]]
func intercept(event: InputEvent) -> bool:
	var key := ""
	if event is InputEventScreenTouch:
		key = "touch:%d" % event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		key = "mouse"
	else:
		return false
	if not event.pressed:
		return _swallowed.erase(key)
	if simulation == null or not _take_press(event.position):
		return false
	_swallowed[key] = true
	return true


## Once per simulation step: the buttons' idle timer (and wake early
## following the phase), or the open surface's step.
# @spec-link [[req_parent_gate_and_access]]
func advance() -> void:
	match state:
		State.HIDDEN:
			return
		State.BUTTONS:
			_steps_left -= 1
			if _steps_left <= 0:
				close()
				return
			_lay_out()
		_:
			surfaces[state].step()


## Shows the parent buttons for HIDE_STEPS, only once setup is done (a code
## is set). Returns whether they show.
# @spec-link [[req_actor_roles_and_permissions]]
# @spec-link [[req_parent_gate_and_access]]
func reveal() -> bool:
	if not store.has_code():
		return false
	_steps_left = HIDE_STEPS
	_enter(State.BUTTONS)
	return true


## Every parent button leads to the code prompt, for its action: the child
## gets there too, and nothing happens without the code.
# @spec-link [[req_actor_roles_and_permissions]]
func open_prompt(action: String) -> void:
	assert(action in SLOTS, "ParentGate.open_prompt: unknown action '%s'" % action)
	pending_action = action
	_enter(State.PROMPT)


## Enters the surface state `to` (PROMPT, SETTINGS, SETUP), which must have
## a surface (add_surface).
func open_state(to: State) -> void:
	assert(surfaces.has(to), "ParentGate.open_state: no surface for state %s" % State.keys()[to])
	_enter(to)


## The right code was entered for `action`: it runs, and the parent's
## authority ends with it (the next action asks for the code again). Wake
## early: the game's wake_early() (sunrise, then screensaver mode, on the next
## step). Leave: the prompt closes and the game's quit_app closes the app
## (stopping screen pinning first is chunk 20). Settings: settings open.
# @spec-link [[req_actor_roles_and_permissions]]
# @spec-link [[req_session_lifecycle]]
func act(action: String) -> void:
	match action:
		WAKE_EARLY:
			close()
			game.wake_early()
		LEAVE:
			close()
			game.quit_app.call()
		SETTINGS:
			pending_action = ""
			open_state(State.SETTINGS)
		_:
			assert(false, "ParentGate.act: unknown action '%s'" % action)


## The game's wall clock now, Unix ms (the wrong-code wait's clock).
func now_wall_ms() -> int:
	return game.now_wall_ms()


## Hides everything: back to HIDDEN, no pending action.
func close() -> void:
	pending_action = ""
	_enter(State.HIDDEN)


## Makes `surface` the one shown in state `for_state` (replacing any).
func add_surface(for_state: State, surface: ParentSurface) -> void:
	assert(for_state not in [State.HIDDEN, State.BUTTONS], "ParentGate.add_surface: HIDDEN and BUTTONS have none")
	if surfaces.has(for_state):
		surfaces[for_state].queue_free()
	surface.gate = self
	surface.visible = state == for_state
	surfaces[for_state] = surface
	add_child(surface)


## The rect of `action`'s button on the screen (its slot, shown or not).
func button_rect(action: String) -> Rect2:
	return ParentLayout.button_rect(SLOTS.find(action), simulation.view)


## Whether `action`'s button shows now: wake early only at bedtime, the
## others always (while the buttons are open).
# @spec-link [[req_parent_gate_and_access]]
func shows(action: String) -> bool:
	return action != WAKE_EARLY or simulation.session.phase == Session.BEDTIME


## The shown button under screen point `at`, or "".
func action_at(at: Vector2) -> String:
	for action in SLOTS:
		if shows(action) and button_rect(action).has_point(at):
			return action
	return ""


## The bottom of what hangs from the top of the screen (the buttons' row
## while they show), else 0. The debug overlay keeps its bar below it.
func menu_bottom() -> float:
	return ParentLayout.row_bottom(simulation.view) if state == State.BUTTONS and simulation != null else 0.0


## Whether a surface that covers the world is open (the prompt, settings,
## setup). The debug overlay hides its bar meanwhile.
func covers_world() -> bool:
	return state in [State.PROMPT, State.SETTINGS, State.SETUP]


## A press at `at` by state: returns whether the gate takes it. Buttons open:
## a press on a button raises the prompt; on the parent zone it restarts the
## 5 s; anywhere else it closes them. A surface open: on it, it's the
## surface's; outside, it closes it (on the parent zone it then reveals the
## buttons, proposed). Only what the gate takes is swallowed:
## the others do their normal job (a call, a session start, ...).
# @spec-link [[req_parent_gate_and_access]]
func _take_press(at: Vector2) -> bool:
	match state:
		State.HIDDEN:
			if at.y < TapDispatcher.parent_zone_height(simulation.view):
				reveal()
			return false
		State.BUTTONS:
			var action := action_at(at)
			if action != "":
				open_prompt(action)
				return true
			if at.y < TapDispatcher.parent_zone_height(simulation.view):
				_steps_left = HIDE_STEPS
			else:
				close()
			return false
	var surface: ParentSurface = surfaces[state]
	if not surface.covers(at):
		close()
		if at.y < TapDispatcher.parent_zone_height(simulation.view):
			reveal()
		return false
	surface.press(at)
	return true


## Switches to state `to`: shows what it shows, hides the rest.
func _enter(to: State) -> void:
	state = to
	_row.visible = to == State.BUTTONS
	for action in buttons:
		buttons[action].visible = false
	for each in surfaces:
		surfaces[each].visible = each == to
	if surfaces.has(to):
		surfaces[to].opened()
	if simulation != null and to != State.HIDDEN:
		_lay_out()


## Places the buttons (and shows wake early only at bedtime) or the open
## surface for the simulation's screen.
func _lay_out() -> void:
	var view := simulation.view
	if state == State.BUTTONS:
		for action in SLOTS:
			var button: Button = buttons[action]
			var rect := button_rect(action)
			button.position = rect.position
			button.size = rect.size
			button.add_theme_font_size_override("font_size", ParentLayout.font_px(view))
			button.visible = shows(action)
	elif surfaces.has(state):
		var surface: ParentSurface = surfaces[state]
		surface.size = view.screen_size
		surface.lay_out(view)


## The row of buttons and the surfaces: the code prompt, settings, setup. The
## buttons never show a time left: a word each, from
## ParentText (icon + word is the settled look; the word alone for now).
# @spec-link [[rule_time_left_shown_only_behind_code]]
func _build() -> void:
	_row = Control.new()
	_row.name = "Buttons"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.visible = false
	add_child(_row)
	var lang := ParentText.language()
	for action in SLOTS:
		var button := Button.new()
		button.name = action.to_pascal_case()
		button.text = ParentText.text(action, lang)
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.visible = false
		buttons[action] = button
		_row.add_child(button)
	add_surface(State.PROMPT, ParentCodePrompt.new())
	add_surface(State.SETTINGS, ParentSettings.new())
	add_surface(State.SETUP, ParentSetup.new())

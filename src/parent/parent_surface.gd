class_name ParentSurface
extends Control
## One parent surface the parent gate (ParentGate) opens as one of its
## states: the code prompt, settings, setup. The gate owns the input and the
## timing; a surface only draws itself and answers the gate:
## - opened(): the gate entered the surface's state (reset it, start its
##   timers, read gate.pending_action);
## - covers(at): whether a press at screen point `at` is the surface's (it is
##   then swallowed, press and release, and given to press()); false means a
##   tap outside: the gate closes the surface and the tap does its normal job.
##   A surface that fills the screen covers every point;
## - press(at): a press on the surface;
## - step(): once per simulation step while open (60 per second), for its
##   timers, so headless tests fast-forward them with ticks;
## - lay_out(view): place the controls for `view`'s screen (called on open and
##   every frame while open).
## To close or move on, a surface calls gate.close() or gate.open_state().
## Its controls ignore the mouse: every press comes through the gate.

## The gate that opened this surface (set by ParentGate.add_surface).
var gate: ParentGate = null


## The gate entered this surface's state.
func opened() -> void:
	pass


## Whether a press at screen point `at` belongs to this surface (default: it
## fills the screen).
func covers(_at: Vector2) -> bool:
	return true


## A press on the surface at screen point `at`.
func press(_at: Vector2) -> void:
	pass


## One simulation step passed while the surface is open.
func step() -> void:
	pass


## Places the surface's controls for `view`'s screen.
func lay_out(_view: ScreenView) -> void:
	pass

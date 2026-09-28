class_name SessionScreen
extends CanvasModulate
## What the session does to the screen (master spec §5.7): the light drifts
## toward dusk over the wind-down, stays at dusk through bedtime and comes
## back at sunrise (Session.dusk()), tinting the world (not the HUD layers);
## and the screen stays on during a session only: in screensaver mode and at
## bedtime the phone's usual screen timeout applies. It only reads the
## simulation.
##
## Placeholder look: DUSK_COLOUR is a stand-in until the ui_ux tree settles
## the dusk (ux-writer); it is a value here, not a design token.
# @spec-link [[req_session_lifecycle]]

## Placeholder: the world's tint at full dusk.
const DUSK_COLOUR := Color(0.55, 0.52, 0.78)

## The simulation shown.
var simulation: Simulation = null

## Whether the screen is being kept on (null: not set yet).
var _keep_on: Variant = null


func _process(_delta: float) -> void:
	if simulation == null:
		return
	color = Color.WHITE.lerp(DUSK_COLOUR, simulation.session.dusk(simulation.tick))
	var keep_on := simulation.session.phase in [Session.SESSION, Session.WIND_DOWN]
	if keep_on != _keep_on:
		_keep_on = keep_on
		if DisplayServer.get_name() != "headless":
			DisplayServer.screen_set_keep_on(keep_on)

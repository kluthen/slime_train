class_name Autosave
extends RefCounted
## When the game saves on its own (master spec, persistence): every
## INTERVAL_SECONDS of wall time since the last save, and whenever the app
## goes to the background. Pure timing; the game root (src/main.gd) does the
## saving. Wall time, not ticks: a save every 15 s of real time whatever the
## simulation speed.
##
## Background, in Godot 4 notifications (is_background()):
## - NOTIFICATION_APPLICATION_PAUSED: Android and iOS, the app leaves the
##   foreground (the last moment the OS guarantees);
## - NOTIFICATION_APPLICATION_FOCUS_OUT: the window loses focus (desktop,
##   and on phones before a pause);
## - NOTIFICATION_WM_CLOSE_REQUEST: the window is being closed (desktop);
## - NOTIFICATION_WM_GO_BACK_REQUEST: Android's Back (it never quits the app:
##   ScreenPinning sends it to the background unless the screen is pinned).
## The game also saves when its root leaves the tree (quitting).
##
## Test mode turns it off unless the run configuration says "autosave": true.

const INTERVAL_SECONDS := 15.0
## Wall-clock seconds are sums of floats: 130.2 - 115.2 is a hair under 15.
const _SLACK := 1e-6

## Off: never due.
var enabled := true
## Seconds of wall time between saves (tests shorten it).
var interval := INTERVAL_SECONDS

var _last := 0.0


## Starts counting at `now` (seconds of wall time).
func start(now: float) -> void:
	_last = now


## Whether a save is due at `now`.
# @spec-link [[req_persistence_and_saves]]
func due(now: float) -> bool:
	return enabled and now - _last >= interval - _SLACK


## A save was made at `now`: the next is due `interval` later.
func saved(now: float) -> void:
	_last = now


## Whether notification `what` means the app is going to the background (or
## away): save now.
# @spec-link [[req_persistence_and_saves]]
static func is_background(what: int) -> bool:
	return what in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
			Node.NOTIFICATION_WM_CLOSE_REQUEST, Node.NOTIFICATION_WM_GO_BACK_REQUEST]

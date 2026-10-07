class_name PhonePlatform
extends RefCounted
## The phone's own services, behind one small API: screen pinning, the
## device's lock screen (is it secure, ask for its PIN or fingerprint), the
## back gesture's excluded areas, sending the app to the background, the
## display's safe area and its density.
##
## On Android they come from the "SlimePlatform" plugin singleton
## (addons/slime_platform/, the Java plugin), when the build has it
## (for_this_build()). Everywhere else (desktop, the editor, headless tests)
## the same class runs as a desktop stub with no singleton: every call does
## nothing, is_pinned() and is_device_secure() are false, physical_dpi() is
## 0 (unknown), and
## confirm_credential() answers credential_finished(false) on the next idle
## frame (a desktop has no lock screen to confirm).
##
## The game root (src/main.gd) owns one as `platform`. Tests put their own
## first (before the game enters the tree), an inline subclass that records
## the calls and fires credential_finished itself.
##
## Rects are window pixels: the window is edge to edge on the phone, so they
## are the Android decor view's coordinates too.

## Emitted once per confirm_credential(): whether the device's lock screen
## (PIN, pattern, password or biometric) was confirmed.
signal credential_finished(ok: bool)

## The Android plugin singleton's name.
const SINGLETON := "SlimePlatform"

## The Android plugin singleton, or null: the desktop stub.
var _singleton: Object = null
## Whether screen_dpi() has already warned of an implausible physical density.
var _warned_dpi := false


## A platform on `singleton` (the Android plugin), or the desktop stub when null.
func _init(singleton: Object = null) -> void:
	_singleton = singleton
	if _singleton != null:
		_singleton.connect("credential_finished", _on_credential_finished)


## This build's platform: the Android plugin's when the build has it, else
## the desktop stub.
static func for_this_build() -> PhonePlatform:
	if Engine.has_singleton(SINGLETON):
		return PhonePlatform.new(Engine.get_singleton(SINGLETON))
	return PhonePlatform.new()


## Whether this runs on the phone through the plugin (false: the desktop stub).
func is_phone() -> bool:
	return _singleton != null


## Asks Android to pin the screen (it shows its own confirmation, every time).
# @spec-link [[req_screen_pinning]]
func request_pinning() -> void:
	if _singleton != null:
		_singleton.startPinning()


## Ends screen pinning, if the screen is pinned.
# @spec-link [[req_screen_pinning]]
func stop_pinning() -> void:
	if _singleton != null:
		_singleton.stopPinning()


## Whether the screen is pinned now (the parent may have declined, or unpinned).
# @spec-link [[req_screen_pinning]]
func is_pinned() -> bool:
	return _singleton != null and _singleton.isPinned()


## Whether the device has a secure lock screen (PIN, pattern or password).
# @spec-link [[req_parent_gate_and_access]]
func is_device_secure() -> bool:
	return _singleton != null and _singleton.isDeviceSecure()


## Asks for the device's lock screen (its PIN, pattern, password or a
## biometric) with `title` and `subtitle`; the answer comes as
## credential_finished. The desktop stub answers false, deferred, as a phone
## answers after its prompt.
# @spec-link [[req_parent_gate_and_access]]
func confirm_credential(title: String, subtitle: String) -> void:
	if _singleton != null:
		_singleton.confirmCredential(title, subtitle)
	else:
		call_deferred("emit_signal", "credential_finished", false)


## Keeps the back gesture out of `rects` (window pixels); they replace the
## previous ones.
func set_back_gesture_exclusion(rects: Array[Rect2i]) -> void:
	if _singleton == null:
		return
	var flat := PackedInt32Array()
	for rect in rects:
		flat.append_array([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	_singleton.setGestureExclusion(flat)


## Sends the app to the background, as Android's back gesture normally does.
func move_to_background() -> void:
	if _singleton != null:
		_singleton.moveToBackground()


## The display's safe area (clear of cut-outs and rounded corners), screen
## pixels; on the desktop, the window's rect.
func safe_area() -> Rect2i:
	if _singleton != null:
		return DisplayServer.get_display_safe_area()
	return Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())


## The panel's physical density, px per inch (the mean of Android's xdpi and
## ydpi); 0 when unknown (the desktop stub). Some devices report bogus values:
## screen_dpi() checks it.
# @spec-link [[req_parent_gate_and_access]]
func physical_dpi() -> float:
	if _singleton != null:
		return _singleton.getPhysicalDpi()
	return 0.0


## The density to measure millimetres with, px per inch: on the phone the
## panel's physical density when it is plausible against the logical one
## (ScreenView.dpi_for_mm()), else the logical one (DisplayServer's, which
## is all the desktop stub has), warning once when a physical reading is
## refused. The caller refuses a reading of 0 or less.
# @spec-link [[req_parent_gate_and_access]]
func screen_dpi() -> float:
	var logical := float(DisplayServer.screen_get_dpi())
	if _singleton == null:
		return logical
	var physical := physical_dpi()
	if not _warned_dpi and not ScreenView.physical_dpi_plausible(physical, logical):
		_warned_dpi = true
		push_warning("Physical screen density %s dpi implausible against the logical %s: using the logical one"
				% [physical, logical])
	return ScreenView.dpi_for_mm(physical, logical)


## The plugin's answer to confirm_credential(), passed on.
func _on_credential_finished(ok: bool) -> void:
	credential_finished.emit(ok)

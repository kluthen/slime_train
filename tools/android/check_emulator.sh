#!/usr/bin/env bash
# The repeatable parts of checking Slime Train on the Android emulator
# (chunk 20; docs/dev/README.md, "Checking on the emulator (chunk 20)").
#
#   tools/android/check_emulator.sh boot               start the AVD headless, wait for the boot
#   tools/android/check_emulator.sh install [--no-build]
#                                                      export the debug APK (tools/android/export.sh
#                                                      debug) unless --no-build, then adb install -r
#   tools/android/check_emulator.sh launch             start the game's launcher activity
#   tools/android/check_emulator.sh pinned             the lock task state (NONE, PINNED or LOCKED)
#   tools/android/check_emulator.sh focus              the focused app and window
#   tools/android/check_emulator.sh immersive          whether the status and navigation bars show
#   tools/android/check_emulator.sh exclusion          the back-gesture exclusion rects Android keeps
#   tools/android/check_emulator.sh perms              the APKs' permissions, the installed app's
#   tools/android/check_emulator.sh ui                 every window's texts and their bounds (system
#                                                      dialogs included: pinning, BiometricPrompt)
#   tools/android/check_emulator.sh shot <name>        screenshot to $SHOTS/<name>.png (a secure
#                                                      window, the credential prompt, gives an empty file)
#   tools/android/check_emulator.sh tilt <x> <y> <z>   set the accelerometer (m/s², portrait axes)
#   tools/android/check_emulator.sh stop               kill the emulator
#
# Environment: ANDROID_HOME (default ~/Android/Sdk), AVD (default
# S20FE_API_34), SERIAL (default emulator-5554), GPU (the emulator's -gpu
# mode, default host: the software renderer, SwiftShader, fails to link
# Godot's canvas shaders and draws a blank screen), SHOTS (screenshots' folder,
# default /tmp/slime-train-emu; keep them out of the repo), BUILD_TOOLS
# (default: the newest in $ANDROID_HOME/build-tools, for aapt).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sdk="${ANDROID_HOME:-$HOME/Android/Sdk}"
avd="${AVD:-S20FE_API_34}"
gpu="${GPU:-host}"
serial="${SERIAL:-emulator-5554}"
shots="${SHOTS:-/tmp/slime-train-emu}"
package=com.slimetrain.dev
activity=com.godot.game.GodotAppLauncher

adb_bin="$sdk/platform-tools/adb"
adb() { "$adb_bin" -s "$serial" "$@"; }

usage() {
	sed -n '5,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
	exit 2
}

# Waits until the device reports sys.boot_completed=1 (3 minutes at most).
wait_for_boot() {
	adb wait-for-device
	for _ in $(seq 180); do
		if [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then
			return 0
		fi
		sleep 1
	done
	echo "check_emulator.sh: $serial did not finish booting." >&2
	exit 1
}

# The newest build-tools' aapt.
aapt_bin() {
	local tools="${BUILD_TOOLS:-$(ls -d "$sdk"/build-tools/* | sort -V | tail -1)}"
	echo "$tools/aapt"
}

case "${1:-}" in
boot)
	if "$adb_bin" devices | grep -q "^$serial[[:space:]]*device"; then
		echo "$serial is already up."
	else
		"$sdk/emulator/emulator" -avd "$avd" -no-window -no-audio -no-snapshot-save -gpu "$gpu" \
			>"${TMPDIR:-/tmp}/check_emulator-$avd.log" 2>&1 &
		wait_for_boot
		echo "$avd booted as $serial."
	fi
	;;
install)
	if [ "${2:-}" != --no-build ]; then
		"$root/tools/android/export.sh" debug
	fi
	adb install -r "$root/build/slime-train-debug.apk"
	;;
launch)
	adb shell am start -n "$package/$activity"
	;;
pinned)
	adb shell dumpsys activity activities | grep "mLockTaskModeState" || true
	;;
focus)
	adb shell dumpsys window | grep -E "mCurrentFocus|mFocusedApp" || true
	;;
immersive)
	# The insets sources' visibility: hidden bars read visible=false.
	adb shell dumpsys window | grep -oE "InsetsSource id=[0-9a-f]+ type=(statusBars|navigationBars) frame=[^ ]+ visible=[a-z]+" |
		sed 's/ id=[0-9a-f]*//' | sort -u || true
	;;
exclusion)
	adb shell dumpsys window | grep -iE "systemGestureExclusion|GestureExclusion" || true
	;;
perms)
	for apk in "$root"/build/slime-train-*.apk; do
		echo "== $apk"
		"$(aapt_bin)" dump permissions "$apk"
	done
	echo "== installed $package"
	adb shell dumpsys package "$package" | grep -A3 "requested permissions" || true
	;;
ui)
	adb shell uiautomator dump --windows /sdcard/check_emulator_ui.xml >/dev/null
	adb exec-out cat /sdcard/check_emulator_ui.xml | grep -oE '<node [^>]*text="[^"]+"[^>]*' |
		sed -E 's/.*text="([^"]*)".*resource-id="([^"]*)".*bounds="([^"]*)".*/\3 \2 "\1"/' || true
	;;
shot)
	[ -n "${2:-}" ] || usage
	mkdir -p "$shots"
	adb exec-out screencap -p >"$shots/$2.png"
	echo "$shots/$2.png"
	;;
tilt)
	[ $# -eq 4 ] || usage
	adb emu sensor set acceleration "$2:$3:$4"
	;;
stop)
	adb emu kill
	;;
*)
	usage
	;;
esac

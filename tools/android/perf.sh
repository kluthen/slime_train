#!/usr/bin/env bash
# Measures Slime Train on an Android device (the reference phone, or the
# emulator) with the debug build's perf log (src/debug/perf_log.gd: one PERF
# line a second in logcat; docs/dev/README.md, "Measuring on the phone").
# The numbers come from the log, never from screenshots.
#
#   tools/android/perf.sh [--serial=S] [--fixture=NAME|none] [--seconds=N]
#                         [--warm-minutes=M] [--period=P] [--no-build]
#                         [--no-install] [--label=TEXT] [--wipe-save]
#                         [--phase-timers]
#   tools/android/perf.sh --free-play [--minutes=N] [--serial=S] [--period=P]
#                         [--no-build] [--no-install] [--label=TEXT]
#                         [--wipe-save] [--phase-timers]
#
#   --serial=S        the device (adb serial); default: the only one attached
#   --fixture=NAME    fixture mode: a fixture of the test level, played in test
#                     mode (--test-mode --fixture=NAME --seed=1); default
#                     stress-still. --fixture=none: normal play from the
#                     device's own save (it autosaves as usual). A cold window
#                     and a warm window are summarised, then the app is stopped
#   --seconds=N       fixture mode: each window's length, seconds (default 60)
#   --warm-minutes=M  fixture mode: how long the run lasts after the first
#                     PERF line (default 5); the warm window is its last N
#                     seconds. 0: the cold window only
#   --free-play       free-play mode: normal play (no fixture, no test mode),
#                     the user just plays; the whole session is summarised and
#                     the app is left running
#   --minutes=N       free-play mode: stop recording after N minutes (default
#                     0: until Ctrl-C or the app stops)
#   --period=P        the perf log's window, whole seconds (default 1: one
#                     PERF line a second)
#   --no-build        don't export the debug APK (tools/android/export.sh debug)
#   --no-install      don't install it (the installed debug app is measured)
#   --label=TEXT      the session folder's name prefix (default run)
#   --wipe-save       normal play only (--free-play or --fixture=none; refused
#                     with a fixture): the save wipe, the game's --wipe-save
#                     added to slime_args, so the debug app's level saves are
#                     deleted at launch and the level starts fresh. Off by
#                     default. For automated test runs; never with a save and
#                     restore check
#   --phase-timers    the game's phase timers (--phase-timers added to
#                     slime_args, chunk 5N U0a): every PERF line also carries
#                     its window's mean us per tick by phase (phases=), and
#                     the summary splits the tick into solver and behaviour.
#                     The timers cost a few us a tick
#
# It exports and installs the debug APK, clears logcat, starts the app with
# the perf log (the launch intent's "slime_args" extra, read by the
# SlimePlatform plugin in a debuggable build only) and records, for the whole
# session, into build/perf/<label>-<mode>-<timestamp>/ (mode: the fixture's
# name, "normal" for --fixture=none, or "free-play"):
#   logcat.txt   the full `logcat -v threadtime -s godot:* SlimePlatform:*` stream
#                (resumed where it stopped when the adb server restarts: any
#                Godot run on this computer restarts it as it quits)
#   perf.log     a "# " header (device, mode, launch, how it ended), the
#                PERF_INFO line and every PERF line
#   thermal.log  a sample every THERMAL_EVERY s (default 15): "<date>
#                elapsed_s=<s> thermal_status=<n> battery_c=<C>" (dumpsys
#                thermalservice's status, dumpsys battery's temperature)
#   summary.txt  the summary printed at the end
# Ctrl-C (SIGINT) in either mode stops the recording cleanly and summarises
# what was recorded. The summary comes from the log only
# (tools/android/perf_summary.py, which can be run again on a saved session:
# perf_summary.py --thermal=DIR/thermal.log DIR/perf.log). No adb process of
# this script's outlives it.
#
# The player's data is never at risk: this script never uninstalls the app,
# never clears its data (no pm clear) and installs only with "adb install -r"
# (a replacing install keeps the app's data: the saves and the parent code).
# If an install is refused (another signing key), it stops: never uninstall to
# get round it. A fixture run writes no save: test mode's autosave is off
# unless its run asks, and the game reads the player's save only in normal
# play. --fixture=none and --free-play are normal play: they play and autosave
# the device's own save, exactly as opening the app does. The one exception,
# asked for each run: with --wipe-save (off by default), the debug app
# (com.slimetrain.dev, never the release one) deletes its level saves at
# launch (the game's save wipe, chunk 19w); the parent code is kept, and this
# script still never uninstalls the app or clears its data.
#
# Exit: 0 on success (Ctrl-C included); 2 on bad arguments or no (or no
# single) device; 1 when the build or install fails, no PERF line arrives in
# time in fixture mode (or the app stops there), or none was recorded at all.
# Environment: ANDROID_HOME (default ~/Android/Sdk), THERMAL_EVERY (seconds).
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sdk="${ANDROID_HOME:-$HOME/Android/Sdk}"
adb_bin="$sdk/platform-tools/adb"
package=com.slimetrain.dev
activity=com.godot.game.GodotAppLauncher
apk="$root/build/slime-train-debug.apk"
summary_py="$root/tools/android/perf_summary.py"
# The SlimePlatform plugin's logcat tag (its launch arguments, its warnings).
plugin_tag=SlimePlatform
# The thermal and battery sample's period, seconds.
thermal_every="${THERMAL_EVERY:-15}"
# How long to wait for the first PERF line after the launch, and for each
# next one (fixture mode), seconds.
first_line_timeout=180
next_line_timeout=60

serial=""
fixture=""
free_play=0
minutes=""
seconds=""
warm_minutes=""
period=1
build=1
install=1
label=run
wipe_save=0
phase_timers=0

usage() {
	sed -n '7,45p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
	exit 2
}

fail_args() {
	echo "tools/android/perf.sh: $1" >&2
	exit 2
}

for arg in "$@"; do
	case "$arg" in
	--serial=*) serial="${arg#*=}" ;;
	--fixture=*) fixture="${arg#*=}" ;;
	--free-play) free_play=1 ;;
	--minutes=*) minutes="${arg#*=}" ;;
	--seconds=*) seconds="${arg#*=}" ;;
	--warm-minutes=*) warm_minutes="${arg#*=}" ;;
	--period=*) period="${arg#*=}" ;;
	--no-build) build=0 ;;
	--no-install) install=0 ;;
	--label=*) label="${arg#*=}" ;;
	--wipe-save) wipe_save=1 ;;
	--phase-timers) phase_timers=1 ;;
	-h | --help) usage ;;
	*) fail_args "unknown argument '$arg' (--help lists them)" ;;
	esac
done
if [ "$free_play" = 1 ]; then
	[ -z "$fixture$seconds$warm_minutes" ] || fail_args "--free-play takes no --fixture, --seconds or --warm-minutes"
	minutes="${minutes:-0}"
	[[ "$minutes" =~ ^[0-9]+$ ]] || fail_args "--minutes expects a whole number >= 0, got '$minutes'"
	mode=free-play
else
	[ -z "$minutes" ] || fail_args "--minutes is free play's (--free-play); fixture mode takes --warm-minutes"
	fixture="${fixture:-stress-still}"
	seconds="${seconds:-60}"
	warm_minutes="${warm_minutes:-5}"
	[[ "$fixture" =~ ^[a-z0-9-]+$ ]] || fail_args "--fixture expects a fixture name (lowercase letters, digits, hyphens) or none, got '$fixture'"
	[[ "$seconds" =~ ^[0-9]+$ ]] && [ "$seconds" -gt 0 ] || fail_args "--seconds expects a whole number > 0, got '$seconds'"
	[[ "$warm_minutes" =~ ^[0-9]+$ ]] || fail_args "--warm-minutes expects a whole number >= 0, got '$warm_minutes'"
	if [ "$fixture" = none ]; then mode=normal; else mode="$fixture"; fi
	[ "$wipe_save" = 0 ] || [ "$fixture" = none ] || fail_args "--wipe-save is refused with a fixture (here '$fixture'): a fixture run never reads the player's save; use it with --free-play or --fixture=none"
fi
[[ "$period" =~ ^[0-9]+$ ]] && [ "$period" -gt 0 ] || fail_args "--period expects a whole number of seconds > 0, got '$period'"
[[ "$thermal_every" =~ ^[0-9]+$ ]] && [ "$thermal_every" -gt 0 ] || fail_args "THERMAL_EVERY expects a whole number of seconds > 0, got '$thermal_every'"
[[ "$label" =~ ^[A-Za-z0-9._-]+$ ]] || fail_args "--label expects letters, digits, '.', '_' or '-', got '$label'"
[ -x "$adb_bin" ] || fail_args "no adb at $adb_bin (set ANDROID_HOME)"
command -v python3 >/dev/null || fail_args "python3 is needed for the summary (tools/android/perf_summary.py)"

# The devices adb sees in the "device" state.
attached() {
	"$adb_bin" devices | awk 'NR > 1 && $2 == "device" { print $1 }'
}

# Picks the serial (the only device when none is given) and checks it is attached.
pick_device() {
	if [ -z "$serial" ]; then
		local devices
		devices="$(attached)"
		case "$(printf '%s' "$devices" | grep -c .)" in
		0) fail_args "no device attached (adb devices)" ;;
		1) serial="$devices" ;;
		*) fail_args "several devices attached: choose one with --serial= ($(echo $devices))" ;;
		esac
	fi
	attached | grep -qx "$serial" || fail_args "device $serial is not attached (adb devices)"
}

adb() { "$adb_bin" -s "$serial" "$@"; }

pick_device

if [ "$build" = 1 ]; then
	"$root/tools/android/export.sh" debug || {
		echo "tools/android/perf.sh: the debug export failed." >&2
		exit 1
	}
	# The headless export restarts the adb server: wait for the device again.
	timeout 60 "$adb_bin" -s "$serial" wait-for-device || fail_args "device $serial did not come back after the export"
fi
if [ "$install" = 1 ]; then
	[ -f "$apk" ] || {
		echo "tools/android/perf.sh: no $apk (drop --no-build)." >&2
		exit 1
	}
	# -r only: a replacing install keeps the app's data (never uninstall).
	adb install -r "$apk" || {
		echo "tools/android/perf.sh: adb install -r refused the APK; the app and its data are untouched." >&2
		echo "Never uninstall or clear the app to get round it (the data holds the parent code)." >&2
		exit 1
	}
fi
adb shell pm path "$package" >/dev/null 2>&1 || {
	echo "tools/android/perf.sh: $package is not installed on $serial (drop --no-install)." >&2
	exit 1
}

prop() { adb shell getprop "$1" | tr -d '\r'; }
# The battery's temperature in C (dumpsys battery gives tenths), or "unavailable".
battery_c() {
	local temp
	temp="$(adb shell dumpsys battery 2>/dev/null | tr -d '\r' | awk -F': ' '/temperature/ { printf "%.1f", $2 / 10; exit }')"
	echo "${temp:-unavailable}"
}
# The thermal status (0 none .. 6 shutdown), or "unavailable".
thermal_status() {
	local status
	status="$(adb shell dumpsys thermalservice 2>/dev/null | tr -d '\r' | awk -F': ' '/Thermal Status/ { print $2; exit }')"
	echo "${status:-unavailable}"
}

model="$(prop ro.product.manufacturer) $(prop ro.product.model)"
android="$(prop ro.build.version.release) (API $(prop ro.build.version.sdk))"

if [ "$free_play" = 1 ] || [ "$fixture" = none ]; then
	slime_args="--perf-log=$period"
	# The save wipe (normal play only: refused with a fixture above).
	[ "$wipe_save" = 0 ] || slime_args="$slime_args,--wipe-save"
else
	slime_args="--test-mode,--fixture=$fixture,--seed=1,--perf-log=$period"
fi
[ "$phase_timers" = 0 ] || slime_args="$slime_args,--phase-timers"

stamp="$(date +%Y%m%d-%H%M%S)"
out_dir="$root/build/perf/$label-$mode-$stamp"
mkdir -p "$out_dir"
logcat_file="$out_dir/logcat.txt"
thermal_file="$out_dir/thermal.log"
perf_file="$out_dir/perf.log"
summary_file="$out_dir/summary.txt"

logcat_pid=""
sampler_pid=""
start_s=$SECONDS

# The pids below $1, depth first.
descendants() {
	local child
	for child in $(pgrep -P "$1"); do
		echo "$child"
		descendants "$child"
	done
}

# Stops the background process $1 and everything it started (an adb call
# in flight included), and reaps it.
stop_background() {
	[ -n "$1" ] || return 0
	local below
	below="$(descendants "$1")"
	kill "$1" 2>/dev/null
	[ -n "$below" ] && kill $below 2>/dev/null
	wait "$1" 2>/dev/null
	return 0
}

# The timestamp ("MM-DD hh:mm:ss.mmm") of logcat.txt's last line, or "".
last_stamp() {
	grep -oE '^[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}' "$logcat_file" | tail -1
}

# Appends the logcat stream to logcat.txt, until stopped. Anything that runs
# Godot on this computer (the editor, an export, the tests) restarts the adb
# server when it quits, which ends a logcat stream: the stream is then
# resumed from logcat.txt's last timestamp (logcat -T; the lines logged in
# between are still in the device's buffer), keeping only the newer lines.
record_logcat() {
	local since
	while true; do
		timeout 30 "$adb_bin" -s "$serial" wait-for-device 2>/dev/null
		since="$(last_stamp)"
		if [ -z "$since" ]; then
			"$adb_bin" -s "$serial" logcat -v threadtime -s 'godot:*' "$plugin_tag:*" >>"$logcat_file" 2>/dev/null
		else
			"$adb_bin" -s "$serial" logcat -v threadtime -T "$since" -s 'godot:*' "$plugin_tag:*" 2>/dev/null \
				| awk -v since="$since" 'substr($0, 1, 18) > since { print; fflush() }' >>"$logcat_file"
		fi
		sleep 1
	done
}

# Appends one thermal and battery sample to thermal.log.
sample() {
	printf '%s elapsed_s=%d thermal_status=%s battery_c=%s\n' "$(date -Iseconds)" $((SECONDS - start_s)) \
		"$(thermal_status)" "$(battery_c)" >>"$thermal_file"
}

# Samples every thermal_every seconds, until stopped.
sampler() {
	while true; do
		sleep "$thermal_every"
		sample
	done
}

# Stops both background recorders (idempotent).
stop_recording() {
	stop_background "$logcat_pid"
	logcat_pid=""
	stop_background "$sampler_pid"
	sampler_pid=""
}
trap stop_recording EXIT

interrupted=0
on_interrupt() {
	interrupted=1
	echo >&2
	echo "tools/android/perf.sh: Ctrl-C: stopping the recording..." >&2
}
trap on_interrupt INT

adb logcat -c || echo "tools/android/perf.sh: warning: logcat -c failed; old lines may show." >&2
: >"$logcat_file"
record_logcat &
logcat_pid=$!
sample
sampler &
sampler_pid=$!
echo "Recording to $out_dir"
echo "Launching $package on $serial ($model), $mode, with: $slime_args"
adb shell am start -S -W -n "$package/$activity" --esa slime_args "$slime_args" >/dev/null || {
	echo "tools/android/perf.sh: am start failed." >&2
	exit 1
}

perf_lines() { grep -o 'PERF t=.*' "$logcat_file" | tr -d '\r'; }
perf_count() { grep -c 'PERF t=' "$logcat_file"; }
# The t= of the PERF line number $1 (1-based), or of the last one with "last".
perf_t() {
	if [ "$1" = last ]; then
		perf_lines | tail -1 | sed -E 's/^PERF t=([0-9.]+).*/\1/'
	else
		perf_lines | sed -n "${1}p" | sed -E 's/^PERF t=([0-9.]+).*/\1/'
	fi
}
# Whether the app is running. False only when the device answers that it
# isn't: an adb call that fails (the adb server restarting) counts as running.
app_running() {
	local answer
	answer="$(adb shell "pidof $package || echo none" 2>/dev/null | tr -d '\r')"
	[ "$answer" != none ]
}

# How the session ended (perf.log's header), and whether that is a failure.
ended=""
failed=0

# Waits until logcat.txt holds at least $1 PERF lines. Returns 0 then; 1
# (setting ended) on Ctrl-C, when none new comes within $2 seconds, or when
# the app stops.
wait_for_lines() {
	local want="$1" limit="$2" last_count waited=0
	last_count="$(perf_count)"
	while [ "$(perf_count)" -lt "$want" ]; do
		[ "$interrupted" = 1 ] && { ended="interrupted (Ctrl-C)"; return 1; }
		sleep 1
		waited=$((waited + 1))
		if [ "$(perf_count)" != "$last_count" ]; then
			last_count="$(perf_count)"
			waited=0
		fi
		if [ "$waited" -ge "$limit" ]; then
			ended="failed: no PERF line within $limit s"
			failed=1
			return 1
		fi
		# A Ctrl-C kills the adb call in flight too: it is not the app stopping.
		if ! app_running && [ "$interrupted" = 0 ]; then
			ended="failed: the app stopped"
			failed=1
			return 1
		fi
	done
	[ "$interrupted" = 1 ] && { ended="interrupted (Ctrl-C)"; return 1; }
	return 0
}

# Fixture mode: the cold window, then the run until M minutes after the first line.
run_fixture() {
	local window_lines=$(((seconds + period - 1) / period)) t0 end_t
	wait_for_lines 1 "$first_line_timeout" || return
	t0="$(perf_t 1)"
	echo "First PERF line at t=$t0 s; cold window: $window_lines lines ($seconds s)."
	wait_for_lines "$window_lines" "$next_line_timeout" || return
	if [ "$warm_minutes" -gt 0 ]; then
		echo "Running until $warm_minutes min after the first PERF line (Ctrl-C stops early)..."
		end_t="$(awk -v a="$t0" -v m="$warm_minutes" 'BEGIN { print a + m * 60 - 0.5 }')"
		while awk -v t="$(perf_t last)" -v end="$end_t" 'BEGIN { exit !(t < end) }'; do
			wait_for_lines $(($(perf_count) + 1)) "$next_line_timeout" || return
		done
	fi
	ended="completed"
}

# Free-play mode: records until the minutes are up, Ctrl-C, or the app stops.
run_free_play() {
	local deadline=$((SECONDS + minutes * 60)) ticks=0
	if [ "$minutes" -gt 0 ]; then
		echo "Play! Recording for $minutes min (Ctrl-C stops early)..."
	else
		echo "Play! Recording until Ctrl-C (or the app stops)..."
	fi
	while true; do
		[ "$interrupted" = 1 ] && { ended="interrupted (Ctrl-C)"; return; }
		if [ "$minutes" -gt 0 ] && [ "$SECONDS" -ge "$deadline" ]; then
			ended="completed ($minutes min)"
			return
		fi
		if [ $((ticks % 5)) = 0 ] && ! app_running && [ "$interrupted" = 0 ]; then
			ended="the app stopped"
			return
		fi
		sleep 1
		ticks=$((ticks + 1))
	done
}

if [ "$free_play" = 1 ]; then
	run_free_play
else
	run_fixture
fi
# Ctrl-C from here on changes nothing: the recording is stopping anyway.
trap '' INT
if [ "$free_play" = 0 ]; then
	adb shell am force-stop "$package"
	sleep 1
fi
sample
stop_recording
echo "Session $ended after $((SECONDS - start_s)) s."

{
	echo "# tools/android/perf.sh $* ($stamp)"
	echo "# device $serial: $model, Android $android"
	if [ "$free_play" = 1 ]; then
		echo "# mode free-play, minutes $minutes (0: until Ctrl-C), period $period s"
	else
		echo "# mode fixture $fixture, windows of $seconds s, warm after $warm_minutes min, period $period s"
	fi
	echo "# launch: --esa slime_args $slime_args"
	echo "# ended: $ended, after $((SECONDS - start_s)) s"
	grep -oE 'PERF(_INFO)? .*' "$logcat_file" | tr -d '\r'
} >"$perf_file"

summary_args=(--thermal="$thermal_file")
if [ "$free_play" = 0 ]; then
	summary_args+=(--cold="$seconds")
	[ "$warm_minutes" -gt 0 ] && summary_args+=(--warm="$seconds")
fi
echo
python3 "$summary_py" "${summary_args[@]}" "$perf_file" | tee "$summary_file"
summary_status=${PIPESTATUS[0]}
errors="$(grep -cE 'godot *: (SCRIPT )?ERROR' "$logcat_file")"
if [ "$errors" -gt 0 ]; then
	{
		echo "Warning: $errors error lines in logcat's godot tag; the first:"
		grep -E 'godot *: (SCRIPT )?ERROR' "$logcat_file" | head -3
	} | tee -a "$summary_file"
fi
echo "Files: $out_dir/{logcat.txt,perf.log,thermal.log,summary.txt}"
if [ "$failed" = 1 ]; then
	echo "tools/android/perf.sh: $ended; logcat's last godot lines:" >&2
	tail -20 "$logcat_file" >&2
	exit 1
fi
[ "$summary_status" = 0 ] || exit 1
exit 0

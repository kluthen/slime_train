#!/usr/bin/env bash
# Measures Slime Train on the desktop with the debug build's perf log
# (src/debug/perf_log.gd), slowed down to something nearer a phone: the game
# (or only its main thread, --pin=main) is pinned to one CPU core that busy
# loops ("hogs") pinned to the same core share with it, so it gets about
# 1/(HOGS+1) of that core. The numbers come from the PERF lines, summarised
# by tools/android/perf_summary.py.
#
#   tools/perf_slow.sh [--hogs=N] [--cpu=C] [--pin=process|main] [--seconds=S]
#                      [--full-speed] [--max-fps=N] <fixture> [extra user arguments...]
#
#   --hogs=N        busy loops sharing the game's core (default 2)
#   --cpu=C         the core, 0-based (default: the last one, nproc - 1)
#   --pin=WHAT      what is pinned to that core (default process):
#                   process  the whole Godot process from its start, every
#                            thread (Godot's and the GL driver's helpers
#                            included) sharing the one slowed core;
#                   main     only the main thread: Godot starts unpinned,
#                            and once it has run PIN_MAIN_AFTER s (loaded)
#                            its main thread alone is pinned (taskset -p,
#                            without -a); the threads it made meanwhile keep
#                            every core, as on a phone's 8 cores. Pinning the
#                            whole process serializes those helper threads
#                            onto the game's core: measured at full speed on
#                            one core, the frame outside the tick went from
#                            3.0 to 11.6 ms with every drawn part's cost
#                            unchanged, which a phone doesn't do.
#   --seconds=S     how long to measure, whole seconds (default 30); the game
#                   gets S + 12 s in all, for its start
#   --full-speed    no pinning, no busy loop: the desktop's own speed
#   --max-fps=N     caps the frame rate at N (Godot's --max-fps; default 0,
#                   no cap). At 60, a frame the game keeps up with holds one
#                   tick, as on a 60 Hz phone, so the parts' ms per frame are
#                   the cost of a real frame, not diluted over frames without
#                   a tick (the redraw-on-change nodes skip those)
#   <fixture>       a fixture of the test level, played in test mode
#   extra arguments go to the game after the others (for example
#                   --max-ticks-per-frame=1, or --phase-timers: each PERF
#                   line then carries the mean us per tick by phase, and the
#                   summary splits the tick into solver and behaviour)
#
# It runs, windowed (DISPLAY, default :0):
#   godot --path . --disable-vsync --max-fps <N> -- --test-mode --fixture=<fixture> --seed=1
#         --perf-log=2 [extra...]
# teeing its stdout to
# build/perf/desktop-<fixture>-<slow|slow-main|full>-<timestamp>.log,
# then prints the summary. The busy loops are killed on exit, Ctrl-C included.
# With --pin=main, the first PIN_MAIN_AFTER s run with the main thread on
# any core (the load and the perf log's first window), and threads the main
# thread starts after the pin inherit its core.
# Exit code: the summary's (0; 1 when the log holds no PERF line); 2 on bad
# arguments, a failed import or (--pin=main) a failed pin; the game's own
# when it fails before the time runs out.
# Set GODOT to use another Godot binary (default: godot on the PATH).
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
USAGE="usage: tools/perf_slow.sh [--hogs=N] [--cpu=C] [--pin=process|main] [--seconds=S] [--full-speed] [--max-fps=N] <fixture> [extra args...]"
# --pin=main: seconds Godot runs unpinned (its load) before its main thread is pinned.
PIN_MAIN_AFTER=3

hogs=2
cpu=$(($(nproc) - 1))
seconds=30
pin_what=process
full_speed=0
max_fps=0
fixture=""
while [ $# -gt 0 ]; do
	case "$1" in
		--hogs=*) hogs="${1#*=}" ;;
		--cpu=*) cpu="${1#*=}" ;;
		--pin=*) pin_what="${1#*=}" ;;
		--seconds=*) seconds="${1#*=}" ;;
		--full-speed) full_speed=1 ;;
		--max-fps=*) max_fps="${1#*=}" ;;
		-h|--help) echo "$USAGE"; exit 0 ;;
		--*) echo "tools/perf_slow.sh: unknown option '$1'" >&2; echo "$USAGE" >&2; exit 2 ;;
		*) fixture="$1"; shift; break ;;
	esac
	shift
done
extra=("$@")

fail_usage() {
	echo "tools/perf_slow.sh: $1" >&2
	echo "$USAGE" >&2
	exit 2
}
[ -n "$fixture" ] || fail_usage "a fixture is needed"
[[ "$hogs" =~ ^[0-9]+$ ]] || fail_usage "--hogs expects a whole number >= 0, got '$hogs'"
[[ "$seconds" =~ ^[0-9]+$ ]] && [ "$seconds" -gt 0 ] || fail_usage "--seconds expects a whole number > 0, got '$seconds'"
[[ "$cpu" =~ ^[0-9]+$ ]] && [ "$cpu" -lt "$(nproc)" ] || fail_usage "--cpu expects a core in 0..$(($(nproc) - 1)), got '$cpu'"
[[ "$max_fps" =~ ^[0-9]+$ ]] || fail_usage "--max-fps expects a whole number >= 0, got '$max_fps'"
[ "$pin_what" = process ] || [ "$pin_what" = main ] || fail_usage "--pin expects 'process' or 'main', got '$pin_what'"
if [ "$full_speed" -eq 0 ] && ! command -v taskset >/dev/null; then
	echo "tools/perf_slow.sh: taskset (util-linux) is needed to slow the game down; or use --full-speed" >&2
	exit 2
fi

# Import first, so classes added by a pull are registered.
if ! import_log="$("$GODOT" --headless --import 2>&1)"; then
	echo "$import_log" >&2
	echo "tools/perf_slow.sh: the Godot import failed." >&2
	exit 2
fi

pids=()
kill_hogs() {
	if [ ${#pids[@]} -gt 0 ]; then
		kill "${pids[@]}" 2>/dev/null
		wait "${pids[@]}" 2>/dev/null
		pids=()
	fi
}
# --pin=main: the file Godot's PID is written to, and the one marking a failed pin.
pid_file=""
pin_failed_file=""
clean_up() {
	kill_hogs
	rm -f "$pid_file" "$pin_failed_file"
}
trap clean_up EXIT
trap 'clean_up; exit 130' INT TERM

speed=full
pin=()
launch=()
if [ "$full_speed" -eq 0 ]; then
	for _ in $(seq "$hogs"); do
		taskset -c "$cpu" sh -c 'while :; do :; done' &
		pids+=($!)
	done
	if [ "$pin_what" = process ]; then
		speed=slow
		pin=(taskset -c "$cpu")
		echo "tools/perf_slow.sh: slowed: the game on core $cpu, shared with $hogs busy loop(s)"
	else
		speed=slow-main
		pid_file="$(mktemp)"
		pin_failed_file="$(mktemp -u)"
		# Godot keeps the PID of the sh that writes it (exec).
		launch=(sh -c 'echo "$$" >"$0"; exec "$@"' "$pid_file")
		# Waits for Godot's PID, lets it load PIN_MAIN_AFTER s, then pins its
		# main thread alone (no -a). A failed pin stops the game: the run
		# would measure something else.
		(
			pid=""
			while [ -z "$pid" ]; do
				sleep 0.1
				pid="$(cat "$pid_file")"
			done
			sleep "$PIN_MAIN_AFTER"
			kill -0 "$pid" 2>/dev/null || exit 0
			if taskset -p -c "$cpu" "$pid" >/dev/null; then
				echo "tools/perf_slow.sh: main thread of Godot ($pid) pinned to core $cpu"
			else
				echo "tools/perf_slow.sh: couldn't pin Godot's main thread ($pid); stopping the game" >&2
				touch "$pin_failed_file"
				kill "$pid"
			fi
		) &
		pids+=($!)
		echo "tools/perf_slow.sh: slowed: the game's main thread on core $cpu after ${PIN_MAIN_AFTER} s, shared with $hogs busy loop(s)"
	fi
else
	echo "tools/perf_slow.sh: full speed"
fi

mkdir -p build/perf
log="build/perf/desktop-$fixture-$speed-$(date +%Y%m%d-%H%M%S).log"
echo "tools/perf_slow.sh: ${seconds} s measured, log $log"
env DISPLAY="${DISPLAY:-:0}" "${pin[@]}" timeout "$((seconds + 12))" "${launch[@]}" \
	"$GODOT" --path . --disable-vsync --max-fps "$max_fps" -- --test-mode --fixture="$fixture" --seed=1 --perf-log=2 "${extra[@]}" \
	| tee "$log"
code=${PIPESTATUS[0]}
kill_hogs
if [ -n "$pin_failed_file" ] && [ -e "$pin_failed_file" ]; then
	exit 2
fi
# 124: timeout ended the run, as meant.
if [ "$code" -ne 0 ] && [ "$code" -ne 124 ]; then
	echo "tools/perf_slow.sh: the game exited with code $code" >&2
	exit "$code"
fi

echo
python3 tools/android/perf_summary.py "$log"

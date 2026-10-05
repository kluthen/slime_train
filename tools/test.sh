#!/usr/bin/env bash
# Runs the whole test suite headless with GUT.
# Exit code: 0 when every test passes, non-zero otherwise.
# Extra arguments go to GUT, for example:
#   tools/test.sh -gselect=test_smoke     (only scripts whose name contains it)
#   tools/test.sh -gunit_test_name=runner (only tests whose name contains it)
# Set GODOT to use another Godot binary (default: godot on the PATH).
#
# The simulation tick (chunk 5N, src/sim/tick_choice.gd): the suite runs on
# the native tick, SLIME_TICK=native unless the environment says otherwise.
# The Linux debug library of the slime_native extension is built first when
# it is missing or older than its sources (tools/build_native.sh), and the
# run fails when it can't be built: it never falls back to the GDScript tick
# on its own. SLIME_TICK=gdscript runs the suite on the GDScript tick, and
# needs no library (the native tests are then pending if it is missing).
#
# The GDScript tick keeps its own tests: after the whole suite on the native
# tick, a second pass runs the slime tests again on the GDScript tick
# (SLIME_TICK=gdscript, -gselect=test_slime_, the other arguments kept).
# Not after a selection (an argument -gselect, -gtest, -gunit_test_name,
# -ginner_class or -gdir), nor when the first pass ran on the GDScript tick.
# The exit code is the first failing pass's.
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

SLIME_TICK="${SLIME_TICK:-native}"
export SLIME_TICK
native_lib=addons/slime_native/bin/libslime_native.linux.template_debug.x86_64.so
if [ "$SLIME_TICK" != gdscript ]; then
	if [ ! -f "$native_lib" ] || [ -n "$(find native/slime_native/SConstruct native/slime_native/src \
		-newer "$native_lib" -print -quit)" ]; then
		if ! tools/build_native.sh; then
			echo "tools/test.sh: building $native_lib failed (see docs/dev/native.md);" >&2
			echo "  SLIME_TICK=gdscript tools/test.sh runs the suite on the GDScript tick." >&2
			exit 2
		fi
	fi
	if [ ! -f "$native_lib" ]; then
		echo "tools/test.sh: $native_lib is missing after the build." >&2
		exit 2
	fi
fi

# Import first. On a fresh clone GUT's class names aren't registered yet, and
# GUT would then quit with code 0 without running a single test. The import
# also lists the extension in .godot/extension_list.cfg, so it loads at startup.
if ! import_log="$("$GODOT" --headless --import 2>&1)"; then
	echo "$import_log"
	echo "tools/test.sh: the Godot import failed." >&2
	exit 2
fi

# The post-run hook (tests/gut_post_run.gd) writes this marker when the suite
# really ran. GUT can quit early with code 0 (nothing matched a selection, for
# example); a missing marker turns that into a failure.
marker="$(mktemp)"
trap 'rm -f "$marker"' EXIT

# One GUT run with the arguments given: its exit code, 3 when GUT quit
# without running the suite.
run_gut() {
	rm -f "$marker"
	SLIME_TEST_MARKER="$marker" "$GODOT" --headless -s res://addons/gut/gut_cmdln.gd "$@"
	local code=$?
	if [ "$code" -eq 0 ] && [ ! -f "$marker" ]; then
		echo "tools/test.sh: GUT exited without running the suite." >&2
		return 3
	fi
	return "$code"
}

selected=false
for arg in "$@"; do
	case "$arg" in
	-gselect=* | -gtest=* | -gunit_test_name=* | -ginner_class=* | -gdir=*) selected=true ;;
	esac
done

run_gut "$@"
status=$?

if [ "$SLIME_TICK" != gdscript ] && ! $selected; then
	echo "tools/test.sh: second pass, the slime tests on the GDScript tick (SLIME_TICK=gdscript -gselect=test_slime_)."
	export SLIME_TICK=gdscript
	run_gut "$@" -gselect=test_slime_
	second=$?
	if [ "$status" -eq 0 ]; then
		status=$second
	fi
fi
exit "$status"

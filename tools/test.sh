#!/usr/bin/env bash
# Runs the whole test suite headless with GUT.
# Exit code: 0 when every test passes, non-zero otherwise.
# Extra arguments go to GUT, for example:
#   tools/test.sh -gselect=test_smoke     (only scripts whose name contains it)
#   tools/test.sh -gunit_test_name=runner (only tests whose name contains it)
# Set GODOT to use another Godot binary (default: godot on the PATH).
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

# Import first. On a fresh clone GUT's class names aren't registered yet, and
# GUT would then quit with code 0 without running a single test.
if ! import_log="$("$GODOT" --headless --import 2>&1)"; then
	echo "$import_log"
	echo "tools/test.sh: the Godot import failed." >&2
	exit 2
fi

# The post-run hook (tests/gut_post_run.gd) writes this marker when the suite
# really ran. GUT can quit early with code 0 (nothing matched a selection, for
# example); a missing marker turns that into a failure.
marker="$(mktemp)"
rm -f "$marker"
trap 'rm -f "$marker"' EXIT

SLIME_TEST_MARKER="$marker" "$GODOT" --headless -s res://addons/gut/gut_cmdln.gd "$@"
status=$?

if [ "$status" -eq 0 ] && [ ! -f "$marker" ]; then
	echo "tools/test.sh: GUT exited without running the suite." >&2
	exit 3
fi
exit "$status"

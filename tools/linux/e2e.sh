#!/usr/bin/env bash
# Runs the end-to-end suite (tests/e2e/) headless with GUT inside the exported
# Linux debug build, not the editor (DoD 31: the automated end-to-end suite
# on the test level passes on the Linux build).
#
#   tools/linux/e2e.sh                exports (tools/linux/export.sh), then runs
#   tools/linux/e2e.sh --no-export    reuses build/linux/slime-train-debug.x86_64
#   tools/linux/e2e.sh -gselect=test_session_e2e   extra arguments go to GUT
#
# Exit code: 0 when every test passes, non-zero otherwise (1: a test failed
# or a test script did not load; 2: bad use, or the export failed; 3: GUT
# quit without running the suite; 124: the run hung past the time limit).
#
# How: an export template has no `-s` (--script) option, so for this run an
# override.cfg next to the binary makes tests/export_runner/gut_runner.tscn
# the main scene; it starts GUT's command-line runner. The override is
# removed on the way out, so the binary starts the game again afterwards.
#
# Editor-only test files (EDITOR_ONLY below) are left out: they need what an
# exported build does not have, listed with the reason for each.
# Environment: GODOT (see tools/linux/export.sh), E2E_TIMEOUT (seconds the
# whole run may take, default 3600).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out_dir="$root/build/linux"
binary="$out_dir/slime-train-debug.x86_64"
override="$out_dir/override.cfg"

# Test files of tests/e2e/ that only run in the editor (proposed list). An
# export template refuses `--path` and has no `-s`, and an exported build's
# res:// is its read-only pack: what a test writes there lands next to the
# binary, where DirAccess on res:// doesn't see it.
EDITOR_ONLY=(
	# The level-rules checker's command line is `godot -s tools/check_level.gd`.
	test_level_checker
	# Builds levels in res://levels/ at run time, then lists them by folder.
	test_level_selection_e2e
	# The level tools (make_fixture, level_report, tools/level.sh) run with
	# `-s` and write levels and fixtures in res://levels/.
	test_level_tools_e2e
	# The new-level scaffolder writes a level, its fixture and its test in
	# res:// and runs them with `-s`.
	test_new_level_e2e
)

do_export=1
if [ "${1:-}" = "--no-export" ]; then
	do_export=0
	shift
fi

if [ "$do_export" = 1 ]; then
	"$root/tools/linux/export.sh" >/dev/null || exit 2
elif [ ! -x "$binary" ]; then
	echo "tools/linux/e2e.sh: no build at $binary (run without --no-export)." >&2
	exit 2
fi

# The test scripts to run: every tests/e2e/test_*.gd but the editor-only ones.
tests=()
for path in "$root"/tests/e2e/test_*.gd; do
	name="$(basename "$path" .gd)"
	skip=0
	for excluded in "${EDITOR_ONLY[@]}"; do
		if [ "$name" = "$excluded" ]; then
			skip=1
		fi
	done
	if [ "$skip" = 0 ]; then
		tests+=("-gtest=res://tests/e2e/$name.gd")
	fi
done

# The post-run hook (tests/gut_post_run.gd) writes this marker when the suite
# really ran; see tools/test.sh.
marker="$(mktemp)"
rm -f "$marker"
cleanup() {
	rm -f "$marker" "$override"
}
trap cleanup EXIT
printf '[application]\n\nrun/main_scene="res://tests/export_runner/gut_runner.tscn"\n' >"$override"

set +e
SLIME_TEST_MARKER="$marker" timeout "${E2E_TIMEOUT:-3600}" "$binary" --headless \
	-gconfig= "${tests[@]}" -gprefix=test_ -gsuffix=.gd \
	-gpost_run_script=res://tests/gut_post_run.gd -glog=1 -gexit "$@"
status=$?
set -e

if [ "$status" -eq 0 ] && [ ! -f "$marker" ]; then
	echo "tools/linux/e2e.sh: GUT exited without running the suite." >&2
	exit 3
fi
exit "$status"

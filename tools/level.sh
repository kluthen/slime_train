#!/usr/bin/env bash
# Runs a level-design tool headless (docs/dev/level-tooling.md), the way a
# designer should: it imports the project first, so classes added by a pull
# are registered (without it a tool can fail to parse, "Identifier
# "LevelBuilder" not declared in the current scope"), and starts Godot
# without its banner (--no-header), so that a tool's --json output is the
# only thing on stdout.
#
#   tools/level.sh <tool> [arguments...]
#
#   check     tools/check_level.gd   the level-rules checker
#   report    tools/level_report.gd  the level report
#   new       tools/new_level.gd     the new-level scaffolder
#   fixture   tools/make_fixture.gd  a level's fixtures
#   bench     tools/bench_level.gd   a level's tick cost
#   rest      tools/bench_rest.gd    the resting-pile rule measured (test level)
#
# The arguments go to the tool (for example: tools/level.sh check
# --level=01 --fast). Exit code: the tool's; 2 when the import fails or the
# tool is unknown (the tools use 2 for "can't run" too).
# Set GODOT to use another Godot binary (default: godot on the PATH).
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
USAGE="usage: tools/level.sh check|report|new|fixture|bench|rest [arguments...]"

case "${1:-}" in
	check) script=check_level ;;
	report) script=level_report ;;
	new) script=new_level ;;
	fixture) script=make_fixture ;;
	bench) script=bench_level ;;
	rest) script=bench_rest ;;
	*)
		echo "tools/level.sh: unknown tool '${1:-}'" >&2
		echo "$USAGE" >&2
		exit 2
		;;
esac
shift

if ! import_log="$("$GODOT" --headless --import 2>&1)"; then
	echo "$import_log" >&2
	echo "tools/level.sh: the Godot import failed." >&2
	exit 2
fi

exec "$GODOT" --headless --no-header --path . -s "res://tools/$script.gd" -- "$@"

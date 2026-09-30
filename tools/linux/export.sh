#!/usr/bin/env bash
# Exports Slime Train as a Linux desktop debug build from the command line
# (preset "Linux debug" of export_presets.cfg): the build where the automated
# end-to-end suite runs (tools/linux/e2e.sh).
#
#   tools/linux/export.sh    build/linux/slime-train-debug.x86_64
#                            and its build/linux/slime-train-debug.pck
#
# A debug build: test mode and the debug overlay only run in one. The export
# log goes to build/linux/export.log (shown when the export fails); the path
# of the binary is printed on success.
# Environment: GODOT (default: godot on the PATH, version 4.7.2, with the
# Linux export templates of that version installed).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-godot}"
preset="Linux debug"
out_dir="$root/build/linux"
binary="$out_dir/slime-train-debug.x86_64"
pck="$out_dir/slime-train-debug.pck"
log="$out_dir/export.log"

mkdir -p "$out_dir"
rm -f "$binary" "$pck"
if ! "$GODOT" --headless --path "$root" --export-debug "$preset" "$binary" >"$log" 2>&1; then
	tail -n 30 "$log"
	echo "tools/linux/export.sh: the export failed (full log: $log)." >&2
	exit 1
fi

if [ ! -f "$binary" ] || [ ! -f "$pck" ]; then
	tail -n 30 "$log"
	echo "tools/linux/export.sh: the export did not produce $binary and $pck." >&2
	exit 1
fi
echo "$binary"

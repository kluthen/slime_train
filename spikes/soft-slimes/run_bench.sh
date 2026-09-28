#!/usr/bin/env bash
# Spike 1 (throwaway): runs the soft-slime benchmark matrix, windowed, and
# prints one RESULT line per run (with the 1-minute load average, since other
# processes on the machine skew the numbers).
#   spikes/soft-slimes/run_bench.sh [extra spike args...]
set -u
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
RES="${RES:-1920x1080}"
WARMUP="${WARMUP:-5}"
MEASURE="${MEASURE:-5}"

run() { # renderer mode points draw field_scale
	local load
	load=$(cut -d' ' -f1 /proc/loadavg)
	"$GODOT" --path . --rendering-method "$1" --resolution "$RES" spikes/soft-slimes/spike.tscn \
		-- --bench --mode="$2" --points="$3" --draw="$4" --field-scale="$5" \
		--warmup="$WARMUP" --measure="$MEASURE" "${@:6}" 2>&1 \
		| grep '^RESULT' | sed "s/\$/ load=$load/"
}

for renderer in gl_compatibility mobile; do
	for mode in still moving; do
		for points in 16 12 8; do
			run "$renderer" "$mode" "$points" blend 1.0 "$@"
			run "$renderer" "$mode" "$points" blend 0.5 "$@"
			run "$renderer" "$mode" "$points" direct 1.0 "$@"
		done
	done
done

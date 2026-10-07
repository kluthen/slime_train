#!/bin/bash
# run.sh <pacing> <geyser on|off> <fixture> <seed> <ticks> <tag> [extra probe args...]
# The dip-jam probe with SLIME_DIPJAM=g,r (phase 2b's pick), SLIME_PACING=<pacing>
# ("" none), the geyser on or off; s3-basket-59of60 with the camera held on the start
# from 9000 (phase 2b's measure). Output: out/<tag>_<pacing>_<geyser>_<fixture>_s<seed>.txt
p=$1; gy=$2; fx=$3; sd=$4; tk=$5; tag=$6; shift 6
root=/home/bastien/work/slime_train/.claude/worktrees/pacing
out=$root/docs/perf/exp-pacing/out
mkdir -p $out
cd $root
name="$out/${tag}_${p:-none}_${gy}_${fx}_s${sd}.txt"
if [ "$fx" = s3-basket-59of60 ]; then extra="--late-from=9000 --hold-view=720,361 --hold-from=9000"; else extra=""; fi
if [ "$gy" = off ]; then g=off; else g=on; fi
start=$(date +%s)
SLIME_DIPJAM=${DJ-g,r} SLIME_PACING=$p SLIME_GEYSER=$g timeout 3000 flock /tmp/slime_train-godot.lock \
	godot --headless --no-header --path . -s res://tools/dipjam_probe.gd -- --fixture=$fx --seed=$sd --ticks=$tk \
	$extra "$@" 2>&1 | grep -v DJ_CEN > "$name"
echo "$name $(( $(date +%s) - start ))s"

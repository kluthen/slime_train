#!/bin/bash
# run.sh <variant> <fixture> <seed> <ticks> <tag> [extra args...]
v=$1; fx=$2; sd=$3; tk=$4; tag=$5; shift 5
out=/tmp/claude-1001/-home-bastien-work-slime-train/d543671e-c4c0-4b90-a9fc-42b12cf6a31a/scratchpad/dj2/out
mkdir -p $out
cd /home/bastien/work/slime_train/.claude/worktrees/agent-a994fc5fd516987db
name="$out/${tag}_${v:-base}_${fx}_s${sd}.txt"
if [ "$fx" = s3-basket-59of60 ]; then extra="--late-from=9000 --hold-view=720,361 --hold-from=9000"; else extra=""; fi
SLIME_DIPJAM=$v timeout 3000 flock /tmp/slime_train-godot.lock godot --headless --no-header --path . -s res://tools/dipjam_probe.gd -- --fixture=$fx --seed=$sd --ticks=$tk $extra "$@" 2>&1 | grep -v DJ_CEN > "$name"
echo "$name"

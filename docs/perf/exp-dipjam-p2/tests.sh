#!/bin/bash
cd /home/bastien/work/slime_train/.claude/worktrees/agent-a994fc5fd516987db
out=/home/bastien/work/slime_train/.claude/worktrees/agent-a994fc5fd516987db/docs/perf/exp-dipjam-p2/tests
mkdir -p $out
for v in "" g h g,h g,h,v1s r g,r g,r,v1s g,h,r; do
  for t in test_train test_fusion test_slime_hops; do
    SLIME_DIPJAM=$v timeout 1500 flock /tmp/slime_train-godot.lock tools/test.sh -gselect=$t > "$out/${v:-base}_$t.txt" 2>&1
    echo "${v:-base} $t exit=$? $(grep -E 'Passing|Failing|Tests ' "$out/${v:-base}_$t.txt" | tr '\n' ' ')"
  done
done
echo TESTS_DONE

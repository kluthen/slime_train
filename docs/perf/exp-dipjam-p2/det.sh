#!/bin/bash
R=/home/bastien/work/slime_train/.claude/worktrees/agent-a994fc5fd516987db/docs/perf/exp-dipjam-p2/run.sh
$R g,r,v1s stress-dense 1 3600 det2
SLIME_TICK=gdscript $R g,r,v1s stress-dense 1 3600 gds
SLIME_TICK=gdscript $R g,h stress-dense 1 1200 gds
$R g,h stress-dense 1 1200 nat
echo DET_DONE
/home/bastien/work/slime_train/.claude/worktrees/agent-a994fc5fd516987db/docs/perf/exp-dipjam-p2/tests.sh

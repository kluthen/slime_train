#!/bin/bash
R=/tmp/claude-1001/-home-bastien-work-slime-train/d543671e-c4c0-4b90-a9fc-42b12cf6a31a/scratchpad/dj2/run.sh
$R g,r,v1s stress-dense 1 3600 det2
SLIME_TICK=gdscript $R g,r,v1s stress-dense 1 3600 gds
SLIME_TICK=gdscript $R g,h stress-dense 1 1200 gds
$R g,h stress-dense 1 1200 nat
echo DET_DONE
/tmp/claude-1001/-home-bastien-work-slime-train/d543671e-c4c0-4b90-a9fc-42b12cf6a31a/scratchpad/dj2/tests.sh

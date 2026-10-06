#!/bin/bash
R=/tmp/claude-1001/-home-bastien-work-slime-train/d543671e-c4c0-4b90-a9fc-42b12cf6a31a/scratchpad/dj2/run.sh
for v in "" g h g,h g,h,v1s r g,r g,r,v1s g,h,r; do
  $R "$v" s3-basket-59of60 1 14000 m
  $R "$v" s3-basket-59of60 2 14000 m
  $R "$v" stress-dense 1 3600 m
done
echo MATRIX_DONE

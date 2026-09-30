# v3 — Proper graphics

Status: themes only (D134); one proposed idea (D145); no spec yet

- **Proper graphics** (D134). Until then the art is placeholder.
- **A waiting train still looks merry** (the user, 2026-09-30; proposed,
  D145): train slimes that hold or rest (v1's hold, chunk 22e, D146) play an
  idle animation in place, "static" animations in the user's words (a
  bob, a sway, a blink), so a waiting train still reads as a merry train.
  Drawing only: it never moves the bodies, so no physics cost and no hash
  change. Keep it within the drawing budget (4 ms a frame on the reference
  phone, D138, measured by D142's method): many resting slimes on screen
  at once is the case to measure.

Sound is no longer assigned here: it begins at v2 (D134, D136).

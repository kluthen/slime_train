# Level design requirements

Status: draft v6

Rules every level must follow, whoever builds it. These rules make up the
checklist for every level's design (see `levels/`). Levels are
Godot scenes built from reusable components, with no per-level scripts (D6).

## The loop

1. **The loop can be travelled with no input at all** (D19).
2. **A slime of any size can travel the loop.** From v2, different sizes may
   take different forks through a size filter (D26, D89). In v1 every size
   takes the same way; size matters off the loop, where bigger free slimes
   jump higher.
3. **No dead ends.** Every branch joins the loop again, and a slime on a
   branch is still part of the train (D18).
4. The **start of the loop carries a split zone**, where fused slimes split
   back into base slimes (D23, D54).
5. A dip in the loop may be used to nudge same-species slimes into fusing (D20).
6. A **signpost** stands at every fork and shows which way the loop goes
   (D47).

## Exploration

7. **From anywhere a free slime can reach, gravity leads back toward the
   loop** (D8).
8. **Every exploration branch includes its own route back to the loop.** A
   slime heading back follows it (D41, D51).
9. **Hints that there is something to explore must be visible from the loop**,
   because the camera stays on it (D45).
10. **Tilt is only for exploration or fun actions.** It is never needed to make
    progress along the loop or to open a frontier gate (D64).

## Sections and gates

11. The **first section has 3 native species**, and each later section adds one
    (D22).
12. A frontier gate opens through the **switch-plus-basket set** (D14, D35).
13. **Each section needs its own return route to the start** from its unopened
    frontier gate. It is part of the loop and has its own camera rail (D79).
    How that route works is O22.
14. **A return route may carry exploration opportunities, but opening a later
    frontier gate must never make them unreachable** (D79).
15. **Once its gate is open, a frontier set is inert for good**; it may be
    removed or become a landscape feature (D86).

## Population

16. **At most 200 slimes per level**, counted in base slimes (D67). Scenes
    where many slimes pile up on one screen should keep them mostly still,
    such as a basket being filled.
17. **Sleepers never sit on the loop itself.** Waking always takes a call
    (D70).

## Onboarding

18. **The first sleeper is placed close to the first awake slime**, so the
    first-play hint and the first call pay off quickly (D65).

## Camera

19. Wherever a wider view is needed, place a **framing zone** that sets the
    zoom and position (D60, D61).

## After release

20. **A released level isn't meant to change.** Any update must be minor and
    ship with a save migration. Keep the stable IDs of slimes, objects and
    gates (D72).

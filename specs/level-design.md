# Level design requirements

Status: draft v15 (rule 24 strengthened: at the loop's start arrivals never outpace what the train takes off it, a rate check over the scripted runs, what to do when it fails, D159, the user's ask, wording and check proposed; v14: rule 24, arrivals clear faster than they come, D157, the user's, wording and check proposed; v13: rule 23, clusters, D143, approved in direction, D144; its limit proposed, O107)

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
    *(Proposed, D127):* each section's basket can be filled by play from
    the slimes that can be woken by then, starting from a fresh game. The
    level-rules checker estimates it and only warns (it can't see climbs
    or lips); a played test is the proof.
    *Reading (proposed, D129):* "the slimes the train can make", fusion
    included, as the checker estimates by default; filling with base
    slimes alone is not required (that would make fusion never needed).
    Sleepers in a **touching line** wake together (chain waking).
13. **Each section needs its own return route to the start** from its unopened
    frontier gate. It is part of the loop and has its own camera rail (D79).
    How that route works is O22; where it meets the start is rule 22.
14. **A return route may carry exploration opportunities, but opening a later
    frontier gate must never make them unreachable** (D79). A gate may shut
    the old return route's entrance with a lid (D105); any exploration on
    that route then needs another way in.
15. **Once its gate is open, a frontier set is inert for good**; it may be
    removed or become a landscape feature (D86).

## Population

16. **At most 200 slimes per level**, counted in base slimes (D67). Scenes
    where many slimes pile up on one screen should keep them mostly still,
    such as a basket being filled. Where slimes gather awake is rule 23.
17. **Sleepers never sit on the loop itself.** Waking always takes a call
    (D70).

## Onboarding

18. **The first sleeper is placed close to the first awake slime**, so the
    first-play hint and the first call pay off quickly (D65). The
    level-rules checker takes "close" as within a third of a screen until
    O94 makes the rule measurable (D126).

## Camera

19. Wherever a wider view is needed, place a **framing zone** that sets the
    zoom and position (D60, D61).

## After release

20. **A released level isn't meant to change.** Any update must be minor and
    ship with a save migration. Keep the stable IDs of slimes, objects and
    gates (D72).
    *Numbering after release (proposed, D127):* before release, each
    section's sleepers are numbered `.01` to N, left to right, with no
    gaps. A released level keeps a list of its released stable IDs (for
    example `levels/<id>/released_ids`): every released ID must still
    exist; new sleepers take numbers above the highest released one in
    their section; the order and gap checks apply only to unreleased IDs;
    removing a released ID needs a `level_version` bump and a save
    migration.

## Controls

21. **At the rails' framing, every interactive object sits fully below the
    parent zone** (the band along the top of the screen), so the child can
    operate it: the call drag is the only way to move the camera up
    (D111). *Reading (chunk 23E, D126, proposed):* the views checked are
    the settled views of every section's outgoing route's rails, framing
    zones included, on the reference phone's screen; the return routes'
    rails aren't checked. An object framed above the top of the screen
    fails too. Switches, baskets and gates are checked.

## The start

22. **A return route delivers slimes into the start behind the loop's
    start, travelling the loop's way**, never along the loop's first stretch
    against the flow: slimes coming home join behind the train, they don't
    meet it head on. **Nothing a base slime must be called up to overhangs
    the loop where larger slimes pass**: a ledge a called size 1 can reach
    is too low for a size 2 or 3 to pass under, so such a ledge sits where
    only base slimes pass (inside the split zone's reach) or off the loop's
    path (D117, D123). The level-rules checker measures (b) with the
    simulation's own numbers (a called base slime reaches about 133 px, a
    size 3's hop about 130 px; `docs/dev/level-tooling.md`, D126).
    *House style (proposed, D129):* a ledge a called base slime must
    reach keeps its underside at least 130 px over any loop ground under
    it, wherever the slime reaches it from (stricter than the checker,
    which measures only ledges within reach of the loop beneath them).

## Where slimes gather

23. *(D143, approved in direction, D144; the measure's numbers proposed, O107.)* **No spot where many slimes gather awake.** Keep apart the places
    where slimes pile up: a bowl or dip next to a basket, an outlet
    releasing into a crowd, a narrow ledge where the train queues, the
    landing spot of a sleeper shelf next to any of these. A pile that
    rests costs little; an awake cluster keeps waking itself and costs
    every tick.
    *Measure (proposed):* the **largest awake cluster** (the biggest
    group of touching slimes that cost physics, D143) over the level's
    own scripted runs (its played test from fresh, and each basket's
    fire-and-drain; the `stress-*` fixtures excepted) stays at or under
    20 slimes, or goes above it for at most 5 s in a row. The level bench
    and the level's played test measure it; the level-rules checker
    points at them. The number is calibrated in chunk 24 (O107). A
    cluster the player builds with calls is accepted: crowd detail and
    the tick cap cover it.
24. *(D157, the user's; strengthened by D159, the user's ask; wording,
    reading and check proposed.)* **Where slimes arrive fast, they get
    away faster than they arrive; at the loop's start, arrivals never
    outpace what the train takes off it.** The place where a flow lands
    slimes (the end of a return route at the loop's start, a slide's end,
    a basket's outlet) gives them enough room and a clear way onward to
    move off before the next ones land. Otherwise each arrival lands on
    the ones before it and the pile feeds itself. This is rule 23's case
    of a gathering spot the flow itself makes. Where a split zone meets
    the arrivals, count them in base slimes (a size 3 lands as three).
    The way onward counts by its pace, not only its room: at the loop's
    start slimes leave by joining the train at its hop pace, so a return
    route that brings them faster than the train carries them off fills
    the start however wide it is. The geyser (D159) spreads the arrivals
    over the first stretch; it gives them room, not pace. Moves to the
    loop start (lost, stuck, stalled) are paced by the loop-start queue
    and land on free spots (D150); this rule is about the level's own
    arrivals.
    *Check (proposed):* over the level's own scripted runs (the `stress-*`
    fixtures excepted), from the first arrival on: **the arrival rate at
    the loop's start is at most the departure rate off its first
    stretch**: the mean arrivals per 600 ticks stay at or below the mean
    departures per 600 ticks past the end of the first stretch (past the
    geyser's farthest landing; 750 px on the test level); and **the
    largest awake cluster** with a slime within 240 px of the loop's start
    stays within rule 23's limit (O107); and over a 10,000-tick
    `tools/thru.gd` run no slime is stuck again within 10 s of landing
    there (D157). The run tool (chunk 24g) counts the rates and the
    cluster; the window and the threshold are O119. *By eye, in test mode:*
    each arrival spot clears while slimes keep coming (no pile there
    grows). The scene-only level-rules checker can't see rates, so it
    lists this rule as a run check and a by-eye item.
    *When it fails:* give the first stretch more room (longer, or wider so
    waiting slimes sit apart), make the train faster off it (a gentler
    first slope), or pace the return route's end (O118, not yet built).

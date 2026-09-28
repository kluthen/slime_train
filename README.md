# Slime Train

A calm, almost idle game for young children (ages 3–5), built for Android
first. It is inspired by *LocoRoco Cocoreccho!*.

A train of slimes hops along a looping path through a soft, high-contrast
world. The child watches, taps to call slimes, and tilts the phone gently to
help free slimes along. Along the way they wake sleeping slimes to join the
train, open gates onto new areas, and fuse slimes into bigger ones that can
take different forks. Think of it as an **interactive screensaver**. Leave it
alone and the camera drifts after a slime. Touch it and the world responds.

Sessions are made to be handed to a child: the screen is pinned, a timer
limits play to 15 minutes at most, and the session ends with a gentle
**bedtime** that only a grown-up, through the **parent gate**, can move past.

## Status

**Building v1.** The v1 master spec is in
`specs/versions/v1/master-spec.md`, with the build plan next to it. Chunk 0
(tooling and project setup) and chunk 3 (test backbone) are done: the project
settings, the code layout and the headless test runner, plus one seeded
random generator, a fixed 60-tick simulation step, test mode (scripted taps
and tilt, time control, a fixture stub; debug builds only) and a headless
end-to-end runner comparing state hashes. There is no gameplay code yet.
UX design (`ui_ux/`) has an inventory and open questions, no design yet.

## Direction so far

- **Engine:** Godot 4. Unity and Unreal are ruled out.
- **Targets:** Android is the main target. A Linux desktop build, and possibly
  a web build, will be used for fast iteration and end-to-end tests.
- **Levels** will be built in Godot's own editor from reusable, configurable
  components such as switches, baskets, gates and bending pathways. There is
  no custom level editor and no per-level scripts.
- **Slimes** will be soft bodies, rendered as smooth blobs (proposed).
- **Session lock** is best effort: Android screen pinning, an in-app parent
  gate, and a timer that survives the app being restarted. It is a help for
  parents, not a security feature.
- **Later:** fusing slimes of different species, themed sections, paid extra
  levels, and procedural generation.

## Repository layout

| Path | What it is |
|---|---|
| `specs/` | Working spec: concept, slimes, interactive objects, tech direction, plus the open-questions register and the decisions log. Start at [`specs/README.md`](specs/README.md). |
| `docs/research/` | Research reports with their sources: the reference game, the tech stack, level authoring and the kid lock. Index: [`docs/research/README.md`](docs/research/README.md). |
| `docs/*.atom.md` | Declared intent, as ATD atoms (see `.atd`) |
| `docs/dev/` | Developer notes: the code layout, how to run the tests, and the technical choices with their reasons. Start at [`docs/dev/README.md`](docs/dev/README.md). |
| `src/` | Game code: the main scene, the simulation core (`src/sim/`) and the reusable level components (`src/components/`) |
| `levels/` | One folder per level, with its scenes; `levels/test/` is the test level |
| `tests/` | Unit tests (`tests/unit/`) and end-to-end tests (`tests/e2e/`), run with GUT |
| `tools/` | Developer scripts, such as `tools/test.sh` |
| `spikes/` | Throwaway prototypes |
| `addons/gut/` | GUT, the test framework (vendored) |
| `CLAUDE.md` | Conventions for AI-assisted sessions, including the project vocabulary |

## Running the tests

With Godot 4.7.2 on the `PATH` as `godot`:

```sh
tools/test.sh
```

It runs the whole suite headless and exits with a non-zero code when any
test fails. Details in [`docs/dev/README.md`](docs/dev/README.md).

## Vocabulary

The project uses a small, precise set of terms, such as *slime*, *sleeper*,
*train*, *loop*, *free slime*, *call*, *gate*, *switch*, *basket*, *weight*
and *bedtime*. The terminology table in [`specs/concept.md`](specs/concept.md)
is the reference.

## Next steps

The build follows `specs/versions/v1/build-plan.md`, chunk by chunk. Each
chunk lands with its tests. The real first level, the interface design and
playtests with children come after the test level has been built and played.

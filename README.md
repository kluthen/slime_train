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

**Spec and design phase: there is no code yet.** Scope, mechanics and
vocabulary are being worked out in `specs/`. Nothing there is final until a
master spec is put together and handed off for building.

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
| `precursor.md` | The original brief |
| `specs/` | Working spec: concept, slimes, interactive objects, tech direction, plus the open-questions register and the decisions log. Start at [`specs/README.md`](specs/README.md). |
| `docs/research/` | Research reports with their sources: the reference game, the tech stack, level authoring and the kid lock. Index: [`docs/research/README.md`](docs/research/README.md). |
| `docs/*.atom.md` | Declared intent, as ATD atoms (see `.atd`) |
| `CLAUDE.md` | Conventions for AI-assisted sessions, including the project vocabulary |

## Vocabulary

The project uses a small, precise set of terms, such as *slime*, *sleeper*,
*train*, *loop*, *free slime*, *call*, *gate*, *switch*, *basket*, *weight*
and *bedtime*. The terminology table in [`specs/concept.md`](specs/concept.md)
is the reference.

## Next steps

1. Settle the remaining session and parent questions: timer settings and the
   parent gate design.
2. Decide the idle camera, the failure states, the personas, and the scope of
   the first release.
3. Build throwaway prototypes to test the main risks:
   - tap-to-call vs hold-and-drag, with real children
   - Android audio latency in Godot
   - how many soft-body slimes a low-end phone can handle
   - how tilt feels in the hand
   - running end-to-end tests without a screen on Linux
4. Put together a master spec and hand it off for building.

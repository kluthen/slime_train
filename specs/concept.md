# Concept

Status: draft v9

## One-liner

Slime Train is an "interactive screensaver" for Android, made for children aged
3–5. A train of squishy slimes travels around a loop through a soft,
curved world. The child gets more slimes to join the train, and the train
opens up the world around it.

Inspiration: LocoRoco Cocoreccho! (research in `docs/research/locoroco-cocoreccho.md`).
The slimes stand in for LocoRoco.

## Design stance

- **Watching is playing.** The world keeps moving and stays pleasant to look
  at without any input. Input adds to it; it is never required to keep
  things alive.
- **Idle camera.** When nobody has touched the game for a while, the camera
  takes over and follows a slime's movement. The exact behaviour is O4.
- **Simple, curved, high-contrast, low detail.** Theming (desert, forest,
  rivers…) may come later as palette and decoration changes only.

## Gameplay layers, in priority order

1. **The train (primary).** Awake slimes follow the loop, and that is fun to
   watch in itself. Sleeping slimes seen along the way catch the child's eye;
   bringing them into the train is the core action (see "Waking sleepers").
2. **Exploring the loop's surroundings (secondary).** The areas just off the
   loop hold more slimes to find.
3. **Fusion (tertiary).** Two slimes of the same species fuse into a bigger
   one after staying in contact for a while. Bigger slimes are heavier and jump
   higher, which opens pathways not yet explored. See `slimes.md`.

## The loop and free slimes (D8)

- The **train** follows the **current loop**, a drawn route. Physics only
  handles the squish and the bumps.
- Opening a gate changes the loop so it takes in the new area. Whether it
  grows or is replaced is O17.
- Attracting slimes away from the loop makes them **free**: they are driven
  by physics alone.
- A free slime makes its way back to the loop by physics and rejoins the
  train when it reaches the loop (D11).
- **Left alone:** off screen for more than 10 s. **Lost:** left alone and still
  not back on the loop after 1 min. A lost slime is teleported to the start of
  the loop (D10). A free slime that stays on screen is never lost.
- **The loop has forks** (switches, spring-back bending pathways). Every branch
  joins the loop again, and there are no dead ends. A slime on any branch is
  still part of the train. Exploration areas hang off the route and are reached
  only by calling slimes there (D18).
- **The train has no slots** (D11). It is whichever slimes are following the
  loop, clumped by where they happen to be at that moment. A slime alone on
  the loop keeps following it.

## Waking sleepers (D13)

Tapping a sleeper calls nearby awake slimes toward it. One of them touching it
wakes it, and the woken slime, being free, in time rejoins the train. Slime
states, movement, size, species and fusion are in `slimes.md`.
- **Level rule:** from anywhere a free slime can reach, following gravity down
  leads back to the loop.

## Persistence (D7)

Progress carries over between sessions. The saved state holds each slime's
type, size and position, plus the state of every interactive object. It is
saved every 15 s and whenever the app goes to the background. On load, a slime
saved in mid-air is placed on the ground or at its jump start, or declared lost
(D12). Save-file versioning is O20.

## Controls

- **Tilt** (D19): the world stays fixed on the screen, and gravity turns with
  the phone, up to ±45°, with a dead zone of about 10°. Neutral is how the
  phone was held when the session started; lying flat counts as neutral. For
  now **only free slimes** feel tilt. Tilt objects always respond to it, and
  can affect the train only indirectly and slightly.
- **Level rule:** the loop can be travelled with no input at all.
- Touching the screen **calls** nearby slimes toward that point. Tap-to-call
  or hold-and-drag is decided by playtesting (O21).
- Every awake slime in range answers the call, train slimes included, and
  answering makes it free. (proposed: this follows from D13. At the start the
  only awake slime is on the loop, so train slimes have to answer or no
  sleeper could ever be woken.)

## Interactive objects

See `interactive-objects.md`. Most are operated by tapping them; a few are
driven by tilt or by the slimes on them (D15). The standard frontier-gate
pattern is a switch plus a basket (D14).

## Candidate actions (from precursor, each still to be specified)

Gates redirecting the flow (for example into a waiting basket that opens the
next section), jumping toward a tapped target that is out of reach, objects
activated by slime contact, zones revealed when slimes approach, fusing,
defusing spots, waking by contact.

## Session and parental controls

A session is limited to at most 15 minutes, and leaving the app requires an
adult-only operation. This is **best effort, a courtesy to parents and not a
guarantee** (D1): Android screen pinning, our own parent gate, and a timer that
survives the app being killed. Timer settings are O6; the parent gate is O7.

### Bedtime (D28)

- In the **last minute** the light drifts toward dusk, the music softens, and
  slimes hop more slowly. No text, no countdown.
- At **bedtime**, slimes fall asleep where they are, the game saves, and calls
  stop doing anything. Only the **parent gate** moves things forward; there is
  no cooldown that lets the child start again alone.
- Bedtime sleep is not the same as being a sleeper. At the next session the
  game wakes every bedtime-asleep slime, and play carries on where it was.

## Terminology

| Term | Meaning |
|---|---|
| slime | one creature, awake or asleep |
| sleeper | a slime that is asleep and not yet in the train |
| train | whichever slimes are following the loop at the moment; no slots, no fixed order |
| loop | the route the train currently follows, from the start to the frontier gate, with forks that always join again; grows when a gate opens |
| frontier gate | the first unopened gate, where the loop currently ends |
| gate | a barrier at the end of the loop that opens onto a new area |
| switch | redirects the flow at a fork in the loop; operated by tapping |
| basket | collects slimes until their weight fills it, then fires its target (usually a gate) |
| weight | a slime's size seen as load; what presence objects respond to |
| left alone | a free slime off screen for more than 10 s |
| lost | a left-alone slime not back on the loop after 1 min; teleported to the loop start |
| free slime | an awake slime attracted away from the loop, driven by physics alone until it rejoins |
| session | one timed play period (at most 15 min) |
| species | a kind of slime; only the same species fuse (replaces the precursor's "type") |
| call | a tap (or hold, see O21) that draws nearby awake slimes toward a point |
| unsure | a free slime just after a call ends, lingering near the call point (proposed) |
| heading back | a free slime making for the loop (proposed) |
| size | the number of base slimes a slime is made of; equals its weight |
| section | the part of the world opened by one gate (proposed) |
| parent gate | the adult-only operation required to leave, change settings, or continue after bedtime |
| bedtime | the end of a session: slimes fall asleep and only the parent gate moves things forward; not the same as a sleeper |

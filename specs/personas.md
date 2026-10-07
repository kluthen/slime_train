# Personas

Status: draft v8 (P1's abilities and limits the working assumptions, D167)

Who Slime Train is for, what each person is trying to get done, and the
circumstances they use it in. These are built from the real people the user
has in mind, not invented profiles. This is a standing document that
describes the product, so it is kept up to date across versions and never
archived.

Personas are not roles. What each kind of user *may do* (the child vs the
parent behind the code) belongs to the parent gate rules (D30, D57), not here.

## P1 — Primary: the newcomer (3 years old)

**Who:** a 3-year-old girl who has **never played a video game**. She is the
main player.

**Context:** a Samsung Galaxy S20 FE, at home, in the daytime. The phone is
handed over **as a reward for good behaviour, or for a little while after
school**. It is not a before-sleep routine. The parent chooses when to hand it
over. How she holds it (in her hands, flat on a table, on her lap) isn't
known, so tilt stays optional (D64, see below).

**Goals:**
- **P1.G1** See something pleasant happen and keep watching it.
- **P1.G2** Touch the screen and see the world answer her straight away.
- **P1.G3** Find out on her own what touching does. There is no one to explain
  it and she can't read.
- **P1.G4** Never fail, and never get stuck with nothing happening.

**Abilities and limits (the working assumptions, D167; to check against the real child):**
- Taps well. Holding, dragging and precise aiming are unreliable.
- Doesn't read. Digits are not a given.
- Holding the phone steady, or tilting it on purpose, is uncertain at 3.
- Short bursts of attention. She may put the phone down and come back.

**What the context means:**
- A reward has to **end without a fight**. The session ends softly, falls
  asleep on its own, and nobody has to take the phone away mid-action. That is
  why bedtime is gentle (D28).
- It happens at home during the day, so v1 having no sound (D50) isn't a
  problem.
- **Tilt is a bonus and never needed to make progress.** v1 already
  guarantees this: only free slimes feel tilt, and the loop works with no
  input (D19). Tilt objects arrive in v2, and a v2 design rule should keep
  them from being the only way forward. This is now a level design requirement
  (D64, `level-design.md`). Whether a 3-year-old uses tilt at all
  is something to watch in playtests.

## P2 — Secondary: the watching sibling (2 years old)

**Who:** her 2-year-old little brother. He mostly watches over her shoulder.

**Goals:**
- **P2.G1** Watch the slimes.
- **P2.G2** Poke the screen too, sometimes at the same moment as his sister,
  without breaking anything.

**What it means:** the game has to be pleasant to watch without playing, and
must stay safe and unbroken whatever gets poked. For now only the first finger
counts, so his poke does nothing while his sister's finger is down, not even
a ripple (D102). Two calls at once will be tried later (D66).

## P3 — Secondary: the early player (4 years old)

**Who:** children of friends, about 4, using a similar phone.

**Goals:**
- **P3.G1** Play more on purpose: call slimes, fuse them, fill a basket, open
  the next section.
- **P3.G2** Explore off the loop to find more slimes.

**Limits:** may already know digits. The code is 6 digits, and D1 accepts that
risk.

## P4 — Supporting: the parent

**Who:** the adult who owns the phone, buys the game and sets it up: the user,
and the friends' parents.

**Goals:**
- **P4.G1** Hand over a calm, safe activity for a limited time, and trust it
  to end on its own.
- **P4.G2** Trust that the child can't leave the app, change anything or buy
  anything.
- **P4.G3** Set it up once, easily, and never have to think about it again.
- **P4.G4** Take the phone back, or give more time, whenever they choose.

## How the settled spec serves these goals

Persona and goal IDs (P1, P1.G2…) are stable content identifiers; the master
spec cites them.

| Goal | Served by |
|---|---|
| P1.G1 something pleasant to watch | interactive screensaver, idle camera, screensaver mode (D2, D4, D53, D59) |
| P1.G2 instant answer to a touch | tap-to-call, with any tap anywhere doing something (D15, D46) |
| P1.G4 nothing to fail | no failure states; a lost slime just comes back (D10, D36) |
| P1.G3 learn with no explanation | a ripple on every tap, and a wordless hint on the very first play (D65) |
| P2.G1 / P2.G2 watch, and safe to poke | parent gate on every parent button (D57); the first touch wins (D66) |
| P3.G1 goals to reach | sleepers, fusion, the frontier-gate set (D13, D20, D54) |
| P3.G2 exploring | exploration branches with hints visible from the loop, the call dragging the camera (D45, D51) |
| P4.G1 a reward that ends without a fight | a gentle bedtime, slimes falling asleep on their own (D28) |
| P4.G1 bounded time | 15 min real-time sessions, bedtime, 10 min cooldown (D29, D44, D56) |
| P4.G2 the child can't get out | screen pinning plus the parent code (D1, D30) |
| P4.G3 easy setup | one-time setup at first launch (D55) |
| P4.G4 in control | wake early, leave and settings behind the code (D57); the time left, shown only behind the code (D114) |

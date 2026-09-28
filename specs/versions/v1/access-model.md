# Slime Train v1 — Access model

Status: consolidated early with the v1 master spec.

## 1. Purpose and scope

This covers who may do what inside the Slime Train app on one phone: the
child playing, the parent behind the 6-digit code, and the game itself.
Slime Train has no accounts, no server and no network, so there is no
login, no remote access and no multi-device concern. Access to the phone
itself (its screen lock, Android settings, uninstalling) belongs to Android
and is out of scope, except where the app relies on it.

## 2. Actors

| Actor | Definition | How acquired | Stacks? |
|---|---|---|---|
| `child` | Anyone touching the screen without having just entered the parent code. This is the default: there is no login, so every touch is the child's unless a code was entered for it. | Default state | No — exclusive with `parent` for any single action |
| `parent` | Whoever has just entered the correct parent code. It is an authority for **one action**, not a mode that stays on. | Enter the correct code at the prompt that a parent button raises | No — ends when that action completes (see §3) |
| `game` | The app itself, acting on its own: timers, autosave, sunrise, the first-launch setup, asking Android for screen pinning. Not a person. | Always present | Not applicable |

Roles are global to the app. There are no per-level roles. The phone's own
screen lock (PIN, pattern, fingerprint) is not an actor. Passing it is a
condition used only to reset a forgotten code (§6).

## 3. Role assignment and lifecycle

- **Becoming `parent`:** there is one way, entering the correct 6-digit code
  at the prompt shown by a parent button. The code is created at the
  one-time first-launch setup.
- **Revocation:** `parent` authority ends as soon as the action it was
  entered for is done. For **wake early** and **leave**, that is immediate.
  For **settings**, it lasts while the settings screen stays open, and ends
  when the settings screen closes. Settings also closes by itself after a
  short time with no input, so a phone handed back to the child is never left
  in settings.
- There is no "remember me". Every new parent action asks for the code again.
- **Changing the code** takes effect immediately. The old code stops working.
- **The last and only code holder:** there is exactly one code. If it's
  forgotten, the phone's own screen lock lets anyone who passes it set a new
  one. If the phone has no screen lock, clearing the app's data in Android
  settings is the only way out, and it erases all progress. The setup screen
  says so.
- **In-flight play during a parent action:** opening the parent buttons or
  the code prompt pauses nothing. The world keeps running, the session timer
  keeps counting (sessions are real time), and bedtime can arrive while the
  prompt is open.

## 4. Resources and operations

| Resource | Operations |
|---|---|
| **World** (the running level: slimes, objects, camera) | `call`, `operate-object` (tap a switch), `move-camera` (edge buttons), `tilt` |
| **Session** | `start` (the first tap in screensaver mode), `end` (bedtime), `wake-early` (end bedtime before the 10 min cooldown is over), `sunrise` (the cooldown running out) |
| **Parent buttons** | `reveal` (tap at the top of the screen) |
| **App exit** | `leave` (stop screen pinning and leave the app), `pin` (ask Android for screen pinning) |
| **Parent code** | `create` (first-launch setup), `change`, `reset` (after a forgotten code) |
| **Level save** | `write` (autosave), `load`, `delete` |

No resource has a list view separate from single-item access. The only list
is the level saves in settings, and v1 ships one level.

## 5. Permission matrix

**World**

| Operation | `child` | `parent` | `game` |
|---|---|---|---|
| `call` | `in-session` | `in-session` | deny |
| `operate-object` | `in-session` | `in-session` | deny |
| `move-camera` | `not-bedtime` | `not-bedtime` | allow |
| `tilt` | `in-session` | `in-session` | deny |

The parent needs no code to play: playing is the same for everyone. The
`game` column for `move-camera` is the idle camera and automatic framing.

**Session**

| Operation | `child` | `parent` | `game` |
|---|---|---|---|
| `start` | `in-screensaver-mode` | `in-screensaver-mode` | deny |
| `end` | deny | deny | `session-time-up` |
| `wake-early` | deny | `in-bedtime` | deny |
| `sunrise` | deny | deny | `cooldown-over` |

**Parent buttons**

| Operation | `child` | `parent` | `game` |
|---|---|---|---|
| `reveal` | `setup-done` | `setup-done` | deny |

Revealing the buttons is harmless: pressing any of them raises the code
prompt, which is what turns a `child` into a `parent`.

**App exit**

| Operation | `child` | `parent` | `game` |
|---|---|---|---|
| `leave` | deny | allow | deny |
| `pin` | deny | deny | `app-opening` |

**Parent code**

| Operation | `child` | `parent` | `game` |
|---|---|---|---|
| `create` | `first-launch` | `first-launch` | deny |
| `change` | deny | allow | deny |
| `reset` | `passes-phone-lock` | `passes-phone-lock` | deny |

At first launch there is no code yet, so whoever holds the phone creates it.
The parent is expected to be the one doing the setup.

**Level save**

| Operation | `child` | `parent` | `game` |
|---|---|---|---|
| `write` | deny | deny | allow |
| `load` | deny | deny | allow |
| `delete` | deny | allow | deny |

Playing changes the save only through the `game`'s autosave. Nobody reads or
edits a save directly.

## 6. Conditions

| Condition | Holds when |
|---|---|
| `in-session` | A session is running: it started with a first tap and its 15 real minutes aren't over |
| `not-bedtime` | The app is in screensaver mode or in a session, not in bedtime |
| `in-screensaver-mode` | Setup is done, no session is running, and it isn't bedtime |
| `in-bedtime` | A session has ended, and neither the 10 min cooldown nor a wake early has ended bedtime yet |
| `session-time-up` | 15 real minutes have passed since the session started, counted across backgrounding, kills and restarts |
| `cooldown-over` | 10 real minutes have passed since bedtime began |
| `setup-done` | The first-launch setup has been completed and a code exists |
| `first-launch` | No parent code exists yet (a fresh install, or after the app's data was cleared) |
| `passes-phone-lock` | The person has just passed the phone's own screen lock through Android's system prompt, reached from "forgot the code?" |
| `app-opening` | The app is opening, including its very first launch. Android then shows its own confirmation, which the app can't skip |

## 7. Denial behaviour

| Operation class | Behaviour | Why |
|---|---|---|
| A tap during bedtime (`call`, `operate-object`, `tilt`) | **Visible but inert.** The ripple still shows; slimes stay asleep; nothing else happens. No text, no sound. | Every tap gets an answer, but bedtime must stay calm and nudge the child to put the phone down. |
| `move-camera` during bedtime | The edge buttons are hidden during bedtime. | Nothing to explore while everyone sleeps. |
| Any parent-only operation (`wake-early`, `leave`, `change`, `delete`) by `child` | **Visible but blocked:** the button is shown, and pressing it raises the code prompt. Without the correct code, nothing happens. | The parent has to find the buttons without instructions; the code is the only guard. |
| A wrong code | The entry shakes and clears. Tries are unlimited, but 5 wrong tries in a row bring a 30 s wait. The prompt closes after about 15 s with no input. | A 3-year-old pressing digits must not lock the parent out for long. |
| `wake-early` pressed outside bedtime | The button is shown only during bedtime. | There is nothing to wake. |
| Home and back while the screen is pinned | Android ignores them. | Screen pinning. |
| Pinning declined by the parent | The game still works; every parent button still asks for the code; setup explains the difference. | Pinning is a courtesy, not a requirement. |
| The child leaves the app anyway (pinning declined or escaped, or the power button) | Nothing is blocked in the app: the session keeps counting in real time, and reopening the app resumes where it was. | Best effort by design; the timer can't be dodged by leaving. |

No denial is logged, and nothing is ever locked for good. The only slowdown is
the 30 s wait after 5 wrong codes in a row.

## 8. Elevation, delegation and non-human actors

- **No support or remote access.** There is no server, so nobody can act on
  the phone from outside.
- **Break-glass:** "forgot the code?" goes through the phone's own screen
  lock. With no screen lock, the last resort is clearing the app's data in
  Android settings, which erases all progress. Anyone who knows the phone's
  PIN can use this path, including a child who knows it. That is accepted.
- **`game`** acts only on its timers and at setup. It can never leave the app
  or delete a save by itself.
- **No delegation.** The code can't be split or shared per action. There is
  one code for everything.
- **Test mode** (the Linux build and debug Android builds only) can inject
  taps and skip time. It doesn't exist in the release build, so it isn't an
  actor there.

## 9. Audited and step-up operations

- **Step-up:** every parent-only operation requires the code immediately
  before it. Deleting a level's save also asks for a second confirmation,
  since it erases that level's progress.
- **Changing the code** asks for the new code twice. The current code has
  already been entered to open settings.
- **Resetting the code** requires the phone's own screen lock.
- **Audit:** nothing is logged. There is no analytics and no network.

## 10. Out of scope

- Purchases. v1 is a paid app with nothing to buy inside it. Paid levels,
  and a code before any purchase, come with later versions.
- Turning the parent code off entirely (a later version).
- Android's own controls: the phone's screen lock, the "Ask for PIN before
  unpinning" setting (which setup recommends turning on, since otherwise
  anyone can unpin with Android's gesture), app data clearing, uninstalling, and Google Family Link.
  There is no public way for the app to read or set Family Link limits.

## 11. Known gaps

None.

# 08 Fixtures and testing a level

## The level's own test

The scaffolder wrote `tests/e2e/levels/test_level_<id>.gd`. It checks that:

- the level loads by its ID with no load errors;
- the full rules checker finds no FAIL (the report is printed either way);
- 2 simulated minutes with no input lose no slime (none stalled, none stuck,
  none lost off screen) and keep every base slime;
- every fixture in `levels/<id>/fixtures/` loads in test mode.

```sh
tools/test.sh -gdisable_colors -gselect=test_level_zz-tutorial
```

```
4/4 passed.
...
---- All tests passed! ----
```

The test is yours: extend it as the level grows (a sleeper a called slime
must reach, a basket that fills in view, what must happen from a fixture).
`tests/e2e/` holds the test level's tests as examples. Adding tests is code:
ask for it if you don't write GDScript.

## Fixtures: named starting points

A fixture is a sidecar, `<name>.fixture.json` (a description, whether it
has a save, where the camera starts), and, if it has one, a save,
`<name>.json`, both in `levels/<id>/fixtures/`.

For any level, the fixture tool makes two kinds:

- `fresh`: the level as new, no save;
- `gate<k>-open`: the gates up to the k-th open as after their baskets
  fired, the level otherwise as new, the camera at the next section's
  start. `gate1-open` is how to start at section 2.

```sh
godot --headless --path . -s res://tools/make_fixture.gd -- --level=zz-tutorial --list
godot --headless --path . -s res://tools/make_fixture.gd -- --level=zz-tutorial
godot --headless --path . -s res://tools/make_fixture.gd -- --level=zz-tutorial gate1-open
```

```
fresh: The level as new: no save, the first slime woken at its marker and every sleeper asleep at its own; ...
gate1-open: Gate open as after its basket fired, its switch inert and its old slide entrance shut: s1.gate ...
make_fixture: wrote fresh
make_fixture: wrote gate1-open
make_fixture: wrote gate2-open
```

With no name it writes them all. An unknown name exits 1 and lists what
exists (`make_fixture: level zz-tutorial has no fixture 'nope' (its
fixtures: fresh, gate1-open)`).

**Rewrite the fixtures after every change to the level.** A fixture's save
is a snapshot: one saved before you added a sleeper still loads, silently
without that sleeper, and the level's test won't notice.

## A fixture of your own

Play from a fixture for a while with no input, save, and write a sidecar:

```sh
godot --headless --path . -- --test-mode --level=zz-tutorial --seed=1 --fixture=gate1-open --run-ticks=1800 --save=levels/zz-tutorial/fixtures/s2-train-arrives.json
```

```
STATE tick=1800 hash=199820784c755ec6dfb6ff06956db5105c2c48a0de56403d70c963627fec62f9
SAVED levels/zz-tutorial/fixtures/s2-train-arrives.json
```

Then `levels/zz-tutorial/fixtures/s2-train-arrives.fixture.json`:

```json
{
	"description": "From gate1-open, 30 s of play with no input: the train on its way into section 2.",
	"save": true,
	"camera": [5299.2, -124]
}
```

`camera` is a level point `[x, y]` in px. The level's test then loads it
too. `make_fixture` doesn't know it, so redo it by hand after a change to
the level. A fixture with taps (a basket half full, a slime on a ledge)
needs a scripted run or a builder in `tools/make_fixture/` (code: ask for
it).

## Test mode: play and look

```sh
godot --path . -- --test-mode --level=zz-tutorial --seed=1
godot --path . -- --test-mode --level=zz-tutorial --seed=1 --fixture=gate2-open
godot --path . -- --test-mode --level=zz-tutorial --seed=1 --at=s1.branch.lookout
```

It opens a window with the pink TEST MODE banner. `--fixture=NAME` starts
from a fixture; `--at=<stable id>` puts the camera on the rails nearest that
thing (any stable ID: a sleeper, a switch, a branch; `--at=x,y` for a level
point in px). A framing zone there applies: `--at=s1.branch.lookout` opens
at the lookout's zoom 0.85. An unknown ID says so: `Test mode: 'at': no
's9.nothing' in level 'zz-tutorial'`.

Headless, `--run-ticks=N` runs N ticks (60 per second), prints the state
hash and quits: a quick "does it run" check.

```sh
godot --headless --path . -- --test-mode --level=zz-tutorial --seed=1 --run-ticks=600
```

```
STATE tick=600 hash=7b822c536b81c0315eb39ad139267f49054fa2127858ba32d9c85bc6b8643678
```

(The hash depends on the level and the seed; the same level and seed give
the same hash every time.)

Test mode exists in debug builds only; a release build refuses it.

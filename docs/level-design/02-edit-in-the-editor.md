# 02 Edit the level in the Godot editor

The recommended way to make a level: hand-placed in the editor, so what you
see is what the game loads. The components are `@tool`, so their greybox
(labelled boxes, coloured circles, route lines) shows while you edit.

## Open it

```sh
godot --path . -e res://levels/zz-tutorial/level.tscn
```

**Watch `project.godot`:** opening the editor drops the line
`window/handheld/orientation=0` from it (a default value). Don't commit that
change: `git checkout project.godot`.

## The scene's layout

The skeleton groups its nodes under plain `Node2D`s. Grouping is free: the
level finds its components at any depth.

```
LevelZzTutorial        the level root (Level): level_id, level_version
  Terrain/             S1Crust, FirstLedge, S1Pillar, S1Bump1, ..., Bedrock
  Loop/                S1Loop, S1Slide, S2Loop, S2Slide   (in loop order)
  Start/               SplitZone, FirstSlime
  Section1/
    Sleepers/          Sleeper01 ... (s1.sleeper.01 ...)
    FrontierSet/       Signpost, Switch, Basket, Gate
  Section2/ ...
```

## Place a component

1. Select the group node it belongs to (for example `Section1`).
2. Instantiate a child scene (the chain-link button, or Ctrl+Shift+A) and
   pick the component in `res://src/components/` (`sleeper.tscn`,
   `exploration_branch.tscn`, `framing_zone.tscn`, ...).
3. Move it into place, then set its fields in the inspector, `stable_id`
   first. Each component's fields are in [04](04-interactive-objects.md).
4. For a curve (terrain, decoration, a loop segment, a route back), select
   the node and draw with the curve tools in the 2D toolbar (add point,
   move point). Terrain and decoration are closed outlines that must not
   cross themselves; a loop segment and a route back are drawn in the
   direction of travel.

Duplicating a node (Ctrl+D) is the quickest way to place another of the same
kind, but **give the copy its own stable ID**: a duplicate is a load error
and a rule 20 FAIL:

```
rule 20  FAIL    A released level isn't meant to change
         - s1.sleeper.07 (x 3.12): the stable ID is used twice (Section1/Lookout/Sleeper07 and Section1/Lookout/Sleeper08): give each thing its own
```

## Units

The inspector shows pixels. The design documents give x in screens:
multiply by 1152 (x 3.08 screens is 3548.16 px). y grows downward: a ledge
200 px above ground at y -100 has its top at y -300.

## Edit the scene file as text (optional)

`level.tscn` is plain text, and small additions are easy to make in any
editor (this is how Claude edits a level for you). The pieces:

- one `[ext_resource]` line per component scene used (add it if the scene
  doesn't use that component yet; any unused `id` string will do);
- one `[sub_resource type="Curve2D"]` per curve, **above** the first
  `[node]`; its `points` hold six numbers per point: the in-handle (x, y),
  the out-handle (x, y), then the point (x, y); straight lines use zero
  handles. A closed outline repeats its first point at the end;
- one `[node]` block per node: its name, type, parent path and
  `instance=ExtResource(...)`, then the fields that differ from the
  defaults. `unique_id` and `script` lines can be left out.

A real example, an exploration branch's ledge, branch box and first
sleeper added to `zz-tutorial`:

```
[ext_resource type="PackedScene" path="res://src/components/exploration_branch.tscn" id="30_branch"]

[sub_resource type="Curve2D" id="Curve2D_lookout"]
_data = {
"points": PackedVector2Array(0, 0, 0, 0, 3490.56, -270, 0, 0, 0, 0, 3686.4, -260, 0, 0, 0, 0, 3686.4, -240, 0, 0, 0, 0, 3490.56, -250, 0, 0, 0, 0, 3490.56, -270)
}
point_count = 5

[node name="Lookout" type="Node2D" parent="Section1"]

[node name="Ledge" type="Path2D" parent="Section1/Lookout" instance=ExtResource("2_eci4l")]
curve = SubResource("Curve2D_lookout")

[node name="Branch" type="Area2D" parent="Section1/Lookout" instance=ExtResource("30_branch")]
position = Vector2(3588.48, -280)
stable_id = "s1.branch.lookout"
size = Vector2(288, 140)

[node name="Sleeper06" type="Node2D" parent="Section1/Lookout" instance=ExtResource("12_k58b7")]
position = Vector2(3548.16, -291)
stable_id = "s1.sleeper.06"
species = "C"
```

The same branch's route back (an open curve, from inside the branch down to
a point on the loop, in the direction of travel) and its framing zone:

```
[ext_resource type="PackedScene" path="res://src/components/route_back.tscn" id="31_routeback"]
[ext_resource type="PackedScene" path="res://src/components/framing_zone.tscn" id="32_frame"]

[sub_resource type="Curve2D" id="Curve2D_lookout_back"]
_data = {
"points": PackedVector2Array(0, 0, 0, 0, 3525.12, -292, 0, 0, 0, 0, 3686.4, -284, 0, 0, 0, 0, 3720, -200, 0, 0, 0, 0, 3744, -124)
}
point_count = 4

[node name="RouteBack" type="Path2D" parent="Section1/Lookout" instance=ExtResource("31_routeback")]
curve = SubResource("Curve2D_lookout_back")
stable_id = "s1.route-back.lookout"
serves = "s1.branch.lookout"

[node name="Frame" type="Area2D" parent="Section1/Lookout" instance=ExtResource("32_frame")]
position = Vector2(3594.24, -200)
stable_id = "s1.frame.lookout"
size = Vector2(576, 400)
zoom = 0.85
offset = Vector2(0, -60)
```

(`2_eci4l` and `12_k58b7` are that scene's existing ids for `terrain.tscn`
and `sleeper.tscn`: look them up at the top of your file.) Node order
matters in one place: the `Loop`'s segments, which are in loop order.

## After every change

Check it straight away, fast first (well under a second), then in full
(seconds; it runs the laps):

```sh
godot --headless --path . -s res://tools/check_level.gd -- --level=zz-tutorial --fast
godot --headless --path . -s res://tools/check_level.gd -- --level=zz-tutorial
```

See [09](09-check-the-rules.md) for reading the result.

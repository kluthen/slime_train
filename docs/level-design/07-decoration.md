# 07 Decoration

Decoration is level art that isn't simulated: plants, rocks, scenery drawn
as curves (D93). It is the `Decoration` component (`src/components/decoration.tscn`).

## How it behaves

It follows O96's proposed default (D123), until the user settles O96:

- it **never collides**: slimes pass through it. Anything a slime must
  stand on, bump into or hop up is `Terrain`, not decoration;
- it **never takes a tap**: it has no stable ID and isn't a tap target, so a
  tap on it is a call;
- it draws **behind** the level unless `in_front` is on, and one in front
  must never hide an interactive object or a hint (rule 9).

## Fields

| Field | What it does |
|---|---|
| the curve | a closed outline (repeat the first point at the end), not crossing itself |
| `fill_color` | its colour |
| `in_front` | draw it in front of the slimes and objects (default off) |
| `bake_tolerance_degrees` | how finely a curved outline is filled (default 2) |

No `stable_id`: a save never needs it, and it can change freely, even after
release.

## Add one

Instantiate `decoration.tscn` under a group (the example uses a
`Decoration` node at the level's root), draw its outline, pick a colour. As
text ([02](02-edit-in-the-editor.md)):

```
[ext_resource type="PackedScene" path="res://src/components/decoration.tscn" id="33_decoration"]

[sub_resource type="Curve2D" id="Curve2D_bush"]
_data = {
"points": PackedVector2Array(0, 0, 0, 0, 2534.4, -100, 0, 0, 0, 0, 2592, -150, 0, 0, 0, 0, 2649.6, -140, 0, 0, 0, 0, 2707.2, -100, 0, 0, 0, 0, 2534.4, -100)
}
point_count = 5

[node name="Decoration" type="Node2D" parent="."]

[node name="Bush" type="Path2D" parent="Decoration" instance=ExtResource("33_decoration")]
curve = SubResource("Curve2D_bush")
fill_color = Color(0.2, 0.45, 0.25, 1)
```

## The one rule the checker enforces

A decoration **in front** that covers an object or a hint fails rule 9. A
rock drawn in front over the lookout's first sleeper:

```
rule 9   FAIL    Hints that there is something to explore are visible from the loop
         - s1.sleeper.06 (x 3.08): decoration Decoration/Rock is drawn in front and covers it: turn its in_front off or move it
```

With `in_front` off (the rock behind the sleeper), rule 9 passes again.
Decoration behind the level can overlap anything.

Check with `--rule=9` for a quick look:

```sh
godot --headless --path . -s res://tools/check_level.gd -- --level=zz-tutorial --fast --rule=9
```

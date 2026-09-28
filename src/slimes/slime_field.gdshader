// Slime blend, pass 1: paints one slime's field into its species channel,
// additively. Vertex colour: rgb = the species' one-hot channel, a = 1 inside
// the ring, falling to 0 across the skirt. dst.rgb += rgb * shaped(a) * 0.5:
// one slime peaks at 0.5, so the 8-bit target only saturates where two
// rings overlap.
shader_type canvas_item;
render_mode blend_add, unshaded;

void fragment() {
	float f = COLOR.a;
	f = f * f * (3.0 - 2.0 * f);
	COLOR = vec4(COLOR.rgb, f * 0.5);
}

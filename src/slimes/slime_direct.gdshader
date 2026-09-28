// Slime fallback: each ring drawn on its own with a soft edge, no blending
// between slimes. Vertex colour: rgb = species colour, a = field (1 inside
// the ring, 0 at the skirt's outer edge).
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float f = COLOR.a;
	float aa = fwidth(f) * 0.75 + 1e-4;
	float cover = smoothstep(0.5 - aa, 0.5 + aa, f);
	vec3 col = COLOR.rgb * mix(0.7, 1.0, smoothstep(0.5, 0.64, f));
	COLOR = vec4(col, cover);
}

// Slime blend, pass 2: thresholds the six species fields into smooth blobs.
// Fields: species A-C in field_a.rgb, D-F in field_b.rgb. Same-species
// slimes that touch melt into one outline; different species meet at a
// darker seam.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D field_a : filter_linear, repeat_disable;
uniform sampler2D field_b : filter_linear, repeat_disable;
uniform vec3 palette[6];
uniform float threshold = 0.25; // half the peak of one slime

void fragment() {
	vec3 a = texture(field_a, SCREEN_UV).rgb;
	vec3 b = texture(field_b, SCREEN_UV).rgb;
	float f[6] = float[6](a.r, a.g, a.b, b.r, b.g, b.b);
	float best = 0.0;
	float second = 0.0;
	int k = 0;
	for (int i = 0; i < 6; i++) {
		float v = f[i];
		if (v > best) {
			second = best;
			best = v;
			k = i;
		} else if (v > second) {
			second = v;
		}
	}
	float aa = fwidth(best) * 0.75 + 1e-4;
	float cover = smoothstep(threshold - aa, threshold + aa, best);
	vec3 col = palette[k];
	// Darker rim just inside the outline.
	col *= mix(0.7, 1.0, smoothstep(threshold, threshold + 0.07, best));
	// Darker seam where two species meet.
	float seam = (1.0 - smoothstep(0.0, 0.05, best - second)) * step(threshold, second);
	col *= mix(1.0, 0.7, seam);
	COLOR = vec4(col, cover);
}

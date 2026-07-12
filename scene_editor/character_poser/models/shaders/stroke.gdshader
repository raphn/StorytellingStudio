shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert;

uniform vec4 base_color : source_color = vec4(0.8, 0.75, 0.65, 1.0);
uniform vec4 stroke_color : source_color = vec4(0.04, 0.03, 0.02, 1.0);

uniform float stroke_width : hint_range(0.001, 0.1) = 0.025;
uniform float stroke_softness : hint_range(0.001, 0.1) = 0.018;
uniform float stroke_strength : hint_range(0.0, 2.0) = 1.0;

uniform float wobble_strength : hint_range(0.0, 0.1) = 0.025;
uniform float wobble_scale = 35.0;

uniform float broken_stroke_amount : hint_range(0.0, 1.0) = 0.25;
uniform float broken_stroke_scale = 18.0;

varying vec3 bary;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) +
		(c - a) * u.y * (1.0 - u.x) +
		(d - b) * u.x * u.y;
}

void vertex() {
	int index = VERTEX_ID % 3;

	if (index == 0) {
		bary = vec3(1.0, 0.0, 0.0);
	} else if (index == 1) {
		bary = vec3(0.0, 1.0, 0.0);
	} else {
		bary = vec3(0.0, 0.0, 1.0);
	}
}

void fragment() {
	vec3 d = fwidth(bary);

	float edge_dist = min(min(bary.x, bary.y), bary.z);

	float wobble = noise(UV * wobble_scale) * wobble_strength;
	float width = stroke_width + wobble;

	float edge = 1.0 - smoothstep(width, width + stroke_softness, edge_dist);

	float break_noise = noise(UV * broken_stroke_scale);
	float broken = smoothstep(broken_stroke_amount, 1.0, break_noise);

	float stroke = clamp(edge * broken * stroke_strength, 0.0, 1.0);

	ALBEDO = mix(base_color.rgb, stroke_color.rgb, stroke);
	ALPHA = base_color.a;
}
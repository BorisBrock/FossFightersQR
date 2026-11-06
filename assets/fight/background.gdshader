shader_type canvas_item;
// The boss's background: darker at the edges, so the boss and the players stand out,
// with mist drifting slowly over the ground.

uniform vec4 mist_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float mist_strength = 0.35;
uniform float dim = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float vignette = 1.0 - 0.6 * smoothstep(0.3, 0.85, length((uv - 0.5) * vec2(1.0, 0.8)));
	vec3 color = COLOR.rgb * dim * vignette;
	float mist = noise(uv * vec2(3.0, 7.0) + vec2(TIME * 0.025, 0.0)) * 0.6
		+ noise(uv * vec2(7.0, 13.0) - vec2(TIME * 0.04, TIME * 0.01)) * 0.4;
	float ground = smoothstep(0.35, 0.95, uv.y);
	color = mix(color, mist_color.rgb, mist * mist_strength * ground);
	COLOR.rgb = color;
}

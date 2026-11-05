shader_type canvas_item;
// The table at dusk: darkened towards the edges, with a flickering candle and a
// breathing potion. Their positions are in the coordinates of the table image.

uniform vec2 candle_at = vec2(0.91, 0.08);
uniform vec2 potion_at = vec2(0.76, 0.87);
uniform float dim = 0.72;

float glow(vec2 uv, vec2 center, float radius) {
	vec2 offset = (uv - center) * vec2(1.0, 1.78);
	return exp(-dot(offset, offset) / (radius * radius));
}

void fragment() {
	float flicker = 0.75 + 0.15 * sin(TIME * 7.3) + 0.1 * sin(TIME * 13.7 + 1.0);
	float breath = 0.7 + 0.3 * sin(TIME * 1.4);
	vec2 centered = SCREEN_UV - 0.5;
	float vignette = 1.0 - 0.75 * smoothstep(0.2, 0.75, length(centered));
	vec3 light = vec3(dim * vignette);
	light += vec3(1.0, 0.62, 0.3) * glow(UV, candle_at, 0.22) * flicker * 0.75;
	light += vec3(0.35, 0.55, 1.0) * glow(UV, potion_at, 0.2) * breath * 0.6;
	COLOR.rgb *= light;
}

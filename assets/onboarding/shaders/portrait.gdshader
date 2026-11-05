shader_type canvas_item;
// Cuts art into a rounded square (corner = 0.5 makes a circle) with a metal ring, and
// can wash it out to show that it is not selected.

uniform float corner : hint_range(0.0, 0.5) = 0.5;
uniform float ring_width : hint_range(0.0, 0.2) = 0.03;
uniform vec3 ring_color : source_color = vec3(0.85, 0.66, 0.3);
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float brightness = 1.0;

void fragment() {
	vec2 edge = abs(UV - 0.5) - (0.5 - corner);
	float dist = length(max(edge, vec2(0.0))) + min(max(edge.x, edge.y), 0.0) - corner;
	float smoothing = fwidth(dist);
	float gray = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	vec3 picture = mix(COLOR.rgb, vec3(gray), desaturate) * brightness;
	float ring = smoothstep(-ring_width - smoothing, -ring_width, dist);
	// Light catching the ring from the top left.
	vec3 metal = ring_color * (0.8 + 0.5 * (1.0 - UV.x - UV.y + 0.5));
	COLOR.rgb = mix(picture, metal, ring_width > 0.0 ? ring : 0.0);
	COLOR.a *= 1.0 - smoothstep(-smoothing, 0.0, dist);
}

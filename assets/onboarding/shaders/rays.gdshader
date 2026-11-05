shader_type canvas_item;
// Slowly turning rays of light that fade out from the centre.

uniform int ray_count = 12;
uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.4);

void fragment() {
	vec2 offset = UV - 0.5;
	float angle = atan(offset.y, offset.x) + TIME * 0.5;
	float rays = 0.5 + 0.5 * cos(angle * float(ray_count));
	float fade = 1.0 - smoothstep(0.1, 0.5, length(offset));
	COLOR = vec4(tint, smoothstep(0.35, 0.9, rays) * fade * COLOR.a);
}

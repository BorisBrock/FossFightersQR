shader_type canvas_item;
// Fades a picture to grey, for what is not available yet, such as an attack type nobody
// has attacked with this round. 0 is in colour, 1 grey.

uniform float gray : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	float light = dot(color.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(mix(color.rgb, vec3(light) * 0.8, gray), color.a);
}

shader_type canvas_item;
// Fades a picture to grey, for what is not available yet, such as an attack type nobody
// has attacked with this round. 0 is in colour, 1 grey: each pixel keeps its brightness
// and only loses its colour. lift brightens the dark parts of the picture, without
// washing out its highlights (0 leaves it as painted).

uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform float lift : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// In Godot 4, COLOR here is already the texture times the modulate and vertex colour:
	// multiplying by texture(TEXTURE, UV) again would square the colours (orange to red).
	vec4 color = COLOR;
	vec3 rgb = pow(max(color.rgb, vec3(0.0)), vec3(1.0 - 0.5 * lift));
	float light = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(rgb, vec3(light), gray), color.a);
}

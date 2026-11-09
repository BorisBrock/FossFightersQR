shader_type canvas_item;
// Fades a picture to grey, for what is not available yet, such as an attack type nobody
// has attacked with this round. 0 is in colour, 1 grey.
// The grey is gray_scale * brightness + gray_lift, so that dark pictures can stay readable
// as light grey. lift brightens the dark parts of the picture, in colour or grey, without
// washing out its highlights (0 leaves it as painted).

uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform float gray_scale = 0.8;
uniform float gray_lift = 0.0;
uniform float lift : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// In Godot 4, COLOR here is already the texture times the modulate and vertex colour:
	// multiplying by texture(TEXTURE, UV) again would square the colours (orange to red).
	vec4 color = COLOR;
	vec3 rgb = pow(max(color.rgb, vec3(0.0)), vec3(1.0 - 0.5 * lift));
	float light = dot(rgb, vec3(0.3, 0.59, 0.11));
	vec3 grey = vec3(clamp(light * gray_scale + gray_lift, 0.0, 1.0));
	COLOR = vec4(mix(rgb, grey, gray), color.a);
}

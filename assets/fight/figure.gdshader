shader_type canvas_item;
// Keeps a boss alive without frames of animation. It stays anchored at its feet: it
// breathes (grows taller), hovers (floats up and down) or sways (leans from side to
// side). Amounts are in pixels on screen.

uniform float breathe = 0.0;
uniform float hover = 0.0;
uniform float sway = 0.0;
uniform float seconds = 4.0;
// Lights the boss up, for hits. 0 is off.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float wave = sin(TIME * TAU / seconds);
	// 1 at the top of the picture, 0 at the feet.
	float height = 1.0 - UV.y;
	VERTEX.y -= height * breathe * (0.5 + 0.5 * wave);
	VERTEX.y += hover * wave;
	VERTEX.x += height * sway * wave;
}

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}

shader_type canvas_item;
// Keeps a boss alive without frames of animation. It stays anchored at its feet: it
// breathes (grows taller), hovers (floats up and down), sways (leans from side to side) or
// slithers (a wave runs up its body). Amounts are in pixels on screen, slither in pixels of
// the picture. It can also sink below its bottom edge, as into water, and its eyes can glow.

uniform float breathe = 0.0;
uniform float hover = 0.0;
uniform float sway = 0.0;
uniform float slither = 0.0;
uniform float seconds = 4.0;
// Lights the boss up, for hits, in flash_color. 0 is off.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
// Shakes the boss, as hits do, in pixels.
uniform vec2 shake = vec2(0.0);
// How far the boss has sunk below its bottom edge, in parts of its height: 0 is all
// there, 1 is gone. Near the edge it fades, like a waterline.
uniform float sink : hint_range(0.0, 1.0) = 0.0;
// 1 for a boss that rises from water: its bottom edge always fades, like a waterline.
uniform float waterline : hint_range(0.0, 1.0) = 0.0;
// The glow of its eyes, at eye_left and eye_right (parts of the picture, outside 0 to 1
// for none), eye_radius in pixels of the picture.
uniform vec2 eye_left = vec2(-1.0);
uniform vec2 eye_right = vec2(-1.0);
uniform float eye_radius = 14.0;
uniform vec3 eye_color : source_color = vec3(1.0, 0.85, 0.3);
uniform float eye_glow = 0.0;

varying vec4 tint;

void vertex() {
	float wave = sin(TIME * TAU / seconds);
	// 1 at the top of the picture, 0 at the feet.
	float height = 1.0 - UV.y;
	VERTEX.y -= height * breathe * (0.5 + 0.5 * wave);
	VERTEX.y += hover * wave;
	VERTEX.x += height * sway * wave;
	VERTEX += shake;
	tint = COLOR;
}

float eye(vec2 uv, vec2 at, vec2 pixel) {
	if (at.x < 0.0) {
		return 0.0;
	}
	float distance_px = length((uv - at) / pixel);
	return exp(-pow(distance_px / max(eye_radius, 1.0), 2.0));
}

void fragment() {
	vec2 uv = UV;
	// The wave starts at the bottom and runs up, growing towards the head.
	float height = 1.0 - UV.y;
	float phase = TIME * TAU / seconds;
	uv.x -= slither * TEXTURE_PIXEL_SIZE.x * pow(height, 1.5) * sin(phase - height * 5.0);
	uv.y += slither * TEXTURE_PIXEL_SIZE.y * 0.25 * pow(height, 2.0) * cos(phase * 0.5);
	uv.y -= sink;
	vec4 color = vec4(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		color = texture(TEXTURE, uv);
	}
	float glow = eye_glow * (0.85 + 0.15 * sin(TIME * 3.0))
		* (eye(uv, eye_left, TEXTURE_PIXEL_SIZE) + eye(uv, eye_right, TEXTURE_PIXEL_SIZE));
	color.rgb = mix(color.rgb, eye_color, clamp(glow, 0.0, 1.0));
	color.a = max(color.a, clamp(glow, 0.0, 1.0) * 0.8);
	// The waterline: what is about to go under fades, once the boss sinks, or always for a
	// boss in water, where it also darkens a little.
	float water = max(waterline, clamp(sink * 12.0, 0.0, 1.0));
	color.a *= mix(1.0, smoothstep(1.0, 0.93, UV.y), water);
	color.rgb *= mix(1.0, mix(0.55, 1.0, smoothstep(1.0, 0.85, UV.y)), waterline);
	color *= tint;
	color.rgb = mix(color.rgb, flash_color, flash * color.a);
	COLOR = color;
}

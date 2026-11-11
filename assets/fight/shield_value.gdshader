shader_type canvas_item;
// The numbers below the boss's shields: polished metal in the damage type's colour. Like
// chrome lettering it reflects a light sky in the upper half and a dark horizon at the
// middle, then a bright ground just below that fades into shade at the bottom, with a
// soft highlight sweeping over it. Only the fill shines: the dark outline and the glow
// stay as they are. top and bottom are where the digits begin and end in the label, in
// pixels (BossFight sets them).

uniform float top = 0.0;
uniform float bottom = 40.0;
// How much lighter the top and the ground below the horizon get, and how much darker the
// horizon and the bottom.
uniform float sky = 0.42;
uniform float ground = 0.3;
uniform float horizon = 0.45;
uniform float shade = 0.35;

varying vec2 position;

void vertex() {
	position = VERTEX;
}

void fragment() {
	vec4 color = COLOR;
	float t = clamp((position.y - top) / max(bottom - top, 1.0), 0.0, 1.0);
	// 0 on the dark outline and glow, 1 on the coloured fill.
	float fill = smoothstep(0.12, 0.3, max(color.r, max(color.g, color.b)));

	// The sky: white at the top, fading into the colour towards the horizon.
	float lighten = sky * (1.0 - smoothstep(0.0, 0.5, t));
	// The ground: a bright band right below the horizon, fading downwards.
	lighten += ground * smoothstep(0.5, 0.56, t) * (1.0 - smoothstep(0.56, 0.9, t));
	vec3 metal = mix(color.rgb, vec3(1.0), lighten);
	// The horizon: a soft dark band just above the middle; and shade at the bottom.
	float darken = horizon * smoothstep(0.36, 0.5, t) * (1.0 - smoothstep(0.5, 0.56, t));
	darken += shade * smoothstep(0.75, 1.0, t);
	metal *= 1.0 - darken;
	// A soft, slanted highlight across the upper half.
	metal += vec3(0.18) * (1.0 - smoothstep(0.0, 0.18, abs(t - 0.22 - 0.004 * position.x)));

	COLOR = vec4(mix(color.rgb, metal, fill), color.a);
}

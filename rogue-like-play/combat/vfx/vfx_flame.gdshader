shader_type canvas_item;
render_mode blend_add, unshaded;

// Fire bursting from a point (Vfx.flame), seen from above: the painted row
// of flames (art/effects/vfx/flame_strip.png, rising from its bottom edge)
// rolled into a ring whose foot runs out from the middle and whose tongues
// reach past it, licking as they go; the ground inside glows for a moment;
// then it burns out. Coloured by heat. The blast's reach is at REACH of the
// quad's half width.

uniform float age = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float seed = 0.0;
// How many times the row goes round.
uniform float turns = 2.0;
uniform sampler2D noise : repeat_enable, filter_linear;

const float REACH = 0.9;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 / REACH;
	float far = length(p);
	float round_it = atan(p.y, p.x) / TAU + 0.5;
	float out_now = 1.0 - pow(1.0 - clamp(age / 0.3, 0.0, 1.0), 2.5);
	float foot = mix(0.04, 0.4, out_now);
	// The tongues are not all of a height, and the whole turns as it burns.
	float uneven = texture(noise, vec2(round_it * 2.0 + seed * 3.0, seed)).g;
	float tall = mix(0.45, 0.66, out_now) * (1.0 - 0.35 * smoothstep(0.5, 1.0, age)) * (0.7 + 0.6 * uneven);
	float up = (far - foot) / tall;
	float cloud = texture(noise, vec2(round_it * 3.0 + seed, far * 1.1 - age * 1.4)).r;
	vec2 at = vec2(round_it * turns + seed + age * 0.2 + (cloud - 0.5) * 0.05 * clamp(up, 0.0, 1.0), 1.0 - clamp(up, 0.0, 1.0));
	float fire = texture(TEXTURE, at).r * step(up, 1.0) * step(0.0, up);
	// The ground inside it glows, in patches, for a moment.
	float embers = texture(noise, vec2(p * 1.4 + seed)).g;
	float bed = step(far, foot) * mix(0.25, 1.0, far / max(foot, 0.01)) * (0.45 + 0.9 * embers) * (1.0 - smoothstep(0.1, 0.55, age));
	float heat = max(fire, bed);
	float gone = smoothstep(0.3, 1.0, age);
	heat *= smoothstep(gone * 1.25 - 0.25, gone * 1.25, cloud * 0.55 + heat * 0.45);
	heat *= 1.0 - smoothstep(0.82, 1.0, age);
	vec3 colour = mix(vec3(0.7, 0.08, 0.02), vec3(1.0, 0.42, 0.07), smoothstep(0.08, 0.45, heat));
	colour = mix(colour, vec3(1.0, 0.84, 0.42), smoothstep(0.45, 0.82, heat));
	colour = mix(colour, vec3(1.0, 0.96, 0.8), smoothstep(0.92, 1.0, heat));
	COLOR = vec4(colour * tint.rgb, clamp(heat * 1.15, 0.0, 0.88) * tint.a);
}

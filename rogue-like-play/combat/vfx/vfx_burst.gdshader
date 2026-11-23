shader_type canvas_item;
render_mode blend_add, unshaded;

// A blow landing (Vfx.burst): the painted burst (the still of a hit, a
// heavy blow or a spell) snapping open and thinning, a white heart for an
// instant, a thin ring of shock running out, and rays thrown from it,
// longer the way the blow went. `weight` (0 to 1) makes it a heavier blow:
// a harder heart, more rays.

uniform float age = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform vec2 toward = vec2(0.0);
uniform float weight = 0.0;
uniform float seed = 0.0;
uniform sampler2D noise : repeat_enable, filter_linear;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float far = length(p);
	float round_it = atan(p.y, p.x) / TAU + 0.5;
	// The painted burst, opening fast.
	float open = mix(0.5, 1.0, 1.0 - pow(1.0 - age, 4.0));
	vec2 at = (UV - 0.5) / open + 0.5;
	float within = step(0.0, at.x) * step(at.x, 1.0) * step(0.0, at.y) * step(at.y, 1.0);
	vec3 picture = texture(TEXTURE, at).rgb * within;
	float cloud = texture(noise, vec2(round_it * 2.0 + seed, far - age * 0.6)).r;
	float thin = smoothstep(age * 1.35 - 0.35, age * 1.35, cloud * 0.6 + 0.4 * (1.0 - far));
	picture *= thin * (1.0 - smoothstep(0.55, 1.0, age));
	// Its heart, for an instant.
	float heart = smoothstep(mix(0.3, 0.45, weight), 0.0, far) * (1.0 - smoothstep(0.0, 0.28, age));
	// The shock running out.
	float front = mix(0.2, 0.92, 1.0 - pow(1.0 - age, 2.6));
	float shock = smoothstep(0.06, 0.0, abs(far - front)) * (1.0 - age) * (1.0 - age);
	// Rays, by the way round: some reach far, most do not.
	float chance = texture(noise, vec2(round_it * 5.0 + seed * 7.0, seed)).g;
	float lean = dot(normalize(p + vec2(0.0001)), toward);
	float reach = front * (0.55 + 0.7 * chance) * (1.0 + 0.45 * max(lean, 0.0));
	float ray = smoothstep(mix(0.62, 0.5, weight), 0.85, chance);
	float streak = ray * smoothstep(reach, reach * 0.3, far) * smoothstep(0.1, 0.24, far) * (1.0 - smoothstep(0.35, 1.0, age));
	vec3 colour = picture * mix(vec3(1.0), tint.rgb, 0.35) + tint.rgb * (shock * 0.9 + streak) + vec3(1.0, 0.98, 0.92) * heart;
	COLOR = vec4(colour, tint.a);
}

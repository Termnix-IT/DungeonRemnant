shader_type canvas_item;
render_mode blend_add, unshaded;

// A shock running out over the floor (GroundRing): the painted ring
// (art/effects/vfx/shock_ring.png, its outer edge at EDGE of the picture's
// half width) carried from the blow's middle out to its reach, which is
// where its front stops: the ring shows what the blow covered. Behind the
// front it burns away from the inside. The blow's reach is at REACH of the
// quad's half width.

uniform float age = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform float seed = 0.0;
uniform sampler2D noise : repeat_enable, filter_linear;

const float EDGE = 0.86;
const float REACH = 0.88;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 / REACH;
	float far = length(p);
	float front = mix(0.25, 1.0, 1.0 - pow(1.0 - age, 3.0));
	float share = far / front;
	float round_it = atan(p.y, p.x) + seed * TAU;
	vec2 at = 0.5 + 0.5 * EDGE * share * vec2(cos(round_it), sin(round_it));
	float within = step(share, 1.0 / EDGE);
	// Its streaks are strong at the front and thin toward the middle, so
	// what stands inside the blow is not painted over.
	float core = texture(TEXTURE, at).r * within * mix(0.22, 1.0, smoothstep(0.5, 0.96, share));
	float glow = textureLod(TEXTURE, at, 3.0).r * within;
	float cloud = texture(noise, vec2(round_it * 0.4, far * 1.3 - age * 0.8)).r;
	float kept = smoothstep(age * 1.15 - 0.3, age * 1.15, share * 0.72 + cloud * 0.28);
	float fade = 1.0 - smoothstep(0.5, 1.0, age);
	float floor_light = step(share, 1.0) * 0.07 * (1.0 - age);
	float light = (core * kept * 1.1 + glow * 0.3 * smoothstep(0.4, 0.9, share) + floor_light) * fade;
	vec3 colour = mix(tint.rgb, vec3(1.0), smoothstep(0.6, 1.0, core));
	COLOR = vec4(colour, clamp(light, 0.0, 1.0) * tint.a);
}

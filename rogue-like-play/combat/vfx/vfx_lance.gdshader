shader_type canvas_item;
render_mode blend_add, unshaded;

// A thrust, or a shot's streak (Vfx.lance): the painted trail run straight
// along the quad's +x, mirrored about its middle line so its sharp edge is
// the core of the streak and its brushed side fans out either way. The head
// runs to the tip and the streak thins away behind it. `steady` holds it
// whole instead (a flying shot's tail), fading only with `age`.

uniform float age = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float seed = 0.0;
uniform float steady = 0.0;
uniform sampler2D noise : repeat_enable, filter_linear;

const float SWEEP = 0.34;

void fragment() {
	float reached = 1.0 - pow(1.0 - clamp(age / SWEEP, 0.0, 1.0), 3.0);
	float head = mix(mix(0.3, 1.0, reached), 1.0, steady);
	float behind = (head - UV.x) / mix(0.8, 1.0, steady);
	float side = abs(UV.y - 0.5) * 2.0;
	// A point at its head, widest just behind it, thinning to its tail.
	float width = mix(1.0, 0.3, clamp(behind, 0.0, 1.0)) * smoothstep(0.0, 0.16, behind);
	float across = side / width;
	float inside = step(0.0, behind) * step(behind, 1.0) * step(across, 1.0);
	vec2 at = vec2(1.0 - behind, across);
	float core = texture(TEXTURE, at).r;
	float glow = textureLod(TEXTURE, at, 3.0).r;
	float cloud = texture(noise, vec2(UV.x * 0.7 + seed - age * 0.6, UV.y * 0.5)).b;
	float gone = clamp((age - SWEEP * 0.6) / (1.0 - SWEEP * 0.6), 0.0, 1.0) * (1.0 - steady);
	float kept = smoothstep(gone * 1.3 - 0.3, gone * 1.3, cloud * 0.5 + (1.0 - behind) * 0.5);
	float tail = 1.0 - smoothstep(0.6, 1.0, behind);
	float light = (core * 1.1 + glow * 0.45) * kept * inside * tail * (1.0 - smoothstep(0.75, 1.0, age) * (1.0 - steady));
	light *= mix(1.0, 0.75 + 0.25 * cloud, steady);
	vec3 colour = mix(tint.rgb, vec3(1.0), smoothstep(0.7, 0.98, core) * (1.0 - behind * 0.6));
	COLOR = vec4(colour, clamp(light, 0.0, 1.0) * tint.a);
}

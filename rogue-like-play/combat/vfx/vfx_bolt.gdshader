shader_type canvas_item;
render_mode blend_add, unshaded;

// Lightning from one point to another (Vfx.bolt): one of the three painted
// bolts (art/effects/vfx/bolt_strip.png, one above another) drawn along the
// quad's +x. It strikes three times in its life, each strike along another
// of the three and a little further along the strip, so it is never the
// same line twice; its ends are drawn in to the quad's middle line, where
// the things it joins are.

uniform float age = 0.0;
uniform vec4 tint : source_color = vec4(0.7, 0.88, 1.0, 1.0);
// How much of the strip's length the bolt takes (a short jump takes less).
uniform float span = 1.0;
uniform float seed = 0.0;

const float STRIKES = 3.0;

void fragment() {
	float strike = min(floor(age * STRIKES), STRIKES - 1.0);
	float since = fract(min(age, 0.999) * STRIKES);
	float row = mod(strike + floor(seed * 3.0), 3.0);
	float gather = max(0.14, smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x));
	float down = 0.5 + (UV.y - 0.5) / gather;
	float inside = step(0.0, down) * step(down, 1.0);
	vec2 at = vec2(UV.x * span + seed * 3.7 + strike * 0.37, (row + clamp(down, 0.04, 0.96)) / 3.0);
	float core = texture(TEXTURE, at).r * inside;
	float glow = textureLod(TEXTURE, at, 3.0).r * inside;
	float strength = strike < 0.5 ? 1.0 : (strike < 1.5 ? 0.5 : 0.85);
	float flash = (1.0 - since * since) * strength * (1.0 - smoothstep(0.82, 1.0, age));
	vec3 colour = mix(tint.rgb, vec3(1.0), smoothstep(0.35, 0.9, core));
	COLOR = vec4(colour, clamp((core * 1.35 + glow) * flash, 0.0, 1.0) * tint.a);
}

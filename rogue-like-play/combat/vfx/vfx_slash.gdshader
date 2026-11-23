shader_type canvas_item;
render_mode blend_add, unshaded;

// A blade's cut through the air (Vfx.slash): the painted trail
// (art/effects/vfx/slash_trail.png: laid out straight, its head at the
// right, its sharp outer edge along the top) bent round an arc about the
// one who swings. The head crosses the arc fast and eases out; the trail
// follows it, and once the blade has passed it burns away from its tail.
// The quad's +x is the way the blow faces; the blow's reach is at REACH of
// the quad's half width, so the glow has room past it.

uniform float age = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.7, 1.0);
// The arc: this many radians either side of the facing; swept clockwise on
// the screen (1) or the other way (-1).
uniform float half_arc = 1.05;
uniform float turn = 1.0;
// 0: a light cut. 1: a heavy one: a wider band, a longer trail.
uniform float weight = 0.0;
uniform float seed = 0.0;
uniform sampler2D noise : repeat_enable, filter_linear;

const float REACH = 0.87;
// The share of its life the blade takes to cross the arc.
const float SWEEP = 0.4;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 / REACH;
	float far = length(p);
	float along = atan(p.y, p.x) * turn;
	float crossed = 1.0 - pow(1.0 - clamp(age / SWEEP, 0.0, 1.0), 3.0);
	float head = mix(-half_arc, half_arc, crossed) + 0.1;
	// A whole turn's cut is measured round from where it began, not across
	// the seam behind the swinger.
	float from_start = along + half_arc;
	if (half_arc > PI - 0.01) {
		from_start = mod(from_start, 2.0 * PI);
	}
	float trail = half_arc * 2.0 * mix(0.85, 1.2, weight);
	float behind = (head + half_arc - from_start) / trail;
	// The band is widest at the head and draws in to its outer edge toward
	// the tail, so the cut is a crescent and not a slice of a ring.
	float inner = mix(mix(0.44, 0.34, weight), 0.9, pow(clamp(behind, 0.0, 1.0), 1.4));
	float across = (far - inner) / (1.0 - inner);
	float inside = step(0.0, behind) * step(behind, 1.0) * step(0.0, across) * step(across, 1.0);
	vec2 at = vec2(1.0 - behind, 1.0 - across);
	// The paint, with the brush's streaks drawn through it along the cut
	// (its head is painted solid, and would read as a white wedge).
	float streaks = texture(noise, vec2(behind * 0.45 + seed, across * 1.7)).b;
	float core = texture(TEXTURE, at).r * mix(0.62, 1.0, streaks);
	float glow = textureLod(TEXTURE, at, 3.5).r;
	// It burns away from the tail once the blade has passed.
	float cloud = texture(noise, vec2(along * 0.55 + seed, far * 0.8 - age * 0.5)).r;
	float gone = clamp((age - SWEEP * 0.55) / (1.0 - SWEEP * 0.55), 0.0, 1.0);
	float kept = smoothstep(gone * 1.3 - 0.3, gone * 1.3, cloud * 0.55 + (1.0 - behind) * 0.45);
	float tail = 1.0 - smoothstep(0.55, 1.0, behind);
	float light = (core * 0.95 + glow * 0.3) * kept * inside * tail * (1.0 - smoothstep(0.78, 1.0, age));
	// White only where the paint is at its brightest (the blade's edge and
	// its head); the tint through the body, deepening toward the tail.
	vec3 hot = mix(tint.rgb, vec3(1.0), smoothstep(0.72, 0.98, core) * (1.0 - behind * 0.6));
	vec3 colour = mix(hot, tint.rgb * vec3(0.95, 0.55, 0.45), smoothstep(0.15, 0.9, behind) * 0.75);
	// The blade itself, at the trail's head while it crosses: a white line
	// a little longer than the trail is wide, so the head reads as steel
	// and not as the cut end of a ring.
	float steel = smoothstep(0.05 / trail, 0.0, abs(behind)) * smoothstep(mix(0.36, 0.28, weight), mix(0.5, 0.42, weight), far) * smoothstep(1.06, 1.0, far) * (1.0 - smoothstep(SWEEP * 0.9, SWEEP * 1.4, age));
	colour = mix(colour, vec3(1.0), steel);
	COLOR = vec4(colour, clamp(light + steel * 0.85, 0.0, 0.92) * tint.a);
}

shader_type canvas_item;

// The painting behind a run's result (RunEndView), lit and moving: its
// light comes out from where it stands in the picture (the open door, the
// way out of the corridor), or the whole picture comes up out of the dark
// (the fallen sword); the light breathes; dust drifts in it, or embers rise
// from the floor; and the side the words stand on is settled darker.

// How far the scene's light has come (0: dark, 1: all of it).
uniform float light = 1.0;
// Where the light comes from (a place in the picture), and how the picture
// comes up: 1 spreads out from that place, 0 rises everywhere at once.
uniform vec2 source = vec2(0.74, 0.36);
uniform float spread = 1.0;
// The light's own colour, how strongly it breathes, and how far it reaches.
uniform vec4 glow_colour : source_color = vec4(1.0, 0.86, 0.56, 1.0);
uniform float glow = 0.0;
uniform float glow_reach = 0.34;
// A burst at the light's place for a moment (the echo counted, the seal).
uniform float flare = 0.0;
// How much the picture itself is brought up round the light's place (a dark
// picture's one thing to be seen: the sword).
uniform float lift = 0.0;
uniform float lift_reach = 0.3;
// Motes drifting in the light (0 to 1), and embers rising from `ember_from`.
uniform float motes = 0.0;
uniform float embers = 0.0;
uniform vec2 ember_from = vec2(0.72, 0.74);
uniform vec4 ember_colour : source_color = vec4(1.0, 0.5, 0.2, 1.0);
// How dark the words' side is settled (the left), and how far across.
uniform float shade = 0.0;
uniform float shade_reach = 0.6;
// The picture's width over its height.
uniform float aspect = 1.7778;
uniform float time = 0.0;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 from_light = (UV - source) * vec2(aspect, 1.0);
	float away = length(from_light);
	// The picture coming up: out from the light, or everywhere at once.
	float reach = light * 2.6;
	float spreading = smoothstep(reach, reach - 1.1, away);
	float lit = mix(light, spreading, spread);
	lit = clamp(lit, 0.0, 1.0);
	// A picture not yet lit is not black: its shapes stand in a deep dusk.
	vec3 dusk = base.rgb * vec3(0.1, 0.11, 0.16);
	vec3 colour = mix(dusk, base.rgb, lit);
	colour *= 1.0 + lift * lit * exp(-away * away / (lift_reach * lift_reach));
	// The light breathing where it stands, and its burst.
	float breath = 0.82 + 0.18 * sin(time * 0.9);
	float halo = exp(-away * away / (glow_reach * glow_reach));
	colour += glow_colour.rgb * halo * (glow * breath * lit + flare) * 0.55;
	// Motes in the light: slow, small, brighter nearer the light.
	if (motes > 0.001) {
		float sum = 0.0;
		for (int i = 0; i < 26; i++) {
			float n = float(i);
			float speed = 0.012 + 0.02 * hash(n + 3.1);
			vec2 home = vec2(hash(n + 0.7), hash(n + 1.9));
			vec2 at = vec2(source.x + (home.x - 0.5) * 0.62, fract(home.y + time * speed) * 0.9 + 0.02);
			at.x += sin(time * (0.3 + hash(n + 5.3) * 0.5) + n) * 0.012;
			vec2 gap = (UV - at) * vec2(aspect, 1.0);
			float size = 0.0016 + 0.0026 * hash(n + 8.8);
			float twinkle = 0.55 + 0.45 * sin(time * (1.1 + hash(n + 2.2) * 1.6) + n * 1.7);
			sum += smoothstep(size, 0.0, length(gap)) * twinkle * (0.35 + 0.65 * exp(-abs(at.x - source.x) * 5.0));
		}
		colour += glow_colour.rgb * sum * motes * lit * 0.7;
	}
	// Embers rising from the floor, swaying, dying as they climb.
	if (embers > 0.001) {
		float sum = 0.0;
		for (int i = 0; i < 22; i++) {
			float n = float(i);
			float life = fract(time * (0.07 + 0.09 * hash(n + 11.0)) + hash(n + 4.4));
			float drift = (hash(n + 6.6) - 0.5) * 0.2;
			vec2 at = ember_from + vec2(drift * (0.3 + life) + sin(time * (0.8 + hash(n) * 0.9) + n * 2.1) * 0.012 * life, -life * (0.3 + 0.32 * hash(n + 9.2)));
			vec2 gap = (UV - at) * vec2(aspect, 1.0);
			float size = (0.0034 + 0.003 * hash(n + 7.1)) * (1.0 - life * 0.6);
			float alive = smoothstep(0.0, 0.08, life) * (1.0 - life) * (1.0 - life);
			sum += smoothstep(size, 0.0, length(gap)) * alive;
		}
		// A low glow where they come from.
		vec2 bed = (UV - ember_from) * vec2(aspect * 0.55, 1.6);
		float warmth = exp(-dot(bed, bed) / 0.012) * (0.5 + 0.12 * sin(time * 2.3) + 0.08 * sin(time * 5.1));
		colour += ember_colour.rgb * (sum * 1.4 + warmth * 0.3) * embers * (0.25 + 0.75 * lit);
	}
	// The words' side, settled.
	float settled = smoothstep(shade_reach, 0.0, UV.x);
	colour *= 1.0 - shade * settled;
	COLOR = vec4(colour, base.a) * COLOR;
}

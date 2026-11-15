// The upgrades page's sky (MetaUpgradePage): a round window of night inside
// the chart's rim, clouded and specked with small stars that twinkle, warmer
// round the lantern at its pole, and a soft shade round the rim on whatever
// lies behind, so the words outside it read. Drawn in the page's design
// space (1520x686): `origin` and `zoom` place that space in the rect, whose
// size in pixels is `extent`. `pole` is the chart's centre and `reach` its
// rim's half width and half height. The colours are the theme's (StarChart).
shader_type canvas_item;

uniform vec2 extent = vec2(1520.0, 686.0);
uniform vec2 origin = vec2(0.0);
uniform float zoom = 1.0;
uniform vec2 pole = vec2(545.0, 343.0);
uniform vec2 reach = vec2(406.0, 308.0);
uniform vec4 sky_deep : source_color = vec4(0.016, 0.022, 0.046, 1.0);
uniform vec4 sky_light : source_color = vec4(0.050, 0.070, 0.135, 1.0);
uniform vec4 sky_haze : source_color = vec4(0.20, 0.12, 0.30, 1.0);
uniform vec4 lamp : source_color = vec4(1.0, 0.78, 0.42, 1.0);
uniform vec4 speck : source_color = vec4(0.75, 0.82, 1.0, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amp * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return sum;
}

void fragment() {
	vec2 p = (UV * extent - origin) / zoom;
	// 1 on the rim, less inside it.
	float d = length((p - pole) / reach);
	float cloud = fbm(p * 0.0045 + vec2(3.0, 1.0));
	vec3 sky = mix(sky_deep.rgb, sky_light.rgb, cloud * cloud * 1.6);
	sky += sky_haze.rgb * pow(fbm(p * 0.008 + vec2(11.0, 7.0)), 3.0) * 0.5;
	vec2 cell = floor(p / 11.0);
	vec2 in_cell = fract(p / 11.0) - 0.5 + (vec2(hash(cell + 1.0), hash(cell + 2.0)) - 0.5) * 0.6;
	float star = step(0.982, hash(cell)) * smoothstep(0.16, 0.0, length(in_cell));
	float twinkle = 0.6 + 0.4 * sin(TIME * (0.6 + hash(cell + 3.0) * 1.6) + hash(cell + 9.0) * 6.28);
	sky += speck.rgb * star * twinkle * (0.25 + 0.5 * hash(cell + 5.0));
	sky += lamp.rgb * exp(-length(p - pole) / 170.0) * 0.16;
	// Darker toward the rim, as a lens is.
	sky *= 1.0 - 0.35 * smoothstep(0.55, 1.0, d);
	float inside = smoothstep(1.0, 0.994, d);
	float shade = 0.62 * smoothstep(1.5, 1.0, d);
	COLOR = vec4(mix(vec3(0.0), sky, inside), mix(shade, 1.0, inside));
}

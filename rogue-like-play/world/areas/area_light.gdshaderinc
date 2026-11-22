// The light of a battlefield (AreaGround): what falls on a point of the
// world from the dark of the place (`ambient`), from her own light, which
// goes where she goes (`hero`), from the fires that stand in it (`lamps`,
// flickering) and from the blows that flash in it (`flashes`). The floor,
// the things that stand on it and the things that lie on it all take their
// light from here, so one fire lights them alike.

const int LAMPS = 12;
const int FLASHES = 6;

// The dark of the place: its colour, and in its alpha how much of it there is.
uniform vec4 ambient : source_color = vec4(0.5, 0.56, 0.7, 0.5);
// Her light: where she stands, how far it reaches (world px), its colour
// (alpha: how strong).
uniform vec2 hero = vec2(0.0);
uniform float hero_reach = 340.0;
uniform vec4 hero_colour : source_color = vec4(1.0, 0.94, 0.8, 0.75);
// Each fire: where it burns and how far its light reaches (0: none).
uniform vec3 lamps[LAMPS];
uniform vec4 lamp_colour : source_color = vec4(1.0, 0.62, 0.3, 0.85);
// Each flash: where, how far, how strong now; and its colour.
uniform vec4 flashes[FLASHES];
uniform vec4 flash_colours[FLASHES] : source_color;
uniform float clock = 0.0;
// The whole place brightened (1: as it is; above: an area cleared) and
// reddened (a boss enraged).
uniform float lift = 1.0;
uniform float dread = 0.0;

float light_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float light_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(light_hash(cell), light_hash(cell + vec2(1.0, 0.0)), f.x), mix(light_hash(cell + vec2(0.0, 1.0)), light_hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

// Full at its source, nothing at its reach, easing both ways.
float light_fall(float far, float reach) {
	float near = clamp(1.0 - far / max(reach, 1.0), 0.0, 1.0);
	return near * near * (3.0 - 2.0 * near);
}

// The light on a point of the world.
vec3 light_on(vec2 at) {
	vec3 dark = mix(ambient.rgb, vec3(0.86, 0.34, 0.3), dread * 0.45);
	vec3 lit = dark * ambient.a * lift;
	lit += hero_colour.rgb * hero_colour.a * light_fall(distance(at, hero), hero_reach);
	for (int i = 0; i < LAMPS; i++) {
		if (lamps[i].z <= 0.0) {
			continue;
		}
		float seed = float(i) * 13.7;
		float flick = 0.86 + 0.16 * light_noise(vec2(clock * 3.2 + seed, seed)) + 0.05 * sin(clock * 10.0 + seed);
		lit += lamp_colour.rgb * lamp_colour.a * light_fall(distance(at, lamps[i].xy), lamps[i].z) * flick;
	}
	for (int i = 0; i < FLASHES; i++) {
		if (flashes[i].w <= 0.0) {
			continue;
		}
		lit += flash_colours[i].rgb * flashes[i].w * light_fall(distance(at, flashes[i].xy), flashes[i].z);
	}
	return lit;
}

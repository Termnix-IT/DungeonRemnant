// A battlefield's ground (AreaGround), drawn as one sheet: the paving, the
// wall round it and the dark beyond, in the light of the place
// (area_light.gdshaderinc).
//
// The paving is the theme's stone (`stone`) laid large, so a screen never
// shows it twice the same: its tone drifts over the field, a second layer
// of the same stone lies over it at another size and turn, and damp patches
// darken it. It is kept quieter than what fights on it. Where a thing
// stands (`plan`: the room's cells, bright round pillars) the floor
// darkens toward its foot.
//
// The room's wall is one cell thick at its edge. The far wall (the top) is
// seen from the front, a face of stone (`rock`) standing above the floor
// with a lit coping; the side and near walls are seen from above. Beyond
// them the stone goes off into the dark.
shader_type canvas_item;

#include "res://world/areas/area_light.gdshaderinc"

uniform sampler2D stone : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D plan : filter_linear, repeat_disable;
// The sheet's rectangle in the world (it runs past the room), and the room's size.
uniform vec2 sheet_from = vec2(0.0);
uniform vec2 sheet_size = vec2(1000.0);
uniform vec2 room = vec2(1000.0);
// World px to one repeat of the stone, a wall's thickness and the far
// wall's height above the floor.
uniform float period = 512.0;
uniform float wall = 48.0;
uniform float face = 96.0;
// The floor's own colour cast, and how much mist lies on it.
uniform vec4 tone : source_color = vec4(1.0);
// How much of the paving's own colour and of its lights and darks is kept
// (1: as painted). A floor of strong colour and deep cracks vies with the
// small figures on it; drawn in toward its middle tone it stays the same
// stone and lets them stand out.
uniform vec2 calm = vec2(0.86, 1.0);
uniform vec4 mist : source_color = vec4(0.7, 0.76, 0.86, 0.08);

float fbm(vec2 p) {
	return light_noise(p) * 0.55 + light_noise(p * 2.07 + 13.1) * 0.3 + light_noise(p * 4.3 + 71.0) * 0.15;
}

void fragment() {
	vec2 at = sheet_from + UV * sheet_size;
	// How far inside the room's rectangle (below 0: outside it).
	float inside = min(min(at.x, room.x - at.x), min(at.y, room.y - at.y));
	vec3 col;
	vec3 lit = light_on(at);
	if (inside >= wall) {
		// The paving.
		vec3 base = texture(stone, at / period).rgb;
		vec2 turned = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * at;
		vec3 over = texture(stone, turned / (period * 2.37) + 0.31).rgb;
		base = mix(base, base * over * 2.1, 0.42);
		// Its tone drifts over the field, and damp patches darken it.
		float drift = fbm(at / 620.0);
		base *= 0.86 + 0.34 * drift;
		float damp = smoothstep(0.56, 0.78, fbm(at / 340.0 + 40.0));
		base *= 1.0 - 0.3 * damp;
		// Quieter than what fights on it.
		float grey = dot(base, vec3(0.3, 0.5, 0.2));
		base = mix(vec3(grey), base, calm.x);
		base *= mix(clamp(0.3 / max(grey, 0.03), 0.4, 3.0), 1.0, calm.y);
		base = base * 1.12 * tone.rgb;
		// Darker toward the foot of what stands on it, and of the walls.
		float near_thing = texture(plan, at / room).r;
		float near_wall = 1.0 - smoothstep(wall, wall + 40.0, inside);
		float far_wall = 1.0 - smoothstep(wall, wall + 74.0, at.y);
		base *= 1.0 - 0.52 * smoothstep(0.08, 0.75, near_thing);
		base *= 1.0 - 0.3 * near_wall - 0.32 * far_wall;
		// Mist lying on it, drifting.
		float veil = fbm(at / 300.0 + vec2(clock * 0.035, -clock * 0.02));
		col = base * lit;
		col = mix(col, mist.rgb * (0.45 + 0.55 * dot(lit, vec3(0.34))), smoothstep(0.42, 0.85, veil) * mist.a);
	} else if (at.y < wall && at.y > -face && at.x > 0.0 && at.x < room.x) {
		// The far wall's face: from its coping down to the floor.
		float down = (at.y + face) / (wall + face);
		vec3 base = texture(rock, vec2(at.x, at.y * 1.15) / (period * 0.5)).rgb * tone.rgb;
		base *= mix(0.62, 1.0, smoothstep(0.0, 0.25, down)) * mix(1.0, 0.5, smoothstep(0.72, 1.0, down));
		// A lit coping along its top, a dark course under it.
		float coping = 1.0 - smoothstep(0.0, 0.07, down);
		base = mix(base, base * 2.1 + 0.05, coping);
		base *= 1.0 - 0.45 * (smoothstep(0.07, 0.085, down) - smoothstep(0.1, 0.13, down));
		// It takes the light of what stands before it.
		col = base * light_on(vec2(at.x, wall + 16.0)) * 0.82;
	} else {
		// The side and near walls from above, and the stone going off beyond.
		vec3 base = texture(rock, at / (period * 0.5)).rgb * tone.rgb * 0.5;
		float lip = smoothstep(wall, wall - 5.0, inside) * (1.0 - smoothstep(wall - 5.0, wall - 12.0, inside));
		base *= 1.0 + 1.3 * lip * step(0.0, inside);
		float away = clamp(-inside / 380.0, 0.0, 1.0);
		col = base * lit * mix(0.85, 0.0, away * away * (3.0 - 2.0 * away));
	}
	COLOR = vec4(col, 1.0);
}

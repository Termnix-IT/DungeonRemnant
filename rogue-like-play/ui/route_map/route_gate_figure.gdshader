// What stands in a gate's light (RouteGateView): a foe's painted portrait
// or an event's object. Not turned to, it is a dark shape with the gate's
// light catching its edge from behind (one she has met shows a little of
// itself in that dark: `glimpse`); turned to, the light climbs it from the
// feet and it is seen (`seen` 0 to 1), unless it is a foe she has not met,
// which the page keeps at 0.
//
// A foe is alive (`alive`): its chest swells and its head rides on its
// breath, what hangs from it (a cloak's hem, a blade's tip) sways a hair,
// never its feet, and what glows on it (an eye, a rune) pulses. These are
// small enough to bend the painting without breaking its drawing. Its feet
// stand in the mist of the gate's floor.
shader_type canvas_item;

uniform vec4 shape : source_color = vec4(0.03, 0.028, 0.03, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform float rim_power = 1.0;
uniform float seen = 0.0;
uniform float glimpse = 0.0;
// How far out, in texels, the edge's light is looked for.
uniform float edge_reach = 9.0;
uniform float alive = 0.0;
uniform float clock = 0.0;
// Sets its breath apart from the next gate's.
uniform float own = 0.0;
// A start it gives as its gate is turned to or chosen (1, dying to 0).
uniform float stir = 0.0;

void fragment() {
	// Where its paint is taken from: moved a little by its breath and sway.
	vec2 uv = UV;
	float breath = sin(clock * 1.7 + own);
	float chest = exp(-pow((uv.y - 0.46) / 0.2, 2.0));
	uv.x = 0.5 + (uv.x - 0.5) / (1.0 + 0.013 * alive * breath * chest);
	uv.y += 0.0045 * alive * breath * (1.0 - smoothstep(0.15, 0.58, uv.y));
	float hangs = pow(abs(uv.x - 0.5) * 2.0, 2.0) * sin(3.14159 * clamp(uv.y, 0.0, 1.0));
	uv.x += 0.0065 * alive * sin(clock * 1.25 + uv.y * 5.0 + own * 2.0) * hangs;
	vec4 paint = texture(TEXTURE, uv);
	// The light from behind: strongest where the figure ends.
	float around = 0.0;
	for (int index = 0; index < 8; index++) {
		float turn = float(index) * 0.7853982;
		around += texture(TEXTURE, uv + vec2(cos(turn), sin(turn)) * TEXTURE_PIXEL_SIZE * edge_reach).a;
	}
	float edge = clamp((paint.a - around / 8.0) * 2.6, 0.0, 1.0);
	// What glows on it of itself: bright and strongly coloured paint.
	float most = max(paint.r, max(paint.g, paint.b));
	float least = min(paint.r, min(paint.g, paint.b));
	float glows = smoothstep(0.62, 0.95, most) * smoothstep(0.22, 0.55, most - least);
	// Not turned to: a shape, or one she knows dimly seen in it.
	vec3 dim = paint.rgb * tint.rgb * 0.34 + rim.rgb * 0.05 + paint.rgb * glows * 0.5;
	vec3 unseen = mix(shape.rgb, dim, glimpse) + rim.rgb * edge * 0.55 * rim_power;
	// Lit from the threshold: a little brighter low down, the edge still caught.
	vec3 lit = paint.rgb * tint.rgb * (0.86 + 0.22 * UV.y) * (1.0 + 0.3 * stir) + rim.rgb * edge * (0.22 + 0.4 * stir) * rim_power;
	lit += paint.rgb * glows * (0.22 + 0.2 * sin(clock * 2.3 + own * 3.0)) * alive;
	// The light climbs from the feet; its front is a bright line.
	float front = 1.08 - seen * 1.3;
	float climbed = smoothstep(front - 0.02, front + 0.2, UV.y);
	vec3 col = mix(unseen, lit, climbed);
	float line = smoothstep(front - 0.05, front + 0.03, UV.y) * (1.0 - smoothstep(front + 0.03, front + 0.14, UV.y));
	col += rim.rgb * line * 0.7 * step(0.001, seen) * (1.0 - step(0.999, seen));
	// Its feet stand in the mist of the gate's floor.
	col = mix(col, rim.rgb * 0.5 + vec3(0.08), smoothstep(0.88, 1.0, UV.y) * 0.4 * clamp(rim_power, 0.0, 1.0));
	COLOR = vec4(col, paint.a * COLOR.a);
}

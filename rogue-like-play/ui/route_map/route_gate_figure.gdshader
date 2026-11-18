// What stands in a gate's light (RouteGateView): a foe's painted portrait
// or an event's object. Not turned to, it is a dark shape with the gate's
// light catching its edge from behind; turned to, the light climbs it from
// the feet and it is seen (`seen` 0 to 1), unless it is a foe she has not
// met, which the page keeps at 0.
shader_type canvas_item;

uniform vec4 shape : source_color = vec4(0.03, 0.028, 0.03, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform float rim_power = 1.0;
uniform float seen = 0.0;
// How far out, in texels, the edge's light is looked for.
uniform float edge_reach = 9.0;

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	// The light from behind: strongest where the figure ends.
	float around = 0.0;
	for (int index = 0; index < 8; index++) {
		float turn = float(index) * 0.7853982;
		around += texture(TEXTURE, UV + vec2(cos(turn), sin(turn)) * TEXTURE_PIXEL_SIZE * edge_reach).a;
	}
	float edge = clamp((paint.a - around / 8.0) * 2.6, 0.0, 1.0);
	vec3 unseen = shape.rgb + rim.rgb * edge * 0.55 * rim_power;
	// Lit from the threshold: a little brighter low down, the edge still caught.
	vec3 lit = paint.rgb * tint.rgb * (0.86 + 0.22 * UV.y) + rim.rgb * edge * 0.22 * rim_power;
	// The light climbs from the feet; its front is a bright line.
	float front = 1.08 - seen * 1.3;
	float climbed = smoothstep(front - 0.02, front + 0.2, UV.y);
	vec3 col = mix(unseen, lit, climbed);
	float line = smoothstep(front - 0.05, front + 0.03, UV.y) * (1.0 - smoothstep(front + 0.03, front + 0.14, UV.y));
	col += rim.rgb * line * 0.7 * step(0.001, seen) * (1.0 - step(0.999, seen));
	COLOR = vec4(col, paint.a * COLOR.a);
}

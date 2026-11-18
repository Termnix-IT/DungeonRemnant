// A gate's stone (RouteGateView): dark in the hall's own light, and lit
// round its opening by the light standing in it. `light_map` is the gate's
// light picture (gate_<chapter>_light.png), whose green says how much of the
// opening's light reaches each part of the stone and whose blue how far it
// spills. The light rakes outward across the stone from the opening, so the
// edge of every block and crack that faces the opening catches it and the
// far edge falls into shade (the paint's own light and dark stand for its
// relief); a fire standing at either jamb warms the stone beside it.
shader_type canvas_item;

uniform sampler2D light_map : filter_linear_mipmap, repeat_disable;
uniform vec4 colour : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform float power = 1.0;
// The hall's own light on the stone, and its hue.
uniform float ambient = 0.4;
uniform vec4 ambient_tone : source_color = vec4(0.62, 0.66, 0.8, 1.0);
// The middle of the opening (UV), which its light rakes out from.
uniform vec2 heart = vec2(0.5, 0.7);
// The fires at its jambs: their strength and colour.
uniform float fire = 0.0;
uniform vec4 fire_colour : source_color = vec4(1.0, 0.56, 0.2, 1.0);

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	vec4 falls = texture(light_map, UV);
	float reach = falls.g;
	// A little more of the hall's light on its upper stones than at its foot.
	float fall = mix(1.0, 0.72, UV.y);
	// The stone's relief, read from its paint: which way it rises here.
	vec2 px = TEXTURE_PIXEL_SIZE * 1.6;
	vec3 weigh = vec3(0.3, 0.5, 0.2);
	vec2 slope = vec2(
		dot(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb - texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb, weigh),
		dot(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb - texture(TEXTURE, UV - vec2(0.0, px.y)).rgb, weigh));
	vec2 outward = normalize((UV - heart) * vec2(1.0, 1.34) + vec2(0.0001));
	float rake = clamp(-dot(slope, outward) * 7.0, -1.0, 1.0);
	float spill = max(reach, falls.b * 0.45);
	vec3 col = paint.rgb * (ambient_tone.rgb * ambient * fall + colour.rgb * reach * power * 1.7);
	col += colour.rgb * reach * reach * reach * power * 0.3;
	col += paint.rgb * colour.rgb * spill * power * rake * 0.9;
	// The fires' warmth: on the lower stones, strongest at the outer sides.
	float beside = smoothstep(0.1, 0.5, abs(UV.x - 0.5)) * exp(-pow((UV.y - 0.72) / 0.26, 2.0));
	col += paint.rgb * fire_colour.rgb * fire * beside * (0.75 + 0.5 * clamp(-slope.y * 6.0, -1.0, 1.0));
	COLOR = vec4(col, paint.a * COLOR.a);
}

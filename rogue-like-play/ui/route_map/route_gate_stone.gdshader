// A gate's stone (RouteGateView): dark in the hall's own light, and lit
// round its opening by the light standing in it. `light_map` is the gate's
// light picture (gate_<chapter>_light.png), whose green says how much of the
// opening's light reaches each part of the stone.
shader_type canvas_item;

uniform sampler2D light_map : filter_linear_mipmap, repeat_disable;
uniform vec4 colour : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform float power = 1.0;
// The hall's own light on the stone, and its hue.
uniform float ambient = 0.4;
uniform vec4 ambient_tone : source_color = vec4(0.62, 0.66, 0.8, 1.0);

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	float reach = texture(light_map, UV).g;
	// A little more of the hall's light on its upper stones than at its foot.
	float fall = mix(1.0, 0.72, UV.y);
	vec3 col = paint.rgb * (ambient_tone.rgb * ambient * fall + colour.rgb * reach * power * 1.7);
	col += colour.rgb * reach * reach * reach * power * 0.3;
	COLOR = vec4(col, paint.a * COLOR.a);
}

// A gate's portcullis (RouteGateView): the iron grille that comes down in
// the gates not chosen. Drawn on the gate's light picture, whose red is the
// opening, so the grille shows only inside it; `bars` is the grille's own
// picture, as wide as the opening, and `drop` how far down it has come (0:
// up out of sight, 1: its points on the threshold).
shader_type canvas_item;

uniform sampler2D bars : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 opening = vec4(0.2, 0.2, 0.6, 0.8);
// The opening's height over its width, and the grille picture's.
uniform float opening_tall = 1.5;
uniform float bars_tall = 1.1;
uniform float drop = 0.0;
uniform vec4 colour : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform float power = 0.2;

void fragment() {
	float hole = texture(TEXTURE, UV).r;
	vec2 q = (UV - opening.xy) / opening.zw;
	// How far above the grille's points this place is, in grille pictures.
	float above = (drop - q.y) * opening_tall / bars_tall;
	vec4 iron = texture(bars, vec2(q.x, clamp(1.0 - above, 0.02, 1.0)));
	float there = step(0.0, above) * step(0.0, q.x) * step(q.x, 1.0);
	// Dark iron against what light is left behind it.
	vec3 col = iron.rgb * (0.5 + 0.5 * power) + colour.rgb * power * 0.1;
	COLOR = vec4(col, iron.a * hole * there * COLOR.a);
}

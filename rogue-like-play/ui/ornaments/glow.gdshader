// A soft light: the rect's colour at its centre fading smoothly to nothing
// at its edge (an ellipse in a rect that is not square), and breathing when
// `breath` is above 0: its strength rises and falls by that share over
// `breath_time` seconds. The fall-off is the cubic of a two-stop Godot
// Gradient, so it matches the gradient discs it replaced.
shader_type canvas_item;

instance uniform vec4 tint = vec4(1.0);
instance uniform float breath = 0.0;
instance uniform float breath_time = 3.2;

void fragment() {
	float t = clamp(distance(UV, vec2(0.5)) / 0.5, 0.0, 1.0);
	float fall = 0.5 * t + 1.5 * t * t - t * t * t;
	float pulse = 1.0 + breath * sin(TIME * TAU / max(breath_time, 0.01));
	COLOR = vec4(tint.rgb, tint.a * pulse * (1.0 - fall));
}

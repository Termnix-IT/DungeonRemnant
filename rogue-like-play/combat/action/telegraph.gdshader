// A foe's warning on the floor (Telegraph), drawn over its plain shape: the
// danger gathers from the attacker outward. The fill is faint near the
// attacker and deeper toward the blow's edge, a bright front runs out as
// the wind-up fills (`progress`), bands of light follow it faster and
// faster, and the whole throbs as the blow nears. A heavier blow (`weight`:
// an elite's 1, a boss's 2) burns deeper. The shape and its timing are the
// Telegraph's; this only lights what it draws.
shader_type canvas_item;

// How far the blow reaches (world px), and how far along its wind-up is.
uniform float reach = 100.0;
uniform float progress = 0.0;
uniform float weight = 0.0;
// 1 once the blow has landed (the flash).
uniform float struck = 0.0;
// A line's way (a unit vector), or nothing for shapes measured from the middle.
uniform vec2 along = vec2(0.0);
uniform float clock = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	// How far out this point is, 0 at the attacker and 1 at the blow's edge.
	float out_share = length(along) > 0.5 ? dot(local, along) / max(reach, 1.0) : length(local) / max(reach, 1.0);
	out_share = clamp(out_share, 0.0, 1.0);
	vec4 base = COLOR;
	// Deeper toward its edge.
	float body = mix(0.55, 1.25, out_share * out_share);
	// The front of the wind-up, and bands running out behind it.
	float front = smoothstep(0.1, 0.0, abs(out_share - progress)) * step(out_share, progress + 0.02);
	float pace = mix(1.2, 3.4, progress);
	float bands = smoothstep(0.75, 1.0, sin((out_share * (5.0 + weight * 2.0) - clock * pace) * 6.2832) * 0.5 + 0.5) * step(out_share, progress);
	// The whole throbs as the blow nears.
	float throb = 1.0 + (0.1 + 0.08 * weight) * sin(clock * mix(6.0, 16.0, progress)) * smoothstep(0.4, 1.0, progress);
	float heat = 1.0 + 0.25 * weight;
	vec3 col = base.rgb * heat + vec3(1.0, 0.72, 0.5) * (front * 0.55 + bands * 0.16);
	float alpha = base.a * body * throb * heat + front * 0.3 + bands * 0.07;
	COLOR = vec4(col, mix(alpha, base.a, struck));
}

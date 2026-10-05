shader_type canvas_item;

// Fades a picture out towards all four edges, so it melts into what is
// behind it instead of reading as a framed rectangle.
uniform float reach = 0.18;

void fragment() {
	vec2 edge = min(UV, 1.0 - UV);
	float fade = smoothstep(0.0, reach, edge.x) * smoothstep(0.0, reach, edge.y);
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.a *= fade;
}

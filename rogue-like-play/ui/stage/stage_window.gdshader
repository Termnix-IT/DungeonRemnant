shader_type canvas_item;

// The window a FightStage is seen through: the fight's picture with soft
// rounded corners and a rim that falls off into dark, so it sits in a page
// as a view into a place and not as a pasted rectangle.

// The corners' radius and the softness of the edge, as shares of the
// window's height; and how dark the rim falls.
uniform float corner = 0.05;
uniform float soft = 0.012;
uniform float dusk = 0.55;

void fragment() {
	vec4 seen = texture(TEXTURE, UV);
	vec2 px = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = (UV - 0.5) * px;
	float radius = corner * px.y;
	vec2 d = abs(p) - (px * 0.5 - radius);
	float far = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
	float inside = 1.0 - smoothstep(-soft * px.y, 0.0, far);
	vec2 q = abs(UV - 0.5) * 2.0;
	float rim = smoothstep(0.6, 1.1, length(q * vec2(0.92, 1.0)));
	float fade = COLOR.a / max(seen.a, 0.001);
	COLOR = vec4(seen.rgb * (1.0 - dusk * rim), inside * clamp(fade, 0.0, 1.0));
}

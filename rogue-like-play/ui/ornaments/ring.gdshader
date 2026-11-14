// A ring round the rect's centre: `radius` and `width` in pixels, drawn
// clockwise from the top over `sweep` of its round (1 is whole), with a
// faint disc `halo_reach` pixels past it at `halo` of the colour's strength.
// `extent` is the rect's size in pixels, set by Ornament.
shader_type canvas_item;

instance uniform vec4 tint = vec4(1.0);
instance uniform vec2 extent = vec2(100.0);
instance uniform float radius = 40.0;
instance uniform float width = 2.0;
instance uniform float sweep = 1.0;
instance uniform float halo = 0.0;
instance uniform float halo_reach = 8.0;

void fragment() {
	vec2 p = (UV - 0.5) * extent;
	float d = length(p);
	float aa = max(fwidth(d), 0.0001);
	float band = 1.0 - smoothstep(width * 0.5 - aa * 0.5, width * 0.5 + aa * 0.5, abs(d - radius));
	float share = atan(p.x, -p.y) / TAU;
	share = share < 0.0 ? share + 1.0 : share;
	float arc = sweep >= 1.0 ? 1.0 : step(share, sweep);
	float ring = band * arc * tint.a;
	float disc = halo * (1.0 - smoothstep(radius + halo_reach - aa, radius + halo_reach + aa, d));
	COLOR = vec4(tint.rgb, 1.0 - (1.0 - ring) * (1.0 - disc));
}

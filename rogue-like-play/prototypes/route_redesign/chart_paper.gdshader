// The expedition chart's sheet (ProtoChart): one sheet of old paper lying on
// a dark desk, browner at its edges, lit warm from one side, with the two
// creases it was folded along. `sheet` is its corners (from.xy, to.zw) in the
// view of `extent` px. The painted grain (art/ui/grimoire/paper.png) says
// where between the dark and light paper each point lies.
shader_type canvas_item;

uniform vec2 extent = vec2(1600.0, 900.0);
uniform vec4 sheet = vec4(20.0, 16.0, 1580.0, 884.0);
uniform vec4 page_dark : source_color = vec4(0.80, 0.72, 0.55, 1.0);
uniform vec4 page_light : source_color = vec4(0.95, 0.90, 0.77, 1.0);
uniform vec4 desk : source_color = vec4(0.045, 0.035, 0.03, 1.0);
uniform vec2 light = vec2(560.0, 360.0);
uniform sampler2D paper_grain : filter_linear_mipmap, repeat_enable, hint_default_white;

float box(vec2 p, vec2 a, vec2 b) {
	vec2 d = max(a - p, p - b);
	return max(d.x, d.y);
}

void fragment() {
	vec2 p = UV * extent;
	float edge = box(p, sheet.xy, sheet.zw);
	vec3 col = desk.rgb * (0.55 + 0.45 * smoothstep(0.0, 26.0, edge));
	if (edge < 0.0) {
		vec2 size = sheet.zw - sheet.xy;
		float grain = texture(paper_grain, (p - sheet.xy) / size).r;
		vec3 paper = mix(page_dark.rgb, page_light.rgb, mix(0.55, grain, 0.6));
		// Browner toward the edges, and warm where the lamp stands.
		paper *= 0.80 + 0.20 * smoothstep(0.0, 170.0, -edge);
		paper *= 0.90 + 0.14 * (1.0 - smoothstep(180.0, 1200.0, distance(p, light)));
		// The two creases: a dark line with the light catching one side.
		for (int index = 1; index <= 2; index++) {
			float fold = sheet.x + size.x * float(index) / 3.0 + (index == 1 ? 14.0 : -22.0);
			float off = p.x - fold;
			paper *= 1.0 - 0.07 * smoothstep(2.0, 0.0, abs(off));
			paper *= 1.0 + 0.035 * smoothstep(16.0, 2.0, off) * step(0.0, off);
			paper *= 1.0 - 0.03 * smoothstep(-22.0, -2.0, off) * step(off, 0.0);
		}
		col = paper;
	}
	COLOR = vec4(col, 1.0);
}

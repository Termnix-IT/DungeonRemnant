// The bestiary's plate (HubCodex): one sheet of parchment, browner at its
// edges, with a soft shadow on whatever lies behind. Drawn in the page's
// design space (1520x686): `origin` and `zoom` place that space in the rect,
// whose size in pixels is `extent`. The colours are the theme's (Grimoire);
// the painted grain (art/ui/grimoire/paper.png) only says where between the
// theme's dark and light each point lies, as in the status page's book.
shader_type canvas_item;

uniform vec2 extent = vec2(1520.0, 686.0);
uniform vec2 origin = vec2(0.0);
uniform float zoom = 1.0;
uniform vec4 page_dark : source_color = vec4(0.84, 0.77, 0.62, 1.0);
uniform vec4 page_light : source_color = vec4(0.94, 0.89, 0.78, 1.0);
uniform sampler2D paper_grain : filter_linear_mipmap, repeat_disable, hint_default_white;

const vec2 SHEET_FROM = vec2(40.0, 4.0);
const vec2 SHEET_TO = vec2(1480.0, 560.0);

float box(vec2 p, vec2 a, vec2 b) {
	vec2 d = max(a - p, p - b);
	return max(d.x, d.y);
}

void fragment() {
	vec2 p = (UV * extent - origin) / zoom;
	float sheet = box(p, SHEET_FROM, SHEET_TO);
	float grain = texture(paper_grain, clamp((p - SHEET_FROM) / (SHEET_TO - SHEET_FROM), 0.0, 1.0)).r;
	vec4 col = vec4(0.0, 0.0, 0.0, 0.6 * smoothstep(60.0, 0.0, sheet) + 0.18);
	if (sheet < 0.0) {
		vec3 paper = mix(page_dark.rgb, page_light.rgb, grain);
		paper *= 0.90 + 0.10 * smoothstep(0.0, 90.0, -sheet);
		col = vec4(paper, 1.0);
	}
	COLOR = col;
}

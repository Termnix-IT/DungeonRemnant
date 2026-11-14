// The status page's open book (HubStatus): a leather cover and two pages of
// parchment, browner at their edges and shaded into the gutter, with a soft
// shadow on whatever lies behind. Drawn in the page's design space
// (1520x686): `origin` and `zoom` place that space in the rect, whose size
// in pixels is `extent`. The colours come from the theme (Grimoire); the
// painted grain of the paper and the leather (art/ui/grimoire/, made by
// tools/build_grimoire_art.py) only says where between the theme's dark and
// light each point lies, so the words' contrast is the theme's to keep.
shader_type canvas_item;

uniform vec2 extent = vec2(1520.0, 686.0);
uniform vec2 origin = vec2(0.0);
uniform float zoom = 1.0;
uniform vec4 page_dark : source_color = vec4(0.84, 0.77, 0.62, 1.0);
uniform vec4 page_light : source_color = vec4(0.94, 0.89, 0.78, 1.0);
uniform vec4 cover_dark : source_color = vec4(0.20, 0.07, 0.06, 1.0);
uniform vec4 cover_light : source_color = vec4(0.30, 0.11, 0.08, 1.0);
uniform sampler2D paper_grain : filter_linear_mipmap, repeat_disable, hint_default_white;
uniform sampler2D leather_grain : filter_linear_mipmap, repeat_enable, hint_default_white;

// The leather's grain repeats over this many design pixels, mirrored at each
// repeat so that no seam shows.
const vec2 LEATHER_TILE = vec2(540.0, 360.0);

const vec2 COVER_FROM = vec2(46.0, 2.0);
const vec2 COVER_TO = vec2(1414.0, 684.0);
const vec2 PAGE_FROM = vec2(60.0, 14.0);
const vec2 PAGE_TO = vec2(1400.0, 672.0);
const float GUTTER = 730.0;

float box(vec2 p, vec2 a, vec2 b) {
	vec2 d = max(a - p, p - b);
	return max(d.x, d.y);
}

void fragment() {
	vec2 p = (UV * extent - origin) / zoom;
	float cover = box(p, COVER_FROM, COVER_TO);
	// Sampled outside the branches below, so the mipmaps' gradients stay whole.
	vec2 turn = abs(fract(p / LEATHER_TILE * 0.5) * 2.0 - 1.0);
	float hide_grain = texture(leather_grain, turn).r;
	float grain = texture(paper_grain, clamp((p - PAGE_FROM) / (PAGE_TO - PAGE_FROM), 0.0, 1.0)).r;
	// The book's shadow on what lies behind it.
	vec4 col = vec4(0.0, 0.0, 0.0, 0.62 * smoothstep(70.0, 0.0, cover) + 0.18);
	if (cover < 0.0) {
		vec3 hide = mix(cover_dark.rgb, cover_light.rgb, hide_grain);
		hide *= 0.75 + 0.25 * smoothstep(0.0, 10.0, -cover);
		col = vec4(hide, 1.0);
	}
	float page = box(p, PAGE_FROM, PAGE_TO);
	if (page < 0.0) {
		vec3 paper = mix(page_dark.rgb, page_light.rgb, grain);
		paper *= 0.90 + 0.10 * smoothstep(0.0, 70.0, -page);
		float gutter = abs(p.x - GUTTER);
		paper *= 0.60 + 0.40 * smoothstep(0.0, 80.0, gutter);
		paper += vec3(0.04, 0.03, 0.015) * smoothstep(220.0, 60.0, gutter) * smoothstep(0.0, 60.0, gutter);
		col = vec4(paper, 1.0);
	}
	COLOR = col;
}

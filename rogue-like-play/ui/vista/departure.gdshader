// Setting out (SceneTransition.play_departure): the chapter's painting as
// the departure showed it, gone into. The view draws back a hair and then
// goes in toward the painting's way in (`way`: its gate, stair or door),
// which comes to the screen's middle as its light swells; the picture
// streaks toward it; and the dark closes on that light from the screen's
// edges (`close`). The first frame is the departure's own: the same part of
// the painting (`window`) under the same dark falls (`falls`, which leave
// with the page's words).
shader_type canvas_item;

const int TAPS = 7;

uniform sampler2D place : source_color, filter_linear_mipmap, repeat_disable;
// The part of the painting on the screen as it set out (x, y, width, height).
uniform vec4 window = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 way = vec2(0.5, 0.45);
uniform vec4 way_light : source_color = vec4(1.0, 0.74, 0.4, 1.0);
uniform vec4 shade : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 night : source_color = vec4(0.01, 0.012, 0.016, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float falls = 1.0;
// How far in (0 to 1; a little under 0 as it draws back first), and how
// close the view is at 1.
uniform float push = 0.0;
uniform float reach = 2.7;
uniform float close = 0.0;
// The screen's width over its height.
uniform float aspect = 1.777;

void fragment() {
	// Where the way in is on the screen at rest, and where it has come to.
	vec2 rest = (way - window.xy) / window.zw;
	float gone = clamp(push, 0.0, 1.0);
	vec2 held = mix(rest, vec2(0.5, 0.5), gone * gone * (3.0 - 2.0 * gone) * 0.9);
	float zoom = 1.0 + (reach - 1.0) * push;
	// This pixel's place on the screen as it was at rest.
	vec2 was = (UV - held) / zoom + rest;
	// The picture streaks toward the way in as she goes.
	float streak = gone * gone * 0.2;
	vec3 col = vec3(0.0);
	for (int i = 0; i < TAPS; i++) {
		vec2 q = mix(was, rest, streak * float(i) / float(TAPS - 1));
		col += texture(place, clamp(window.xy + q * window.zw, vec2(0.001), vec2(0.999))).rgb;
	}
	col = col / float(TAPS) * tint.rgb;
	// The departure's dark falls, leaving with its words.
	col = mix(col, shade.rgb, smoothstep(0.4, 1.0, was.y) * 0.95 * falls);
	col = mix(col, shade.rgb, clamp(1.0 - was.x / 0.52, 0.0, 1.0) * 0.55 * falls);
	col = mix(col, shade.rgb, clamp(1.0 - was.y / 0.2, 0.0, 1.0) * 0.72 * falls);
	// The way's light, swelling to meet her.
	vec2 off = (UV - held) * vec2(aspect, 1.0);
	float far = length(off);
	float glow = exp(-far * far / (0.012 + 0.34 * gone * gone));
	col *= 1.0 + glow * gone * 0.7;
	col += way_light.rgb * glow * (0.05 + 0.85 * gone * gone);
	// The dark closing on that light from the screen's edges.
	float seen_to = mix(1.7, -0.25, close);
	float dark = smoothstep(seen_to, seen_to + 0.34, far);
	dark = max(dark, smoothstep(0.86, 1.0, close));
	col = mix(col, night.rgb, dark * step(0.001, close));
	COLOR = vec4(col, 1.0);
}

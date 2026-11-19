// A chapter's small view on the departure (HubSortie): the chapter's
// painting seen through a stone window (view_frame.png, this item's
// texture; `hole`: view_hole.png, bright where the window opens). The
// painting keeps its own light (`bright`: full for the chapter turned to,
// low for the others, lower for a sealed one); the stone is lit from within
// by the chosen view (`glow`).
shader_type canvas_item;

uniform sampler2D place : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D hole : filter_linear, repeat_disable;
// The part of the painting behind the whole frame (x, y, width, height).
uniform vec4 window = vec4(0.0, 0.0, 1.0, 1.0);
uniform float bright = 1.0;
uniform float glow = 0.0;
uniform vec4 glow_colour : source_color = vec4(1.0, 0.82, 0.48, 1.0);

// The item's own colour (its fade with the page): in fragment() COLOR
// already carries the frame's alpha, which is nothing where the window opens.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 frame = texture(TEXTURE, UV);
	float open = texture(hole, UV).r;
	vec3 seen = texture(place, window.xy + UV * window.zw).rgb * bright;
	// The stone's own shadow lies on the edge of what is seen through it.
	seen *= mix(0.45, 1.0, smoothstep(0.55, 1.0, open));
	seen += glow_colour.rgb * glow * 0.05;
	vec3 stone = frame.rgb * (0.7 + 0.55 * glow) + glow_colour.rgb * glow * 0.1;
	COLOR = vec4(mix(seen, stone, frame.a), max(frame.a, open)) * tint;
}

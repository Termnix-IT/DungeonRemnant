shader_type canvas_item;

// The dark an area is entered out of and left into (BattleArea): all of the
// view is dark but a round of it about her, which widens as she arrives
// until the whole view is clear, and closes on her as the area is left.
// Drawn over the world and under the HUD.

// Where she stands on the screen (0 to 1 both ways) and the screen's width
// over its height.
uniform vec2 at = vec2(0.5);
uniform float aspect = 1.7778;
// How far it has opened: 0, all dark; 1, all clear.
uniform float open = 1.0;
uniform vec4 dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 from_her = UV - at;
	from_her.x *= aspect;
	// At 1 the round reaches past the furthest corner wherever she stands.
	float reach = open * 2.1;
	float edge = 0.1 + 0.3 * open;
	float shade = smoothstep(reach - edge, reach, length(from_her));
	COLOR = vec4(dark.rgb, dark.a * shade);
}

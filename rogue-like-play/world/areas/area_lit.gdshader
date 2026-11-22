// A thing on a battlefield that is not the floor (AreaGround): something
// that stands on it (a pillar's prop, a tree: `upright`, lit as its foot is
// lit, the node's origin) or lies on it (rubble, bones: lit point by
// point). It takes the place's light (area_light.gdshaderinc), so it is
// dark where the floor round it is dark and warm where a fire is near.
shader_type canvas_item;

#include "res://world/areas/area_light.gdshaderinc"

uniform float upright = 1.0;
// A colour cast over the picture (a set of props used in another place).
uniform vec4 tone : source_color = vec4(1.0);
// How much of the light it takes (below 1: it keeps some of its own, so it
// never sinks wholly into the dark).
uniform float held = 0.78;

varying vec2 foot;
varying vec2 spot;
varying vec4 tint;

void vertex() {
	foot = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	spot = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	vec4 px = texture(TEXTURE, UV);
	vec3 lit = light_on(mix(spot, foot, upright));
	vec3 col = px.rgb * tone.rgb * mix(vec3(1.0), lit, held);
	COLOR = vec4(col, px.a) * tint;
}

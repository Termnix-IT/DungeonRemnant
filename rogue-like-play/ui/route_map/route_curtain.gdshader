// The dark she walks into as she goes through a gate (RouteMapView), over
// everything. It does not fall over the screen all at once: it comes in
// from the edges and closes on a point (the gate's far light), and lifts
// the same way, opening from the screen's middle on the area she has come
// into. How far it has closed is the rect's own alpha (0: open, 1: shut).
shader_type canvas_item;

// The point it closes on (a share of the rect), and the rect's size (px).
uniform vec2 centre = vec2(0.5, 0.5);
uniform vec2 extent = vec2(1600.0, 900.0);

void fragment() {
	float closed = COLOR.a;
	// How far from the point, in heights of the screen.
	float far = length((UV - centre) * extent / max(extent.y, 1.0));
	float open_to = mix(2.1, -0.3, closed);
	float dark = smoothstep(open_to, open_to + 0.42, far);
	dark = max(dark, smoothstep(0.8, 1.0, closed));
	COLOR = vec4(COLOR.rgb, dark * step(0.001, closed));
}

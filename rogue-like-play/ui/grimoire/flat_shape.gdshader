// A picture's shape alone, in one flat colour: a foe not met on the
// bestiary's plate. Tinting the picture instead would let its painted
// details through, which is more than a foe not met may show.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}

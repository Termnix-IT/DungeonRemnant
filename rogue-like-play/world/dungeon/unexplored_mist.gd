extends Node2D

# Slow, faint mist under the terrain, so the unknown beyond the explored map
# reads as dark air rather than an empty black screen. Terrain and remembered
# tiles are opaque and cover it, so it only shows where nothing is known yet.
# The pattern is noise over world position, independent of the layout, so it
# never hints at unexplored rooms, and it consumes no gameplay RNG.
const TILE_SIZE := 48.0
# Far enough past the map edge that the camera never shows the mist's border.
const MARGIN_TILES := 24
# Terrain themes share dungeon.gd's order; the forest has its own green.
const THEME_TINTS: Array[Color] = [Color(0.2, 0.24, 0.3), Color(0.16, 0.24, 0.18), Color(0.3, 0.15, 0.09), Color(0.21, 0.15, 0.31)]
const FOREST_TINT := Color(0.12, 0.23, 0.14)
const SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color;
uniform float strength = 0.5;
varying vec2 world;

void vertex() {
	world = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += amplitude * noise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 p = world / 220.0;
	float t = TIME * 0.035;
	float drift = fbm(p + vec2(t, t * 0.4));
	float wisp = fbm(p * 1.7 - vec2(t * 0.6, -t * 0.3) + drift);
	COLOR = vec4(tint.rgb, tint.a * smoothstep(0.35, 0.85, wisp) * strength);
}
"""

var area := Rect2()
var tint := THEME_TINTS[0]


func _ready() -> void:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = Shader.new()
	shader_material.shader.code = SHADER
	material = shader_material
	_apply_tint()


func refresh(grid_size: Vector2i, forest: bool, theme_index: int) -> void:
	area = Rect2(Vector2.ZERO, Vector2(grid_size) * TILE_SIZE).grow(MARGIN_TILES * TILE_SIZE)
	tint = FOREST_TINT if forest else THEME_TINTS[clampi(theme_index, 0, THEME_TINTS.size() - 1)]
	_apply_tint()
	queue_redraw()


func _apply_tint() -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(&"tint", tint)


func _draw() -> void:
	if area.has_area():
		draw_rect(area, Color.WHITE)

class_name DangerVignette
extends CanvasLayer

# Low-HP warning: a red edge that breathes faster as HP falls. It sits above
# the dungeon and below the HUD panels, and never blocks input.
const THRESHOLD := 0.3
const MIN_STRENGTH := 0.4
const EASE_SPEED := 4.0
const SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color;
uniform float strength = 0.0;
uniform float pace = 2.0;

void fragment() {
	vec2 from_center = (UV - 0.5) * vec2(1.6, 1.0);
	float edge = smoothstep(0.38, 0.95, length(from_center));
	float breath = 0.78 + 0.22 * sin(TIME * pace);
	COLOR = vec4(tint.rgb, tint.a * edge * strength * breath);
}
"""

var rect: ColorRect
var target := 0.0
var strength := 0.0


func _ready() -> void:
	layer = 4
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.theme = preload("res://ui/theme/dungeon_theme.tres")
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SHADER
	var tint := rect.get_theme_color(&"font_color", &"HpCaption")
	tint.a = 0.55
	material.set_shader_parameter(&"tint", tint)
	rect.material = material
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply()


func set_health(hp: int, max_hp: int) -> void:
	var ratio := clampf(float(hp) / maxf(max_hp, 1.0), 0.0, 1.0)
	target = 0.0 if ratio > THRESHOLD else lerpf(MIN_STRENGTH, 1.0, 1.0 - ratio / THRESHOLD)
	if rect != null:
		(rect.material as ShaderMaterial).set_shader_parameter(&"pace", lerpf(2.0, 5.0, target))


func clear() -> void:
	target = 0.0
	strength = 0.0
	_apply()


func _process(delta: float) -> void:
	if is_equal_approx(strength, target):
		return
	strength = move_toward(strength, target, delta * EASE_SPEED)
	_apply()


func _apply() -> void:
	if rect == null:
		return
	rect.visible = strength > 0.001
	(rect.material as ShaderMaterial).set_shader_parameter(&"strength", strength)

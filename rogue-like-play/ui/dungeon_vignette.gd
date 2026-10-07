class_name DungeonVignette
extends CanvasLayer

# A steady dark rim around the dungeon view, so the lit room reads as the
# centre of a torchlit space instead of a board on black. It sits under the
# danger warning and the HUD and never blocks input.
# On arrival the dark first closes in on the player, then lifts outward
# (closing 1 -> 0), as if the lamp catches and the room opens up.
const SHADER := """
shader_type canvas_item;
uniform float strength = 0.55;
uniform float closing = 0.0;

void fragment() {
	vec2 from_center = (UV - 0.5) * vec2(1.6, 1.0);
	float edge = smoothstep(mix(0.32, 0.03, closing), mix(0.92, 0.4, closing), length(from_center));
	COLOR = vec4(0.0, 0.0, 0.0, edge * mix(strength, 0.97, closing));
}
"""
const BLOOM_TIME := 0.9

var rect: ColorRect
var _bloom: Tween


func _ready() -> void:
	layer = 3
	rect = ColorRect.new()
	rect.name = "Rim"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SHADER
	rect.material = material
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# Presentation only: input and turns never wait for it.
func bloom(delay: float = 0.0) -> void:
	var material := rect.material as ShaderMaterial
	if _bloom != null:
		_bloom.kill()
	material.set_shader_parameter("closing", 1.0)
	_bloom = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bloom.tween_interval(delay)
	_bloom.tween_method(func(value: float): material.set_shader_parameter("closing", value), 1.0, 0.0, BLOOM_TIME)

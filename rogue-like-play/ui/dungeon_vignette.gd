class_name DungeonVignette
extends CanvasLayer

# A steady dark rim around the dungeon view, so the lit room reads as the
# centre of a torchlit space instead of a board on black. It sits under the
# danger warning and the HUD and never blocks input.
const SHADER := """
shader_type canvas_item;
uniform float strength = 0.55;

void fragment() {
	vec2 from_center = (UV - 0.5) * vec2(1.6, 1.0);
	float edge = smoothstep(0.32, 0.92, length(from_center));
	COLOR = vec4(0.0, 0.0, 0.0, edge * strength);
}
"""

var rect: ColorRect


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

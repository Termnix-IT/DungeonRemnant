class_name Ornament
extends ColorRect

# One drawn ornament, painted by a shader over its rect: a soft light that
# can breathe (GLOW), a ring that can run round once and leave a faint halo
# (RING), or a hairline fading at both ends (RAIL). Each kind shares one
# material; what differs between two ornaments of a kind (its colour, its
# size, how far a ring has run) is set on the node as an instance uniform,
# so a screen holds as many as it likes at the cost of one shader each.
#
# A component lays its ornaments between what it draws itself and what it
# draws over them (see LoadoutSlot): an ornament is a child, so it is drawn
# after its parent's own _draw and before the children that follow it.
#
# Colours go to the shader as Vector4, never as Color: under the Forward+
# renderer a Color set as an instance uniform is turned to linear light and
# comes out darker than under Compatibility (found in the theme's tokens
# trial, 2026-11). set() does that, so use it rather than
# set_instance_shader_parameter().

enum Kind { GLOW, RING, RAIL }

const SHADERS := {
	Kind.GLOW: preload("res://ui/ornaments/glow.gdshader"),
	Kind.RING: preload("res://ui/ornaments/ring.gdshader"),
	Kind.RAIL: preload("res://ui/ornaments/rail.gdshader"),
}

static var _materials: Dictionary = {}

var kind := Kind.GLOW


func _init(of: Kind = Kind.GLOW) -> void:
	kind = of
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	if not _materials.has(kind):
		var shared := ShaderMaterial.new()
		shared.shader = SHADERS[kind]
		_materials[kind] = shared
	material = _materials[kind]
	resized.connect(_fit)


func _ready() -> void:
	_fit()


# Sets one of the shader's values on this ornament alone.
func set_value(key: StringName, value: Variant) -> void:
	if value is Color:
		var colour := value as Color
		value = Vector4(colour.r, colour.g, colour.b, colour.a)
	set_instance_shader_parameter(key, value)


# Places a round ornament (GLOW, RING) on `centre`, `reach` pixels each way.
func round_on(centre: Vector2, reach: float) -> void:
	position = centre - Vector2.ONE * reach
	size = Vector2.ONE * reach * 2.0


func _fit() -> void:
	if kind != Kind.GLOW:
		set_instance_shader_parameter(&"extent", size)

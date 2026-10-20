class_name DamageInfo
extends RefCounted

# One blow as it arrives: how hard, from where, and how far it pushes.

var amount := 0.0
# The way the blow travels (unit), for the push and the flinch.
var direction := Vector2.ZERO
var knockback := 0.0
var hit_stop := 0.0
var element: StringName
var source: Node


static func make(amount_value: float, direction_value: Vector2, knockback_value: float = 0.0, source_node: Node = null) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount_value
	info.direction = direction_value.normalized()
	info.knockback = knockback_value
	info.source = source_node
	return info

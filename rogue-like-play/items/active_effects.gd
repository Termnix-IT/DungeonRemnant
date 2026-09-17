class_name ActiveEffects
extends RefCounted

const MAX_BUFFS := 5
var effects: Dictionary = {}


func can_use(item: ItemData) -> bool:
	if item.effect_id.is_empty() or effects.has(item.effect_id):
		return false
	return item.effect_turns == 0 or buff_count() < MAX_BUFFS


func buff_count() -> int:
	var count := 0
	for effect: Dictionary in effects.values():
		if effect.remaining > 0:
			count += 1
	return count


func add(item: ItemData) -> bool:
	if not can_use(item):
		return false
	# The use action itself must not shorten the advertised duration.
	effects[item.effect_id] = {"item": item, "remaining": item.effect_turns + 1 if item.effect_turns > 0 else 0}
	return true


func amount(id: StringName) -> int:
	return effects[id].item.effect_amount if effects.has(id) else 0


func tick() -> void:
	for id: StringName in effects.keys():
		if effects[id].remaining > 0:
			effects[id].remaining -= 1
			if effects[id].remaining == 0:
				effects.erase(id)


func change_floor() -> void:
	for id: StringName in effects.keys():
		if effects[id].remaining == 0:
			effects.erase(id)


func summary() -> String:
	var labels: PackedStringArray = []
	for effect: Dictionary in effects.values():
		labels.append("%s：%s" % [effect.item.display_name, str(effect.remaining) if effect.remaining > 0 else "この階"])
	return " / ".join(labels)

class_name SaveCodec
extends RefCounted

const VERSION := 1
const MAX_GOLD := 1000000000


static func encode(state: RunCarryover) -> Dictionary:
	var equipment: Array = []
	for item in state.equipment.slots:
		equipment.append(String(item.id) if item != null else null)
	return {"version": VERSION, "gold": state.gold, "hp_upgrade_level": state.hp_upgrade_level, "inventory": _encode_inventory(state.inventory), "storage": _encode_inventory(state.storage), "equipment": equipment}


static func _encode_inventory(inventory: Inventory) -> Array:
	var result: Array = []
	for entry in inventory.entries:
		result.append({"id": String(entry.item.id), "count": entry.count})
	return result


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func decode(data: Variant) -> RunCarryover:
	if not data is Dictionary or not integer(data.get("version"), VERSION, VERSION):
		return null
	var state := RunCarryover.new()
	if not integer(data.get("gold"), 0, MAX_GOLD) or not integer(data.get("hp_upgrade_level"), 0, state.upgrade.costs.size()):
		return null
	if not _decode_inventory(data.get("inventory"), state.inventory):
		return null
	# Storage was added without changing version 1 so existing saves migrate to an empty warehouse.
	if data.has("storage") and not _decode_inventory(data.storage, state.storage):
		return null
	if not data.get("equipment") is Array or data.equipment.size() != 5:
		return null
	for index in 5:
		var id: Variant = data.equipment[index]
		if id == null and index != Equipment.Slot.MAIN:
			state.equipment.slots[index] = null
			continue
		if not id is String:
			return null
		var item := ItemCatalog.by_id(id)
		if item == null or not state.equipment.accepts(item, index):
			return null
		state.equipment.slots[index] = item
	state.gold = int(data.gold)
	state.hp_upgrade_level = int(data.hp_upgrade_level)
	return state


static func _decode_inventory(data: Variant, inventory: Inventory) -> bool:
	if not data is Array or data.size() > inventory.max_entries:
		return false
	var stacks: Dictionary = {}
	for entry: Variant in data:
		if not entry is Dictionary or not entry.get("id") is String:
			return false
		var item := ItemCatalog.by_id(entry.id)
		if item == null or not integer(entry.get("count"), 1, inventory.max_stack if item.stackable() else 1):
			return false
		if item.stackable():
			if stacks.has(item.id):
				return false
			stacks[item.id] = true
		if inventory.add(item, int(entry.count)) != 0:
			return false
	return true

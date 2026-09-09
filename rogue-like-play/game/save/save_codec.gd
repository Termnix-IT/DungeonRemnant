class_name SaveCodec
extends RefCounted

const VERSION := 1
const MAX_GOLD := 1000000000


static func encode(state: RunCarryover) -> Dictionary:
	var inventory: Array = []
	for entry in state.inventory.entries:
		inventory.append({"id": String(entry.item.id), "count": entry.count})
	var equipment: Array = []
	for item in state.equipment.slots:
		equipment.append(String(item.id) if item != null else null)
	return {"version": VERSION, "gold": state.gold, "hp_upgrade_level": state.hp_upgrade_level, "inventory": inventory, "equipment": equipment}


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func decode(data: Variant) -> RunCarryover:
	if not data is Dictionary or not integer(data.get("version"), VERSION, VERSION):
		return null
	var state := RunCarryover.new()
	if not integer(data.get("gold"), 0, MAX_GOLD) or not integer(data.get("hp_upgrade_level"), 0, state.upgrade.costs.size()):
		return null
	if not data.get("inventory") is Array or data.inventory.size() > Inventory.MAX_ENTRIES:
		return null
	var stacks: Dictionary = {}
	for entry: Variant in data.inventory:
		if not entry is Dictionary or not entry.get("id") is String:
			return null
		var item := ItemCatalog.by_id(entry.id)
		if item == null or not integer(entry.get("count"), 1, Inventory.MAX_STACK if item.stackable() else 1):
			return null
		if item.stackable():
			if stacks.has(item.id):
				return null
			stacks[item.id] = true
		if state.inventory.add(item, int(entry.count)) != 0:
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

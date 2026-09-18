class_name SaveCodec
extends RefCounted

const VERSION := 3
const MAX_GOLD := 1000000000


static func encode(state: RunCarryover) -> Dictionary:
	var equipment: Array = []
	for item in state.equipment.slots:
		equipment.append(_encode_item(item))
	return {"version": VERSION, "gold": state.gold, "skills": state.skill_levels.duplicate(true), "bosses": state.defeated_bosses.duplicate(true), "entries": state.unlocked_entries.duplicate(true), "cleared_stages": state.cleared_stages.duplicate(), "hp_upgrade_level": state.hp_upgrade_level, "inventory": _encode_inventory(state.inventory), "storage": _encode_inventory(state.storage), "equipment": equipment}


static func _encode_inventory(inventory: Inventory) -> Array:
	var result: Array = []
	for entry in inventory.entries:
		var data := {"id": String(entry.item.id), "count": entry.count}
		if entry.item.socketed_scroll != null:
			data["scroll"] = String(entry.item.socketed_scroll.id)
		result.append(data)
	return result


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func decode(data: Variant) -> RunCarryover:
	if not data is Dictionary or not integer(data.get("version"), 1, VERSION):
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
		var item := _decode_item(id)
		if item == null or not state.equipment.accepts(item, index):
			return null
		state.equipment.slots[index] = item
	state.hp_upgrade_level = int(data.hp_upgrade_level)
	if not _decode_campaign(data, state):
		return null
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
		var item := _decode_item(entry)
		if item == null or not integer(entry.get("count"), 1, inventory.max_stack if item.stackable() else 1):
			return false
		if item.stackable():
			if stacks.has(item.id):
				return false
			stacks[item.id] = true
		if inventory.add(item, int(entry.count)) != 0:
			return false
	return true


static func _encode_item(item: ItemData) -> Variant:
	if item == null:
		return null
	if item.socketed_scroll == null:
		return String(item.id)
	return {"id": String(item.id), "scroll": String(item.socketed_scroll.id)}


static func _decode_item(data: Variant) -> ItemData:
	if data is String:
		return ItemCatalog.by_id(data)
	if not data is Dictionary or not data.get("id") is String:
		return null
	var item := ItemCatalog.by_id(data.id)
	if item == null or not data.has("scroll"):
		return item
	if not data.scroll is String or item.kind != ItemData.Kind.WEAPON or item.weapon.kind != WeaponData.Kind.STAFF:
		return null
	var scroll := ItemCatalog.by_id(data.scroll)
	if scroll == null or scroll.kind != ItemData.Kind.SCROLL:
		return null
	item = item.duplicate()
	item.socketed_scroll = scroll
	return item


static func _decode_campaign(data: Dictionary, state: RunCarryover) -> bool:
	var skills: Variant = data.get("skills", {})
	if not skills is Dictionary:
		return false
	for id: Variant in skills:
		if not id is String:
			return false
		var node := SkillCatalog.find(StringName(id))
		if node == null or not integer(skills[id], 0, node.max_rank):
			return false
		state.skill_levels[id] = int(skills[id])
	for field in ["bosses", "entries"]:
		var values: Variant = data.get(field, {})
		if not values is Dictionary:
			return false
		for stage: Variant in values:
			if stage not in ["ancient_ruins", "forest"] or not values[stage] is Array:
				return false
			var seen: Array[int] = []
			for value: Variant in values[stage]:
				if not integer(value, 1, 50) or value in seen:
					return false
				if (field == "bosses" and int(value) not in [10, 20, 30, 40, 50]) or (field == "entries" and int(value) not in [11, 21, 31, 41]):
					return false
				seen.append(int(value))
			if field == "bosses":
				state.defeated_bosses[stage] = seen
			else:
				state.unlocked_entries[stage] = seen
	var cleared: Variant = data.get("cleared_stages", [])
	if not cleared is Array:
		return false
	for stage: Variant in cleared:
		if stage not in ["ancient_ruins", "forest"] or stage in state.cleared_stages:
			return false
		state.cleared_stages.append(stage)
	for node in SkillCatalog.NODES:
		if state.skill_rank(node.id) > 0 and state.skill_rank(node.prerequisite) < node.prerequisite_rank:
			return false
	for stage in state.cleared_stages:
		if 50 not in state.defeated_bosses.get(stage, []):
			return false
	for stage in state.unlocked_entries:
		for floor_number in state.unlocked_entries[stage]:
			if floor_number - 1 not in state.defeated_bosses.get(stage, []):
				return false
	return true

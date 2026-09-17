class_name ItemCatalog
extends RefCounted

const POTION := preload("res://data/items/healing_potion.tres")


static func shop_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	if POTION.buy_price > 0:
		result.append(POTION)
	for index in 9:
		var item := floor_item(index)
		if item.buy_price > 0:
			result.append(item)
	result.append_array(talismans())
	return result


static func by_id(id: String) -> ItemData:
	if id == String(POTION.id):
		return POTION
	for index in 9:
		var item := floor_item(index)
		if String(item.id) == id:
			return item
	for item in talismans():
		if String(item.id) == id:
			return item
	return null


static func floor_item(index: int) -> ItemData:
	var equipment: Array[ItemData] = [
		ItemData.from_weapon(preload("res://data/weapons/hammer.tres")),
		preload("res://data/items/leather_armor.tres"),
		preload("res://data/items/vital_charm.tres"),
		preload("res://data/items/vision_charm.tres"),
		preload("res://data/items/power_charm.tres"),
		preload("res://data/items/chain_armor.tres"),
		ItemData.from_weapon(preload("res://data/weapons/sword.tres")),
		ItemData.from_weapon(preload("res://data/weapons/spear.tres")),
		ItemData.from_weapon(preload("res://data/weapons/axe.tres")),
	]
	return equipment[index % equipment.size()]


static func talismans() -> Array[ItemData]:
	return [
		preload("res://data/items/damage_talisman.tres"),
		preload("res://data/items/defense_talisman.tres"),
		preload("res://data/items/vision_talisman.tres"),
		preload("res://data/items/regen_talisman.tres"),
		preload("res://data/items/kill_heal_talisman.tres"),
		preload("res://data/items/gold_talisman.tres"),
		preload("res://data/items/exp_talisman.tres"),
	]


static func ground_item(index: int) -> ItemData:
	var available: Array[ItemData] = []
	for item in shop_items():
		if item.kind != ItemData.Kind.ACCESSORY and item.effect_id.is_empty():
			available.append(item)
	return available[posmod(index, available.size())]

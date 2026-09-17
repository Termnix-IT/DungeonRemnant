class_name ItemCatalog
extends RefCounted

const POTION := preload("res://data/items/healing_potion.tres")


static func shop_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	if POTION.buy_price > 0:
		result.append(POTION)
	for index in 8:
		var item := floor_item(index)
		if item.buy_price > 0:
			result.append(item)
	return result


static func by_id(id: String) -> ItemData:
	if id == String(POTION.id):
		return POTION
	for index in 8:
		var item := floor_item(index)
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
	]
	return equipment[index % equipment.size()]

class_name Equipment
extends RefCounted

enum Slot { MAIN, SUB, ARMOR, ACCESSORY_1, ACCESSORY_2 }
const SLOT_NAMES := ["Main", "Sub", "Armor", "Accessory 1", "Accessory 2"]
var slots: Array[ItemData] = []


func _init() -> void:
	slots.assign([
		ItemData.from_weapon(preload("res://data/weapons/sword.tres")),
		ItemData.from_weapon(preload("res://data/weapons/spear.tres")), null, null, null,
	])


func accepts(item: ItemData, slot: int) -> bool:
	if item == null or slot < 0 or slot >= slots.size():
		return false
	if slot == Slot.MAIN or slot == Slot.SUB:
		return item.kind == ItemData.Kind.WEAPON and item.weapon != null
	if slot == Slot.ARMOR:
		return item.kind == ItemData.Kind.ARMOR
	return item.kind == ItemData.Kind.ACCESSORY


func equip(inventory: Inventory, index: int, slot: int) -> bool:
	if index < 0 or index >= inventory.entries.size():
		return false
	var item := inventory.entries[index].item
	if not accepts(item, slot):
		return false
	var candidate := inventory.copy()
	candidate.remove(index)
	if slots[slot] != null and candidate.add(slots[slot]) != 0:
		return false
	inventory.entries = candidate.entries
	slots[slot] = item
	return true


func unequip(inventory: Inventory, slot: int) -> bool:
	# A main weapon is required for the existing attack flow; replace or swap it.
	if slot <= Slot.MAIN or slot >= slots.size() or slots[slot] == null:
		return false
	var candidate := inventory.copy()
	if candidate.add(slots[slot]) != 0:
		return false
	inventory.entries = candidate.entries
	slots[slot] = null
	return true


func swap_weapons() -> bool:
	if slots[Slot.SUB] == null:
		return false
	var previous := slots[Slot.MAIN]
	slots[Slot.MAIN] = slots[Slot.SUB]
	slots[Slot.SUB] = previous
	return true


func bonuses() -> Dictionary:
	var result := {"hp": 0, "defense": 0, "vision": 0, "damage": 0}
	for item in slots:
		if item == null:
			continue
		result.hp += item.max_hp_bonus
		result.defense += item.defense_bonus
		result.vision += item.vision_bonus
		result.damage += item.damage_bonus
	return result

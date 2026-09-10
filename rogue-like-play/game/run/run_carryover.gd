class_name RunCarryover
extends RefCounted

const STORAGE_MAX_ENTRIES := 120
const STORAGE_MAX_STACK := 999

var gold := 0
var inventory := Inventory.new()
var storage := Inventory.new(STORAGE_MAX_ENTRIES, STORAGE_MAX_STACK)
var equipment := Equipment.new()
var hp_upgrade_level := 0
var upgrade: PermanentUpgrade = preload("res://data/upgrades/max_hp.tres")


func purchase_upgrade() -> bool:
	var cost := upgrade.price(hp_upgrade_level)
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	hp_upgrade_level += 1
	return true


func transfer_item(source: Inventory, destination: Inventory, index: int) -> int:
	if source == null or destination == null or source == destination or index < 0 or index >= source.entries.size():
		return 0
	var entry := source.entries[index]
	var unaccepted := destination.add(entry.item, entry.count)
	var moved := entry.count - unaccepted
	if moved > 0:
		source.remove(index, moved)
	return moved


func capture(player: Node2D, held_gold: int) -> void:
	gold = held_gold
	inventory = player.inventory.copy()
	equipment = Equipment.new()
	equipment.slots.assign(player.equipment.slots)


func restore(player: Node2D) -> void:
	player.inventory = inventory.copy()
	player.equipment = Equipment.new()
	player.equipment.slots.assign(equipment.slots)
	player.refresh_equipment_effects()
	player.apply_permanent_hp(upgrade.hp_bonus(hp_upgrade_level))
	player.hp = player.stats.max_hp

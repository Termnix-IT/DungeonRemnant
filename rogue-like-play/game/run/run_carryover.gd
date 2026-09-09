class_name RunCarryover
extends RefCounted

var gold := 0
var inventory := Inventory.new()
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

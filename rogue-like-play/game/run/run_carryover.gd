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


func sell_item(from_storage: bool, index: int, amount: int) -> bool:
	var source := storage if from_storage else inventory
	if index < 0 or index >= source.entries.size() or amount <= 0:
		return false
	var entry := source.entries[index]
	if entry.item.socketed_scroll != null:
		return false
	var value := entry.item.sell_price * amount
	var owned := 0
	for matching in source.entries:
		if matching.item.id == entry.item.id and matching.item.socketed_scroll == null:
			owned += matching.count
	if amount > owned or entry.item.sell_price <= 0 or gold + value > SaveCodec.MAX_GOLD:
		return false
	var remaining := amount
	for item_index in range(source.entries.size() - 1, -1, -1):
		var matching := source.entries[item_index]
		if matching.item.id == entry.item.id and matching.item.socketed_scroll == null:
			var removed := mini(remaining, matching.count)
			source.remove(item_index, removed)
			remaining -= removed
			if remaining == 0:
				break
	gold += value
	return true


func buy_item(to_storage: bool, item_id: StringName, amount: int) -> bool:
	var item := ItemCatalog.by_id(String(item_id))
	if item == null or item.buy_price <= 0 or amount <= 0 or amount > STORAGE_MAX_STACK:
		return false
	var cost := item.buy_price * amount
	if gold < cost:
		return false
	var destination := storage if to_storage else inventory
	var candidate := destination.copy()
	if candidate.add(item, amount) != 0:
		return false
	destination.entries = candidate.entries
	gold -= cost
	return true


func preparation_stats(gear: Equipment = equipment) -> Dictionary:
	var base: ActorStats = preload("res://data/player_stats.tres")
	var bonus := gear.bonuses()
	var main := gear.slots[Equipment.Slot.MAIN]
	var attack_weapon: WeaponData = (main.socketed_scroll.weapon if main.socketed_scroll != null else main.weapon) if main != null else null
	return {"hp": base.max_hp + upgrade.hp_bonus(hp_upgrade_level) + bonus.hp,
		"attack": base.attack + bonus.damage + (attack_weapon.damage_bonus if attack_weapon != null else 0),
		"defense": base.defense + bonus.defense,
		"reach": attack_weapon.reach if attack_weapon != null else 0}


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

class_name RunCarryover
extends RefCounted

const STORAGE_MAX_ENTRIES := 120
const STORAGE_MAX_STACK := 999

var gold := 0
var inventory := Inventory.new()
var storage := Inventory.new(STORAGE_MAX_ENTRIES, STORAGE_MAX_STACK)
var equipment := Equipment.new()
var hp_upgrade_level := 0
var skill_levels: Dictionary = {}
var defeated_bosses: Dictionary = {}
var unlocked_entries: Dictionary = {}
var cleared_stages: Array[String] = []
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
	return {"hp": base.max_hp + upgrade.hp_bonus(hp_upgrade_level) + bonus.hp + skill_bonus(&"hp"),
		"attack": base.attack + skill_bonus(&"attack") + bonus.damage + (attack_weapon.damage_bonus if attack_weapon != null else 0),
		"defense": base.defense + skill_bonus(&"defense") + bonus.defense,
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
	player.apply_permanent_hp(upgrade.hp_bonus(hp_upgrade_level) + skill_bonus(&"hp"))
	player.stats.attack += skill_bonus(&"attack")
	player.stats.defense += skill_bonus(&"defense")
	player.stats.max_mp += skill_bonus(&"mp")
	player.mp = player.stats.max_mp
	player.hp = player.stats.max_hp


func skill_rank(id: StringName) -> int:
	return hp_upgrade_level if id == &"hp" else int(skill_levels.get(String(id), 0))


func skill_bonus(effect: StringName) -> int:
	var value := 0
	for node in SkillCatalog.NODES:
		if node.effect == effect:
			value += node.amount * skill_rank(node.id)
	return value


func can_purchase_skill(id: StringName) -> bool:
	var node := SkillCatalog.find(id)
	if node == null:
		return false
	var cost := node.price(skill_rank(id))
	return cost >= 0 and gold >= cost and skill_rank(node.prerequisite) >= node.prerequisite_rank


func purchase_skill(id: StringName) -> bool:
	if not can_purchase_skill(id):
		return false
	var node := SkillCatalog.find(id)
	gold -= node.price(skill_rank(id))
	skill_levels[String(id)] = skill_rank(id) + 1
	return true


func stage_available(stage: StageData) -> bool:
	return stage != null and stage.available and (stage.previous_stage.is_empty() or String(stage.previous_stage) in cleared_stages)


func record_boss(stage_id: StringName, floor_number: int, final: bool) -> void:
	var key := String(stage_id)
	if key.is_empty():
		return
	if not defeated_bosses.has(key):
		defeated_bosses[key] = []
	if floor_number not in defeated_bosses[key]:
		defeated_bosses[key].append(floor_number)
	if final and key not in cleared_stages:
		cleared_stages.append(key)


func can_start(stage: StageData, floor_number: int) -> bool:
	return stage_available(stage) and (floor_number == 1 or floor_number in unlocked_entries.get(String(stage.id), [])) and floor_number <= stage.floor_count


func can_unlock_entry(stage: StageData, floor_number: int) -> bool:
	if not stage_available(stage) or floor_number not in [11, 21, 31, 41] or floor_number >= stage.floor_count:
		return false
	var index := (floor_number - 1) / 10 - 1
	return index < stage.entry_costs.size() and gold >= stage.entry_costs[index] and floor_number - 1 in defeated_bosses.get(String(stage.id), []) and floor_number not in unlocked_entries.get(String(stage.id), [])


func unlock_entry(stage: StageData, floor_number: int) -> bool:
	if not can_unlock_entry(stage, floor_number):
		return false
	gold -= stage.entry_costs[(floor_number - 1) / 10 - 1]
	var key := String(stage.id)
	if not unlocked_entries.has(key):
		unlocked_entries[key] = []
	unlocked_entries[key].append(floor_number)
	return true

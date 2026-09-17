extends Node

signal turn_finished
signal ability_choice_requested
signal player_moved
signal boss_defeated

var grid: GridState
var player: Node2D
var enemies: Array[Node2D] = []
var turn_count := 0
var floor_turn_count := 0
var moved_this_turn := false
var boss_reward_claimed := false
var busy := false
var ended := false
var gold := 0
var earned_gold := 0
var paused := false
var progression: RunProgression
var offered_abilities: Array[AbilityData] = []
var last_message := "探索開始。水色がプレイヤー、赤色が敵です。"


func submit(kind: String, direction: Vector2i) -> bool:
	if kind == "switch":
		return submit_inventory("switch")
	if busy or ended or paused or player.hp <= 0:
		return false
	if direction == Vector2i.ZERO or absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	player.facing = direction
	moved_this_turn = false
	player.queue_redraw()
	if kind == "move":
		if not grid.move_actor(player, player.cell + direction):
			last_message = "進めません。向きだけ変更しました。"
			return false
		last_message = "移動しました。"
		moved_this_turn = true
		player_moved.emit()
	elif kind == "attack":
		var damage := CombatRules.attack(grid, player, direction, player.effective_weapon())
		last_message = "敵に %d ダメージ。" % damage if damage > 0 else "攻撃は空振りしました。"
	else:
		return false
	return _complete_player_action()


func submit_inventory(kind: String, index: int = -1, slot: int = -1) -> bool:
	if busy or ended or paused or player.hp <= 0:
		return false
	var succeeded := false
	match kind:
		"equip":
			succeeded = player.equipment.equip(player.inventory, index, slot)
		"unequip":
			succeeded = player.equipment.unequip(player.inventory, slot)
		"switch":
			succeeded = player.equipment.swap_weapons()
		"use":
			if index >= 0 and index < player.inventory.entries.size():
				var item: ItemData = player.inventory.entries[index].item
				if item.kind == ItemData.Kind.CONSUMABLE and item.heal_amount > 0 and player.hp < player.stats.max_hp:
					player.hp = mini(player.stats.max_hp, player.hp + item.heal_amount)
					player.inventory.remove(index)
					succeeded = true
	if not succeeded:
		last_message = "実行できません。収納の空き・装備先・HPを確認してください。"
		return false
	player.refresh_equipment_effects()
	player.aiming = false
	last_message = "回復薬を使用しました。" if kind == "use" else "装備を変更しました。"
	if kind == "use":
		moved_this_turn = false
		return _complete_player_action()
	return true


func _complete_player_action() -> bool:
	busy = true
	player.input_enabled = false
	turn_count += 1
	floor_turn_count += 1
	if progression != null:
		var earned_exp := 0
		var action_gold := 0
		var kills := 0
		for enemy: Node2D in enemies:
			if enemy.hp <= 0 and not enemy.exp_claimed:
				enemy.exp_claimed = true
				enemy.hide()
				earned_exp += enemy.stats.exp_reward
				gold += enemy.stats.gold_reward
				earned_gold += enemy.stats.gold_reward
				action_gold += enemy.stats.gold_reward
				kills += 1
		if kills > 0:
			player.hp = mini(player.stats.max_hp, player.hp + kills * player.abilities.total(AbilityData.Effect.KILL_HEAL))
			progression.gain_exp(earned_exp)
			last_message += " EXP +%d / Gold +%d。" % [earned_exp, action_gold]
		for enemy: Node2D in enemies:
			if enemy.stats.is_boss and enemy.hp <= 0 and not boss_reward_claimed:
				boss_reward_claimed = true
				boss_defeated.emit()
				if ended:
					busy = false
					progression.pending_choices = 0
					return true
		if _offer_choice():
			return true
	_finish_enemy_phase()
	return true


func _offer_choice() -> bool:
	if progression.pending_choices <= 0:
		return false
	offered_abilities = player.abilities.offer()
	if offered_abilities.is_empty():
		progression.pending_choices = 0
		return false
	ability_choice_requested.emit()
	return true


func choose_ability(id: StringName) -> bool:
	if not busy or ended or paused or offered_abilities.is_empty():
		return false
	for ability in offered_abilities:
		if ability.id == id:
			if not player.gain_ability(ability):
				return false
			offered_abilities.clear()
			progression.pending_choices -= 1
			if not _offer_choice():
				_finish_enemy_phase()
			return true
	return false


func _finish_enemy_phase() -> void:
	for enemy: Node2D in enemies:
		if enemy.hp <= 0:
			enemy.hide()
			continue
		if player.hp <= 0:
			break
		var damage: int = enemy.take_turn(grid, player)
		if damage > 0:
			last_message += " 敵の攻撃 %d。" % damage
	ended = player.hp <= 0
	player.input_enabled = not ended
	busy = false
	turn_finished.emit()

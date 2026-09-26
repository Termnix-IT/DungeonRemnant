extends Node

signal turn_finished
signal ability_choice_requested
signal player_moved
signal boss_defeated
signal enemy_defeated(enemy: Node2D)
signal summon_requested(enemy: Node2D)

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
# One log entry per action. Later notes in the same action (pickups, EXP,
# enemy replies) extend it; a new serial starts the next entry.
var last_message := ""
var message_serial := 0
var defeated_by := ""


func begin_message(text: String) -> void:
	last_message = text
	message_serial += 1


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
			begin_message("その方向には進めない。向きだけ変えた。")
			return false
		# Footsteps are routine; only what happens on arrival is logged.
		begin_message("")
		moved_this_turn = true
		player_moved.emit()
	elif kind == "attack":
		var attack: WeaponData = player.effective_weapon()
		if player.mp < attack.mana_cost:
			begin_message("MPが足りない。")
			return false
		if attack.spell_heal > 0 and player.hp >= player.stats.max_hp:
			begin_message("HPは満タンだ。")
			return false
		player.mp -= attack.mana_cost
		if attack.spell_heal > 0:
			var before: int = player.hp
			player.hp = mini(player.stats.max_hp, player.hp + attack.spell_heal)
			begin_message("治癒の魔法でHPが%d回復した。" % (player.hp - before))
		else:
			var first_event := grid.visual_events.size()
			CombatRules.attack(grid, player, direction, attack)
			begin_message(_attack_report(first_event))
	else:
		return false
	return _complete_player_action()


func submit_inventory(kind: String, index: int = -1, slot: int = -1) -> bool:
	if busy or ended or paused or player.hp <= 0:
		return false
	var succeeded := false
	var used_note := ""
	match kind:
		"socket":
			succeeded = player.equipment.socket(player.inventory, index, slot)
		"unsocket":
			succeeded = player.equipment.unsocket(player.inventory, slot)
		"equip":
			succeeded = player.equipment.equip(player.inventory, index, slot)
		"unequip":
			succeeded = player.equipment.unequip(player.inventory, slot)
		"switch":
			succeeded = player.equipment.swap_weapons()
		"use":
			if index >= 0 and index < player.inventory.entries.size():
				var item: ItemData = player.inventory.entries[index].item
				if not item.effect_id.is_empty() and player.active_effects.add(item):
					player.inventory.remove(index)
					succeeded = true
					used_note = "%sを使った。" % item.display_name
				elif item.kind == ItemData.Kind.CONSUMABLE and item.restore_mp > 0 and player.mp < player.stats.max_mp:
					var before_mp: int = player.mp
					player.mp = mini(player.stats.max_mp, player.mp + item.restore_mp)
					player.inventory.remove(index)
					succeeded = true
					used_note = "%sを使った。MPが%d回復。" % [item.display_name, player.mp - before_mp]
				elif item.kind == ItemData.Kind.CONSUMABLE and item.heal_amount > 0 and player.hp < player.stats.max_hp:
					var before_hp: int = player.hp
					player.hp = mini(player.stats.max_hp, player.hp + item.heal_amount)
					player.inventory.remove(index)
					succeeded = true
					used_note = "%sを使った。HPが%d回復。" % [item.display_name, player.hp - before_hp]
	if not succeeded:
		begin_message("実行できません。収納の空き・装備先・HPを確認してください。")
		return false
	player.refresh_equipment_effects()
	player.aiming = false
	begin_message(used_note if kind == "use" else "装備を変更した。")
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
				enemy_defeated.emit(enemy)
				earned_exp += enemy.stats.exp_reward
				gold += enemy.stats.gold_reward
				earned_gold += enemy.stats.gold_reward
				action_gold += enemy.stats.gold_reward
				kills += 1
		if kills > 0:
			player.hp = mini(player.stats.max_hp, player.hp + kills * (player.abilities.total(AbilityData.Effect.KILL_HEAL) + player.active_effects.amount(&"kill_heal")))
			earned_exp += earned_exp * player.active_effects.amount(&"exp") / 100
			var bonus_gold: int = action_gold * player.active_effects.amount(&"gold") / 100
			gold += bonus_gold
			earned_gold += bonus_gold
			action_gold += bonus_gold
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
	# Spawned actors start acting on the following turn.
	for enemy: Node2D in enemies.duplicate():
		if enemy.hp <= 0:
			enemy.hide()
			continue
		if player.hp <= 0:
			break
		var damage: int = enemy.take_turn(grid, player)
		if enemy.summon_due:
			enemy.summon_due = false
			summon_requested.emit(enemy)
		if damage > 0:
			last_message += " %sの攻撃で%dダメージ。" % [enemy.stats.display_name, damage]
			if player.hp <= 0:
				defeated_by = enemy.stats.display_name
				last_message += " %sに倒された……" % defeated_by
	if player.hp > 0:
		player.hp = mini(player.stats.max_hp, player.hp + player.active_effects.amount(&"regen"))
	player.active_effects.tick()
	player.refresh_equipment_effects()
	ended = player.hp <= 0
	player.input_enabled = not ended
	busy = false
	turn_finished.emit()


# Names each target the player's attack reached, from this action's hit events.
func _attack_report(first_event: int) -> String:
	var parts: Array[String] = []
	for index in range(first_event, grid.visual_events.size()):
		var event: Dictionary = grid.visual_events[index]
		if event.kind != "hit" or event.source != player:
			continue
		var target_name: String = event.actor.stats.display_name
		parts.append("%sを倒した" % target_name if event.dead else "%sに%dダメージ" % [target_name, event.damage])
	return "攻撃は空を切った。" if parts.is_empty() else "、".join(parts) + "。"

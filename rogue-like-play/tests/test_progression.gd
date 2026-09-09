extends SceneTree

const RUN := preload("res://game/run/run.tscn")
const PLAYER := preload("res://actors/player/player.tscn")
const ENEMY := preload("res://actors/enemy/enemy.tscn")
const DEFENSE := preload("res://data/abilities/defense.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func test_exp_and_offers() -> void:
	var progress := RunProgression.new()
	progress.gain_exp(9)
	check(progress.level == 1 and progress.exp == 9 and progress.pending_choices == 0, "Below threshold")
	progress.gain_exp(1)
	check(progress.level == 2 and progress.exp == 0 and progress.pending_choices == 1, "Exact threshold")
	progress.gain_exp(27)
	check(progress.level == 4 and progress.exp == 1 and progress.pending_choices == 3, "Multiple levels preserve remainder")
	progress.gain_exp(-5)
	check(progress.exp == 1, "Negative EXP ignored")
	progress.level = 99
	progress.pending_choices = 0
	progress.gain_exp(100000)
	check(progress.level == 100 and progress.exp == 0 and progress.pending_choices == 1 and progress.required_exp() == 0, "Level 100 cap")
	progress.gain_exp(100)
	check(progress.pending_choices == 1 and progress.exp == 0, "No extra choices after cap")
	var abilities := AbilitySystem.new()
	var tuned: AbilityData = DEFENSE.duplicate()
	tuned.amount = 2
	check(tuned.effect_description().contains("2軽減"), "Ability description follows tuned effect value")
	abilities.rng.seed = 123
	for attempt in 20:
		var options := abilities.offer()
		var ids: Dictionary = {}
		for ability in options:
			ids[ability.id] = true
		check(options.size() == 3 and ids.size() == 3, "Three unique choices")
	for ability in abilities.definitions:
		abilities.levels[ability.id] = ability.max_level
	check(abilities.offer().is_empty(), "No choices when everything is capped")
	check(not abilities.upgrade(abilities.definitions[0]), "Cannot exceed max level")
	abilities.levels[abilities.definitions[0].id] = 0
	check(abilities.offer().size() == 1, "One remaining candidate")
	abilities.levels[abilities.definitions[1].id] = 0
	check(abilities.offer().size() == 2, "Two remaining candidates")


func find_ability(player: Node2D, effect: AbilityData.Effect) -> AbilityData:
	for ability: AbilityData in player.abilities.definitions:
		if ability.effect == effect:
			return ability
	return null


func test_effects() -> void:
	var player := PLAYER.instantiate()
	var other := PLAYER.instantiate()
	var enemy := ENEMY.instantiate()
	root.add_child(player)
	root.add_child(other)
	root.add_child(enemy)
	check(player.gain_ability(find_ability(player, AbilityData.Effect.MAX_HP)), "Acquire HP ability")
	check(player.hp == 27 and player.stats.max_hp == 27, "Max and current HP increase together")
	check(other.stats.max_hp == 24 and preload("res://data/player_stats.tres").max_hp == 24, "Definition and other player unchanged")
	player.gain_ability(find_ability(player, AbilityData.Effect.ATTACK))
	player.gain_ability(DEFENSE)
	player.gain_ability(find_ability(player, AbilityData.Effect.VISION))
	check(player.stats.attack == 5 and player.stats.defense == 1 and player.vision_range == 9, "General stats and vision growth")
	var grid := GridState.new()
	grid.size = Vector2i(12, 12)
	grid.place(player, Vector2i(2, 2))
	grid.place(enemy, Vector2i(3, 2))
	check(CombatRules.attack(grid, enemy, Vector2i.LEFT) == 2, "Defense reduces actual damage")
	var weapons: Array[WeaponData] = [preload("res://data/weapons/sword.tres"), preload("res://data/weapons/spear.tres"), preload("res://data/weapons/hammer.tres")]
	var effects := [AbilityData.Effect.SWORD_DAMAGE, AbilityData.Effect.SPEAR_DAMAGE, AbilityData.Effect.HAMMER_DAMAGE]
	for index in 3:
		var base_bonus: int = weapons[index].damage_bonus
		player.gain_ability(find_ability(player, effects[index]))
		player.weapon = weapons[index]
		var effective: WeaponData = player.effective_weapon()
		check(effective.damage_bonus == base_bonus + 1 and weapons[index].damage_bonus == base_bonus, "Weapon bonus without definition mutation")
		enemy.hp = 8
		check(CombatRules.attack(grid, player, Vector2i.RIGHT, effective) == 6 + base_bonus, "Weapon bonus changes actual damage")
	player.weapon = weapons[1]
	player.gain_ability(find_ability(player, AbilityData.Effect.SPEAR_RANGE))
	player.gain_ability(find_ability(player, AbilityData.Effect.SPEAR_RANGE))
	player.gain_ability(find_ability(player, AbilityData.Effect.SPEAR_PIERCE))
	check(player.effective_weapon().reach == 4 and player.effective_weapon().pierces, "Spear range and penetration")
	check(weapons[1].reach == 2 and not weapons[1].pierces, "Spear definition unchanged")
	grid.remove_actor(enemy)
	grid.place(enemy, Vector2i(3, 2))
	enemy.hp = 8
	var second := ENEMY.instantiate()
	root.add_child(second)
	grid.place(second, Vector2i(4, 2))
	check(CombatRules.attack_cells(grid, player.cell, Vector2i.RIGHT, player.effective_weapon()).size() == 4, "Piercing preview continues beyond enemies")
	check(CombatRules.attack(grid, player, Vector2i.RIGHT, player.effective_weapon()) == 12 and enemy.hp == 2 and second.hp == 2, "Each pierced enemy hit once")
	grid.walls[Vector2i(4, 2)] = true
	check(CombatRules.attack_cells(grid, player.cell, Vector2i.RIGHT, player.effective_weapon()) == [Vector2i(3, 2)], "Penetration still stops at wall")
	grid.walls.clear()
	grid.walls[Vector2i(4, 3)] = true
	check(CombatRules.attack_cells(grid, player.cell, Vector2i(1, 1), player.effective_weapon()) == [Vector2i(3, 3)], "Extended spear respects corner")
	player.free()
	other.free()
	enemy.free()
	second.free()


func new_fight(reward: int = 10) -> Node2D:
	var run := RUN.instantiate()
	run.generation_seed = 47
	run.dungeon_settings = DungeonSettings.new()
	run.dungeon_settings.enemy_count = 0
	root.add_child(run)
	var grid: GridState = run.dungeon.grid
	grid.size = Vector2i(12, 12)
	grid.walls.clear()
	grid.pillars.clear()
	grid.occupants.clear()
	run.dungeon.has_stairs = false
	grid.place(run.turns.player, Vector2i(2, 2))
	for cell: Vector2i in [Vector2i(3, 2), Vector2i(2, 3)]:
		var enemy := ENEMY.instantiate()
		enemy.stats = enemy.stats.duplicate()
		enemy.stats.exp_reward = reward
		run.dungeon.get_node("Actors").add_child(enemy)
		grid.place(enemy, cell)
		run.turns.enemies.append(enemy)
	run.turns.enemies[0].hp = 4
	run._refresh()
	return run


func test_turn_pause() -> void:
	var run := new_fight()
	run.turns.player.abilities.definitions.assign([DEFENSE])
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.progression.level == 2 and run.turns.turn_count == 1, "Kill grants configured EXP in one turn")
	check(run.turns.busy and not run.turns.player.input_enabled and run.ability_choice.visible, "Ability dialog pauses input and enemies")
	check(run.turns.player.hp == 24 and not run.turns.enemies[0].visible, "Enemy does not retaliate during choice")
	check(run.turns.offered_abilities.size() == 1 and not run.ability_choice.buttons[1].visible, "UI hides missing candidates")
	check(not run.turns.submit("move", Vector2i.LEFT), "Movement rejected during choice")
	check(not run.turns.choose_ability(&"invalid"), "Non-offered ability rejected")
	run.ability_choice.buttons[0].pressed.emit()
	check(not run.turns.busy and run.turns.player.input_enabled and not run.ability_choice.visible, "Choice resumes turn")
	check(run.turns.player.hp == 22 and run.turns.turn_count == 1, "Chosen defense applies before exactly one enemy action")
	run.turns.submit("attack", Vector2i.LEFT)
	check(run.progression.level == 2 and run.progression.exp == 0, "Corpse grants EXP only once")
	check(not run.turns.choose_ability(DEFENSE.id), "Cannot choose outside dialog")
	run.free()
	run = new_fight(40)
	run.turns.player.abilities.definitions.assign([DEFENSE])
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.progression.level == 4 and run.progression.pending_choices == 3, "Multiple choices queued")
	for index in 3:
		check(run.turns.player.hp == 24, "No retaliation between queued choices")
		run.ability_choice.buttons[0].pressed.emit()
	check(run.turns.player.hp == 23 and run.turns.turn_count == 1 and not run.turns.busy, "Enemy resumes once after all choices")
	run.free()
	run = new_fight()
	run.turns.player.abilities.definitions.assign([DEFENSE])
	run.turns.player.abilities.levels[DEFENSE.id] = DEFENSE.max_level
	run.turns.submit("attack", Vector2i.RIGHT)
	check(not run.turns.busy and not run.ability_choice.visible and run.progression.pending_choices == 0, "All-max case skips dialog")
	check(run.turns.player.hp == 21 and run.progression.level == 2, "Level gained and enemy turn retained at all-max")
	run.free()


func test_healing_and_lifecycle() -> void:
	var run := new_fight(0)
	var player: Node2D = run.turns.player
	player.gain_ability(find_ability(player, AbilityData.Effect.KILL_HEAL))
	player.hp = 10
	run.turns.submit("attack", Vector2i.RIGHT)
	check(player.hp == 8, "Kill heals one before incoming three damage")
	run.turns.submit("attack", Vector2i.LEFT)
	check(player.hp == 5, "Corpse does not heal twice")
	player.gain_ability(find_ability(player, AbilityData.Effect.MAX_HP))
	player.gain_ability(find_ability(player, AbilityData.Effect.VISION))
	run.progression.level = 7
	run.progression.exp = 4
	var hp: int = player.hp
	run.floor_number = 2
	run._load_floor()
	run._refresh()
	check(player.hp == hp and player.stats.max_hp == 27 and player.vision_range == 9, "Stats persist across floors")
	check(run.progression.level == 7 and run.progression.exp == 4 and player.abilities.levels.size() == 3, "Progress and abilities persist across floors")
	run.free()


func test_piercing_rewards_and_keyboard() -> void:
	var run := new_fight(10)
	var player: Node2D = run.turns.player
	player.weapon = preload("res://data/weapons/spear.tres")
	player.gain_ability(find_ability(player, AbilityData.Effect.SPEAR_PIERCE))
	player.gain_ability(find_ability(player, AbilityData.Effect.KILL_HEAL))
	player.hp = 20
	var second: Node2D = run.turns.enemies[1]
	run.dungeon.grid.remove_actor(second)
	run.dungeon.grid.place(second, Vector2i(4, 2))
	run.turns.enemies[0].hp = 4
	second.hp = 4
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.turns.enemies[0].hp == 0 and second.hp == 0, "Piercing kills both enemies")
	check(player.hp == 22 and run.progression.level == 2 and run.progression.exp == 10, "Both kills grant EXP and healing exactly once")
	check(run.ability_choice.offers.size() == 3, "Real dialog presents three options")
	var selected_id: StringName = run.ability_choice.offers[0].id
	var previous: int = player.abilities.levels.get(selected_id, 0)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_1
	event.pressed = true
	run.ability_choice._unhandled_input(event)
	check(player.abilities.levels[selected_id] == previous + 1 and not run.turns.busy, "Number key selects offered ability and resumes")
	run.turns.submit("attack", Vector2i.RIGHT)
	check(run.progression.exp == 10, "Pierced corpses never grant duplicate rewards")
	run.free()
	run = new_fight(0)
	player = run.turns.player
	player.gain_ability(find_ability(player, AbilityData.Effect.KILL_HEAL))
	# Remove the other enemy to isolate healing at full HP.
	second = run.turns.enemies.pop_back()
	run.dungeon.grid.remove_actor(second)
	second.free()
	run.turns.submit("attack", Vector2i.RIGHT)
	check(player.hp == player.stats.max_hp, "Healing never exceeds maximum HP")
	run.free()
	run = new_fight()
	player = run.turns.player
	player.hp = 1
	player.abilities.definitions.assign([preload("res://data/abilities/sword_damage.tres")])
	run.turns.submit("attack", Vector2i.RIGHT)
	check(player.hp == 1 and run.turns.busy, "Lethal retaliation waits for choice")
	run.ability_choice.buttons[0].pressed.emit()
	check(run.turns.ended and player.hp == 0 and not player.input_enabled and not run.ability_choice.visible, "Death after choice ends run cleanly")
	run.free()
	run = new_fight()
	check(run.progression.level == 1 and run.progression.exp == 0 and run.turns.player.abilities.levels.is_empty(), "New run resets progression and abilities")
	check(run.turns.player.stats.max_hp == 24 and run.turns.player.vision_range == 8, "New run resets derived stats")
	run.free()


func run_tests() -> void:
	test_exp_and_offers()
	test_effects()
	test_turn_pause()
	test_healing_and_lifecycle()
	test_piercing_rewards_and_keyboard()
	print("Progression tests: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

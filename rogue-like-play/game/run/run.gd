extends Node2D

signal hub_requested
signal result_ready

const PLAYER_SCENE := preload("res://actors/player/player.tscn")
const ENEMY_SCENE := preload("res://actors/enemy/enemy.tscn")
const PREVIEW := preload("res://combat/attack_preview.gd")
const FINAL_FLOOR := 10
@export_range(1, 100) var final_floor: int = FINAL_FLOOR
const MOVE_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP, Vector2i(1, -1), Vector2i.RIGHT, Vector2i(1, 1),
	Vector2i.DOWN, Vector2i(-1, 1), Vector2i.LEFT, Vector2i(-1, -1),
]
const ENEMY_TYPES: Array[EnemyStats] = [
	preload("res://data/enemies/basic_enemy.tres"),
	preload("res://data/enemies/proximity_enemy.tres"),
	preload("res://data/enemies/turret_enemy.tres"),
	preload("res://data/enemies/fast_enemy.tres"),
	preload("res://data/enemies/summoner_enemy.tres"),
]

@export var starting_weapon: WeaponData = preload("res://data/weapons/sword.tres")
@export var dungeon_settings: DungeonSettings = preload("res://data/dungeon/default.tres")
@export var level_settings: LevelSettings = preload("res://data/progression/levels.tres")
## Zero selects a fresh random seed. Nonzero seeds reproduce layouts for testing.
@export var generation_seed: int = 0
var preview: Node2D
var floor_number := 1
var floor_limit := 5000
var exit_cell := Vector2i(-1, -1)
var transition_kind := ""
var transition_dialog: ConfirmationDialog
var last_prompt_cell := Vector2i(-1, -1)
var warning_marks: Array[int] = []
var rng := RandomNumberGenerator.new()
var progression := RunProgression.new()
var carryover := RunCarryover.new()
var initial_state: RunCarryover
var result: Dictionary = {}
var loss_rng := RandomNumberGenerator.new()
var discovered_item_cells: Dictionary = {}
var stairs_discovered := false
var discovery_revision := 0
var presentation := preload("res://combat/battle_presentation.gd").new()
var reinforcements := ReinforcementSpawner.new()

@onready var dungeon = $Dungeon
@onready var turns = $TurnManager
@onready var rapid_move: RapidMoveController = $RapidMove
@onready var hud = $HUD
@onready var camera: Camera2D = $Camera2D
@onready var ability_choice = $AbilityChoice
@onready var inventory_panel = $InventoryPanel
@onready var result_panel = $RunResult


func _ready() -> void:
	transition_dialog = ConfirmationDialog.new()
	transition_dialog.title = "探索の選択"
	transition_dialog.ok_button_text = "はい"
	transition_dialog.cancel_button_text = "いいえ"
	add_child(transition_dialog)
	transition_dialog.confirmed.connect(func(): resolve_transition(true))
	transition_dialog.canceled.connect(func(): resolve_transition(false))
	dungeon.add_child(presentation)
	presentation.finished.connect(_refresh)
	if generation_seed == 0:
		rng.randomize()
	else:
		rng.seed = generation_seed
	var player := PLAYER_SCENE.instantiate()
	dungeon.get_node("Actors").add_child(player)
	turns.player = player
	progression.settings = level_settings
	turns.progression = progression
	if generation_seed != 0:
		player.abilities.rng.seed = generation_seed
	player.weapon = starting_weapon
	if initial_state != null:
		carryover = initial_state
		carryover.restore(player)
		turns.gold = carryover.gold
	player.action_requested.connect(_on_action)
	player.aim_changed.connect(_on_aim_changed)
	rapid_move.step_requested.connect(_on_rapid_step)
	preview = PREVIEW.new()
	preview.tile_size = dungeon.TILE_SIZE
	dungeon.add_child(preview)
	turns.turn_finished.connect(_on_turn_finished)
	turns.boss_defeated.connect(_on_boss_defeated)
	turns.enemy_defeated.connect(_drop_enemy_loot)
	turns.summon_requested.connect(_summon_enemy)
	turns.ability_choice_requested.connect(_show_ability_choice)
	ability_choice.selected.connect(_choose_ability)
	turns.player_moved.connect(_collect_items)
	inventory_panel.action_requested.connect(_inventory_action)
	inventory_panel.close_requested.connect(_close_inventory)
	result_panel.retry_requested.connect(retry_run)
	result_panel.return_to_hub = initial_state != null
	result_panel.abort_confirmed.connect(func(): finish_run(false))
	result_panel.abort_cancelled.connect(_cancel_abort)
	_load_floor()
	_refresh()


func _load_floor() -> void:
	turns.player.active_effects.change_floor()
	turns.player.refresh_equipment_effects()
	turns.floor_turn_count = 0
	turns.boss_reward_claimed = false
	floor_limit = dungeon_settings.floor_turn_limit
	exit_cell = Vector2i(-1, -1)
	last_prompt_cell = exit_cell
	warning_marks.clear()
	if presentation.finished.is_connected(_present_result):
		presentation.finished.disconnect(_present_result)
	if presentation.finished.is_connected(_present_ability_choice):
		presentation.finished.disconnect(_present_ability_choice)
	presentation.clear()
	reinforcements.reset(turns.turn_count)
	rapid_move.stop()
	turns.player.reset_step()
	discovered_item_cells.clear()
	stairs_discovered = false
	discovery_revision += 1
	# Preserve the player node (HP and weapon); release only the previous enemies.
	for enemy: Node2D in turns.enemies:
		enemy.get_parent().remove_child(enemy)
		enemy.queue_free()
	turns.enemies.clear()
	dungeon.build(dungeon_settings, floor_number, rng, floor_number == final_floor)
	turns.grid = dungeon.grid
	turns.player.aiming = false
	dungeon.grid.place(turns.player, dungeon.start_cell)
	for cell: Vector2i in dungeon.enemy_cells:
		var enemy := ENEMY_SCENE.instantiate()
		enemy.stats = ENEMY_TYPES[(floor_number - 1 + turns.enemies.size()) % ENEMY_TYPES.size()]
		_make_elite(enemy)
		dungeon.get_node("Actors").add_child(enemy)
		dungeon.grid.place(enemy, cell)
		turns.enemies.append(enemy)
	if floor_number % 10 == 0 or floor_number == final_floor:
		# The unused exit is the farthest reachable cell, never an enemy spawn.
		var boss := ENEMY_SCENE.instantiate()
		boss.stats = preload("res://data/enemies/boss.tres")
		dungeon.get_node("Actors").add_child(boss)
		dungeon.grid.place(boss, dungeon.stairs_cell)
		turns.enemies.append(boss)
	dungeon.spawn_items(dungeon_settings, floor_number, rng)
	turns.last_message = "%dFに到着。金色の階段から次の階へ進めます。" % floor_number
	if floor_number == final_floor:
		turns.last_message = "%dF：深層の守護者を倒すとクリアです。中断確認はR。" % final_floor


func _on_turn_finished() -> void:
	inventory_panel.hide()
	ability_choice.dismiss()
	if turns.ended:
		finish_run(false)
		return
	if turns.player.cell != last_prompt_cell:
		last_prompt_cell = Vector2i(-1, -1)
	if turns.moved_this_turn and turns.player.cell != last_prompt_cell:
		if dungeon.has_stairs and turns.player.cell == dungeon.stairs_cell:
			_request_transition("stairs")
		elif turns.player.cell == exit_cell:
			_request_transition("exit")
	if transition_kind.is_empty() and _check_floor_limit():
		return
	_spawn_reinforcement()
	_refresh()


func _on_boss_defeated() -> void:
	if floor_number == final_floor:
		finish_run(true)
		return
	floor_limit += dungeon_settings.boss_grace_turns
	exit_cell = dungeon.start_cell
	dungeon.escape_cell = exit_cell
	turns.last_message += " 中ボス撃破！入口に脱出口が出現。滞在猶予 +%dターン。" % dungeon_settings.boss_grace_turns


func _request_transition(kind: String) -> void:
	rapid_move.stop()
	transition_kind = kind
	last_prompt_cell = turns.player.cell
	turns.paused = true
	transition_dialog.dialog_text = "次の階へ降りますか？" if kind == "stairs" else "アイテムを失わずに帰還しますか？"
	transition_dialog.popup_centered(Vector2i(460, 160))


func resolve_transition(accepted: bool) -> void:
	if transition_kind.is_empty() or turns.ended:
		return
	var kind := transition_kind
	transition_kind = ""
	transition_dialog.hide()
	turns.paused = false
	if accepted:
		if kind == "stairs":
			floor_number += 1
			_load_floor()
		else:
			finish_run(false, true)
			return
	if not _check_floor_limit():
		_refresh()


func _check_floor_limit() -> bool:
	var remaining: int = floor_limit - turns.floor_turn_count
	if remaining <= 0:
		finish_run(false, false, true)
		return true
	for percent in [30, 20, 10]:
		var threshold: int = dungeon_settings.floor_turn_limit * percent / 100
		if remaining <= threshold and not warning_marks.has(percent):
			warning_marks.append(percent)
			turns.last_message += " ダンジョンの様子が変だ……残り%dターン。" % remaining
	if remaining <= 100 and not warning_marks.has(0):
		warning_marks.append(0)
		turns.last_message += " もう無理だ！あと%dターンで強制帰還になる！" % remaining
	return false


func _spawn_reinforcement() -> void:
	# Use visibility after this turn's movement, and spawn after enemies acted.
	dungeon.update_visibility(turns.player.cell, turns.player.vision_range)
	var cell := reinforcements.try_spawn(dungeon.grid, turns.player.cell, dungeon.fog.visible,
		turns.enemies, dungeon.stairs_cell, dungeon_settings, turns.turn_count,
		floor_number, rng, dungeon.ground_items)
	if cell == ReinforcementSpawner.NO_CELL:
		return
	var enemy := ENEMY_SCENE.instantiate()
	enemy.stats = ENEMY_TYPES[rng.randi_range(0, ENEMY_TYPES.size() - 1)]
	_make_elite(enemy)
	dungeon.get_node("Actors").add_child(enemy)
	dungeon.grid.place(enemy, cell)
	turns.enemies.append(enemy)


func _show_ability_choice() -> void:
	rapid_move.stop()
	inventory_panel.hide()
	_refresh()
	if presentation.playing:
		if not presentation.finished.is_connected(_present_ability_choice):
			presentation.finished.connect(_present_ability_choice, CONNECT_ONE_SHOT)
	else:
		_present_ability_choice()


func _present_ability_choice() -> void:
	if turns.ended or turns.offered_abilities.is_empty():
		return
	ability_choice.present(turns.offered_abilities, turns.player.abilities, progression.level, progression.pending_choices)


func _choose_ability(id: StringName) -> void:
	turns.choose_ability(id)


func _on_action(kind: String, direction: Vector2i) -> void:
	rapid_move.stop()
	var origin: Vector2i = turns.player.cell
	var destination := origin + direction
	var destination_was_explored: bool = dungeon.fog.explored.has(destination)
	var destination_had_item: bool = dungeon.ground_items.has(destination)
	var floor_before := floor_number
	var discovery_before := discovery_revision
	var succeeded: bool = turns.submit(kind, direction)
	if kind == "move" and succeeded:
		if floor_number == floor_before:
			turns.player.play_step(direction, dungeon.TILE_SIZE)
		if _can_arm_after_move(origin, direction, destination_was_explored, destination_had_item, floor_before, discovery_before):
			rapid_move.arm(direction)
	elif kind == "switch" and succeeded:
		# Free equipment changes still need immediate HUD and preview updates.
		_refresh()
	elif not succeeded:
		_refresh()


func _on_rapid_step(direction: Vector2i) -> void:
	if _rapid_step_blocked(direction):
		rapid_move.stop()
		return
	var origin: Vector2i = turns.player.cell
	var destination := origin + direction
	var floor_before := floor_number
	var discovery_before := discovery_revision
	var destination_had_item: bool = dungeon.ground_items.has(destination)
	if not turns.submit("move", direction):
		rapid_move.stop()
		_refresh()
		return
	if floor_number == floor_before:
		turns.player.play_step(direction, dungeon.TILE_SIZE)
	if not _can_arm_after_move(origin, direction, true, destination_had_item, floor_before, discovery_before):
		rapid_move.stop()


func _rapid_step_blocked(direction: Vector2i) -> bool:
	if not _world_input_available() or _has_visible_enemy():
		return true
	var destination: Vector2i = turns.player.cell + direction
	if not dungeon.fog.explored.has(destination):
		return true
	if dungeon.has_stairs and destination == dungeon.stairs_cell:
		return true
	if dungeon.ground_items.has(destination):
		return true
	return not dungeon.grid.can_step(turns.player.cell, destination) or dungeon.grid.occupants.has(destination)


func _can_arm_after_move(origin: Vector2i, direction: Vector2i, destination_was_explored: bool, destination_had_item: bool, floor_before: int, discovery_before: int) -> bool:
	if floor_number != floor_before or not destination_was_explored or destination_had_item:
		return false
	if discovery_revision != discovery_before or not _world_input_available() or _has_visible_enemy():
		return false
	return not _entered_branch(origin, origin + direction, direction)


func _world_input_available() -> bool:
	return not presentation.playing and not turns.busy and not turns.ended and not turns.paused and turns.player.hp > 0 \
		and not inventory_panel.visible and not ability_choice.visible and not result_panel.visible \
		and not turns.player.aiming


func _has_visible_enemy() -> bool:
	for enemy: Node2D in turns.enemies:
		if enemy.hp > 0 and dungeon.fog.visible.has(enemy.cell):
			return true
	return false


func _entered_branch(origin: Vector2i, destination: Vector2i, direction: Vector2i) -> bool:
	if _terrain_exit_count(origin) > 2:
		return false
	return _terrain_exit_count(destination, -direction) >= 2


func _terrain_exit_count(cell: Vector2i, excluded_direction := Vector2i.ZERO) -> int:
	var count := 0
	for direction: Vector2i in MOVE_DIRECTIONS:
		if direction != excluded_direction and dungeon.grid.can_step(cell, cell + direction):
			count += 1
	return count


func _on_aim_changed() -> void:
	rapid_move.stop()
	_refresh()


func _refresh() -> void:
	turns.player.input_enabled = not turns.busy and not turns.ended and not turns.paused and not inventory_panel.visible
	dungeon.sync_actors()
	dungeon.update_visibility(turns.player.cell, turns.player.vision_range)
	var events: Array[Dictionary] = dungeon.grid.visual_events.duplicate()
	dungeon.grid.visual_events.clear()
	presentation.present(events, turns.player, dungeon.fog.visible, dungeon.TILE_SIZE)
	turns.player.input_enabled = turns.player.input_enabled and not presentation.playing
	_record_discoveries()
	camera.global_position = turns.player.global_position
	camera.force_update_scroll()
	var visible_enemies := 0
	for enemy: Node2D in turns.enemies:
		enemy.visible = enemy.hp > 0 and dungeon.fog.visible.has(enemy.cell)
		if enemy.visible:
			visible_enemies += 1
	hud.refresh(turns.player.hp, turns.player.stats.max_hp, turns.turn_count, visible_enemies, turns.last_message, floor_number, dungeon.layout_name, dungeon.terrain_theme_name, final_floor)
	hud.show_progress(progression.level, progression.exp, progression.required_exp())
	preview.cells.clear()
	for cell: Vector2i in CombatRules.attack_cells(dungeon.grid, turns.player.cell, turns.player.facing, turns.player.effective_weapon()):
		if dungeon.fog.visible.has(cell):
			preview.cells.append(cell)
	preview.visible = turns.player.aiming and not turns.ended and not turns.busy
	preview.queue_redraw()
	hud.show_aim(turns.player.weapon.display_name, preview.visible)
	hud.show_inventory(turns.player.inventory.entries.size())
	hud.show_effects(turns.player.active_effects.summary())
	hud.show_gold(turns.gold)
	hud.show_equipment(turns.player.equipment)
	var visible_enemy_cells: Array[Vector2i] = []
	for enemy: Node2D in turns.enemies:
		if enemy.visible:
			visible_enemy_cells.append(enemy.cell)
	var discovered_items: Array[Vector2i] = []
	for item_cell: Vector2i in dungeon.ground_items:
		if dungeon.fog.explored.has(item_cell):
			discovered_items.append(item_cell)
	var known_stairs: Vector2i = dungeon.stairs_cell if stairs_discovered else Vector2i(-1, -1)
	hud.show_minimap(dungeon.grid, dungeon.fog.explored, dungeon.fog.visible, turns.player.cell, known_stairs, visible_enemy_cells, discovered_items)
	var boss_text := ""
	for enemy: Node2D in turns.enemies:
		if enemy.stats.is_boss and enemy.visible:
			boss_text = "%s  HP %d / %d" % [enemy.stats.display_name, enemy.hp, enemy.stats.max_hp]
	hud.show_boss(boss_text)


func _record_discoveries() -> void:
	var found_something := false
	for cell: Vector2i in dungeon.ground_items:
		if dungeon.fog.visible.has(cell) and not discovered_item_cells.has(cell):
			discovered_item_cells[cell] = true
			found_something = true
	if dungeon.has_stairs and dungeon.fog.visible.has(dungeon.stairs_cell) and not stairs_discovered:
		stairs_discovered = true
		found_something = true
	if found_something:
		discovery_revision += 1
		rapid_move.stop()


func _collect_items() -> void:
	var message: String = dungeon.collect_items(turns.player)
	turns.last_message += message
	if not message.is_empty():
		var center: Vector2 = Vector2(turns.player.cell * dungeon.TILE_SIZE) + Vector2.ONE * dungeon.TILE_SIZE / 2.0
		var feedback := message.replace(" 所持上限のため残りは床に置いたままです。", "\n収納がいっぱい（残りは床）").strip_edges()
		presentation.popup(feedback, center + Vector2(0, 34), Color("9de3c3"), 16)
		if message.contains("取得"):
			presentation.sound(880)


func _inventory_action(kind: String, index: int, slot: int) -> void:
	if not inventory_panel.visible:
		return
	rapid_move.stop()
	var succeeded: bool = turns.submit_inventory(kind, index, slot)
	if not succeeded or inventory_panel.visible:
		inventory_panel.refresh(turns.last_message)
		_refresh()


func _close_inventory() -> void:
	rapid_move.stop()
	inventory_panel.hide()
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if result_panel.visible:
		# Handle input before Hub navigation can remove this Run from the tree.
		if event is InputEventKey or event is InputEventAction:
			get_viewport().set_input_as_handled()
		if result_panel.confirming and event.is_action_pressed("cancel_attack"):
			_cancel_abort()
		elif not result_panel.confirming and event.is_action_pressed("restart"):
			retry_run()
		return
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		if presentation.playing or turns.busy or turns.ended or turns.paused:
			return
		if inventory_panel.visible:
			_close_inventory()
		else:
			rapid_move.stop()
			turns.player.aiming = false
			inventory_panel.present(turns.player)
			_refresh()
	elif inventory_panel.visible and event.is_action_pressed("cancel_attack"):
		get_viewport().set_input_as_handled()
		_close_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not event.is_echo():
		get_viewport().set_input_as_handled()
		request_abort()


func request_abort() -> void:
	if presentation.playing or turns.busy or turns.ended or turns.paused or result_panel.visible:
		return
	rapid_move.stop()
	inventory_panel.hide()
	turns.player.aiming = false
	turns.paused = true
	result_panel.confirm_abort()
	_refresh()


func _cancel_abort() -> void:
	if not result_panel.confirming or turns.ended:
		return
	result_panel.hide()
	turns.paused = false
	_refresh()


func finish_run(cleared: bool, safe_return: bool = false, forced_return: bool = false) -> void:
	# Idempotence is essential: callbacks and repeated input cannot apply loss twice.
	if not result.is_empty():
		return
	rapid_move.stop()
	turns.player.reset_step()
	turns.ended = true
	turns.busy = false
	turns.paused = false
	turns.player.aiming = false
	turns.offered_abilities.clear()
	inventory_panel.hide()
	ability_choice.dismiss()
	result = {"gold_lost": 0, "items_lost": {}, "item_count_lost": 0}
	transition_dialog.hide()
	transition_kind = ""
	if not cleared and not safe_return:
		result = RunLoss.apply(turns.player.inventory, turns.gold, loss_rng)
	turns.gold -= int(result.gold_lost)
	result.merge({"cleared": cleared, "safe_return": safe_return, "forced_return": forced_return, "floor": floor_number, "earned_gold": turns.earned_gold, "gold": turns.gold})
	turns.player.active_effects.effects.clear()
	turns.player.refresh_equipment_effects()
	carryover.capture(turns.player, turns.gold)
	_refresh()
	if presentation.playing:
		presentation.finished.connect(_present_result, CONNECT_ONE_SHOT)
	else:
		_present_result()
	result_ready.emit()


func _present_result() -> void:
	if turns.ended and not result.is_empty():
		result_panel.present(result)


func retry_run() -> void:
	if result.is_empty():
		return
	if initial_state != null:
		hub_requested.emit()
		return
	rapid_move.stop()
	result_panel.hide()
	var old_player: Node2D = turns.player
	old_player.get_parent().remove_child(old_player)
	old_player.queue_free()
	var player := PLAYER_SCENE.instantiate()
	dungeon.get_node("Actors").add_child(player)
	turns.player = player
	carryover.restore(player)
	player.action_requested.connect(_on_action)
	player.aim_changed.connect(_on_aim_changed)
	progression = RunProgression.new()
	progression.settings = level_settings
	turns.progression = progression
	turns.gold = carryover.gold
	turns.earned_gold = 0
	turns.turn_count = 0
	turns.ended = false
	turns.busy = false
	turns.paused = false
	result = {}
	floor_number = 1
	hud.reset_log()
	_load_floor()
	_refresh()


func _make_elite(enemy: Node2D) -> void:
	if rng.randf() >= dungeon_settings.elite_chance:
		return
	enemy.stats = enemy.stats.duplicate()
	enemy.stats.elite = true
	enemy.stats.max_hp += 3
	enemy.stats.attack += 1
	enemy.stats.exp_reward += 5
	enemy.stats.display_name = "精鋭 " + enemy.stats.display_name


func _drop_enemy_loot(enemy: Node2D) -> void:
	if not enemy.stats.elite or rng.randf() >= dungeon_settings.accessory_drop_chance:
		return
	var candidates: Array[Vector2i] = [enemy.cell]
	for direction in MOVE_DIRECTIONS:
		candidates.append(enemy.cell + direction)
	for cell in candidates:
		if dungeon.grid.in_bounds(cell) and not dungeon.grid.walls.has(cell) and not dungeon.ground_items.has(cell) and cell != dungeon.stairs_cell:
			var items := ItemCatalog.talismans()
			dungeon.ground_items[cell] = InventoryEntry.new(items[rng.randi_range(0, items.size() - 1)])
			return


func _summon_enemy(source: Node2D) -> void:
	var alive := 0
	for enemy: Node2D in turns.enemies:
		if enemy.hp > 0 and enemy.summoner == source:
			alive += 1
	if alive >= source.stats.summon_cap:
		return
	for direction in MOVE_DIRECTIONS:
		var cell: Vector2i = source.cell + direction
		if not dungeon.grid.can_step(source.cell, cell) or dungeon.grid.occupants.has(cell) or cell == dungeon.stairs_cell:
			continue
		var enemy := ENEMY_SCENE.instantiate()
		enemy.stats = preload("res://data/enemies/charge_enemy.tres")
		enemy.summoner = source
		dungeon.get_node("Actors").add_child(enemy)
		dungeon.grid.place(enemy, cell)
		turns.enemies.append(enemy)
		turns.last_message += " 突進獣が召喚された！"
		return

extends Node2D

signal hub_requested
signal result_ready

const PLAYER_SCENE := preload("res://actors/player/player.tscn")
const ENEMY_SCENE := preload("res://actors/enemy/enemy.tscn")
const PREVIEW := preload("res://combat/attack_preview.gd")
const FINAL_FLOOR := 10
const MOVE_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP, Vector2i(1, -1), Vector2i.RIGHT, Vector2i(1, 1),
	Vector2i.DOWN, Vector2i(-1, 1), Vector2i.LEFT, Vector2i(-1, -1),
]
const ENEMY_TYPES: Array[EnemyStats] = [
	preload("res://data/enemies/basic_enemy.tres"),
	preload("res://data/enemies/proximity_enemy.tres"),
	preload("res://data/enemies/turret_enemy.tres"),
]

@export var starting_weapon: WeaponData = preload("res://data/weapons/sword.tres")
@export var dungeon_settings: DungeonSettings = preload("res://data/dungeon/default.tres")
@export var level_settings: LevelSettings = preload("res://data/progression/levels.tres")
## Zero selects a fresh random seed. Nonzero seeds reproduce layouts for testing.
@export var generation_seed: int = 0
var preview: Node2D
var floor_number := 1
var rng := RandomNumberGenerator.new()
var progression := RunProgression.new()
var carryover := RunCarryover.new()
var initial_state: RunCarryover
var result: Dictionary = {}
var loss_rng := RandomNumberGenerator.new()
var discovered_item_cells: Dictionary = {}
var stairs_discovered := false
var discovery_revision := 0

@onready var dungeon = $Dungeon
@onready var turns = $TurnManager
@onready var rapid_move: RapidMoveController = $RapidMove
@onready var hud = $HUD
@onready var camera: Camera2D = $Camera2D
@onready var ability_choice = $AbilityChoice
@onready var inventory_panel = $InventoryPanel
@onready var result_panel = $RunResult


func _ready() -> void:
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
	turns.boss_defeated.connect(func(): finish_run(true))
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
	rapid_move.stop()
	discovered_item_cells.clear()
	stairs_discovered = false
	discovery_revision += 1
	# Preserve the player node (HP and weapon); release only the previous enemies.
	for enemy: Node2D in turns.enemies:
		enemy.get_parent().remove_child(enemy)
		enemy.queue_free()
	turns.enemies.clear()
	dungeon.build(dungeon_settings, floor_number, rng, floor_number == FINAL_FLOOR)
	turns.grid = dungeon.grid
	turns.player.aiming = false
	dungeon.grid.place(turns.player, dungeon.start_cell)
	for cell: Vector2i in dungeon.enemy_cells:
		var enemy := ENEMY_SCENE.instantiate()
		enemy.stats = ENEMY_TYPES[(floor_number - 1 + turns.enemies.size()) % ENEMY_TYPES.size()]
		dungeon.get_node("Actors").add_child(enemy)
		dungeon.grid.place(enemy, cell)
		turns.enemies.append(enemy)
	if floor_number == FINAL_FLOOR:
		# The unused exit is the farthest reachable cell, never an enemy spawn.
		var boss := ENEMY_SCENE.instantiate()
		boss.stats = preload("res://data/enemies/boss.tres")
		dungeon.get_node("Actors").add_child(boss)
		dungeon.grid.place(boss, dungeon.stairs_cell)
		turns.enemies.append(boss)
	dungeon.spawn_items(dungeon_settings, floor_number, rng)
	turns.last_message = "%dFに到着。金色の階段から次の階へ進めます。" % floor_number
	if floor_number == FINAL_FLOOR:
		turns.last_message = "10F：深層の守護者を倒すとクリアです。中断確認はR。"


func _on_turn_finished() -> void:
	inventory_panel.hide()
	ability_choice.dismiss()
	if turns.ended:
		finish_run(false)
		return
	# Old-floor enemies have already acted. Death takes precedence over stairs.
	if not turns.ended and dungeon.has_stairs and turns.player.cell == dungeon.stairs_cell:
		floor_number += 1
		_load_floor()
	_refresh()


func _show_ability_choice() -> void:
	rapid_move.stop()
	inventory_panel.hide()
	_refresh()
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
	return not turns.busy and not turns.ended and not turns.paused and turns.player.hp > 0 \
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
	_record_discoveries()
	camera.global_position = turns.player.global_position
	camera.force_update_scroll()
	var visible_enemies := 0
	for enemy: Node2D in turns.enemies:
		enemy.visible = enemy.hp > 0 and dungeon.fog.visible.has(enemy.cell)
		if enemy.visible:
			visible_enemies += 1
	hud.refresh(turns.player.hp, turns.player.stats.max_hp, turns.turn_count, visible_enemies, turns.last_message, floor_number, dungeon.layout_name)
	hud.show_progress(progression.level, progression.exp, progression.required_exp())
	preview.cells.clear()
	for cell: Vector2i in CombatRules.attack_cells(dungeon.grid, turns.player.cell, turns.player.facing, turns.player.effective_weapon()):
		if dungeon.fog.visible.has(cell):
			preview.cells.append(cell)
	preview.visible = turns.player.aiming and not turns.ended and not turns.busy
	preview.queue_redraw()
	hud.show_aim(turns.player.weapon.display_name, preview.visible)
	hud.show_inventory(turns.player.inventory.entries.size())
	hud.show_gold(turns.gold)
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
	turns.last_message += dungeon.collect_items(turns.player)


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
		if turns.busy or turns.ended:
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
	if turns.busy or turns.ended or result_panel.visible:
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


func finish_run(cleared: bool) -> void:
	# Idempotence is essential: callbacks and repeated input cannot apply loss twice.
	if not result.is_empty():
		return
	rapid_move.stop()
	turns.ended = true
	turns.busy = false
	turns.paused = false
	turns.player.aiming = false
	turns.offered_abilities.clear()
	inventory_panel.hide()
	ability_choice.dismiss()
	result = {"gold_lost": 0, "items_lost": {}, "item_count_lost": 0}
	if not cleared:
		result = RunLoss.apply(turns.player.inventory, turns.gold, loss_rng)
	turns.gold -= int(result.gold_lost)
	result.merge({"cleared": cleared, "floor": floor_number, "earned_gold": turns.earned_gold, "gold": turns.gold})
	carryover.capture(turns.player, turns.gold)
	_refresh()
	result_panel.present(result)
	result_ready.emit()


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
	_load_floor()
	_refresh()

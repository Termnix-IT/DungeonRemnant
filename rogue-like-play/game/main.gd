extends Node

@export var run_scene: PackedScene = preload("res://game/run/run.tscn")
@export var saving_enabled := true
var save_store := SaveStore.new()
var state := RunCarryover.new()
var active_run: Node2D


func _ready() -> void:
	# Script-only instances in rule tests only register input bindings.
	if not has_node("Hub"):
		return
	if saving_enabled:
		state = save_store.load_state()
	$Hub.start_requested.connect(start_run)
	$Hub.purchase_requested.connect(purchase_upgrade)
	$Hub.refresh(state)
	_update_save_status()


func purchase_upgrade() -> bool:
	if active_run != null or not has_node("Hub") or not $Hub.visible:
		return false
	var old_gold: int = state.gold
	var old_level: int = state.hp_upgrade_level
	var purchased := state.purchase_upgrade()
	if purchased and saving_enabled and not save_store.save_state(state):
		state.gold = old_gold
		state.hp_upgrade_level = old_level
		purchased = false
	$Hub.refresh(state, "最大HP強化を購入しました。" if purchased else "購入できません。Goldと強化上限を確認してください。")
	_update_save_status()
	return purchased


func start_run() -> void:
	if active_run != null or not has_node("Hub") or not $Hub.visible:
		return
	if saving_enabled and not save_store.save_state(state):
		_update_save_status()
		return
	$Hub.hide()
	active_run = run_scene.instantiate()
	active_run.name = "Run"
	active_run.initial_state = state
	active_run.hub_requested.connect(return_to_hub)
	active_run.result_ready.connect(_save_result)
	add_child(active_run)


func return_to_hub() -> void:
	if active_run == null or active_run.result.is_empty():
		return
	# Loss has already been applied by Run; never recalculate it here.
	state = active_run.carryover
	var finished := active_run
	active_run = null
	remove_child(finished)
	finished.queue_free()
	$Hub.refresh(state)
	$Hub.show()
	_update_save_status()


func _save_result() -> void:
	if saving_enabled:
		save_store.save_state(active_run.carryover)
		active_run.result_panel.show_save_status(save_store.message)


func _update_save_status() -> void:
	$Hub.save_label.text = save_store.message if saving_enabled else "テストモード：保存は無効です。"


func _enter_tree() -> void:
	# All gameplay keys use InputMap, including keypad diagonals.
	var bindings := {
		"move_n": [KEY_UP, KEY_W, KEY_KP_8],
		"move_ne": [KEY_E, KEY_KP_9],
		"move_e": [KEY_RIGHT, KEY_D, KEY_KP_6],
		"move_se": [KEY_C, KEY_KP_3],
		"move_s": [KEY_DOWN, KEY_S, KEY_KP_2],
		"move_sw": [KEY_Z, KEY_KP_1],
		"move_w": [KEY_LEFT, KEY_A, KEY_KP_4],
		"move_nw": [KEY_Q, KEY_KP_7],
		"attack": [KEY_SPACE, KEY_KP_5],
		"cancel_attack": [KEY_ESCAPE],
		"restart": [KEY_R],
		"inventory": [KEY_I],
		"switch_weapon": [KEY_TAB],
	}
	for action: String in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

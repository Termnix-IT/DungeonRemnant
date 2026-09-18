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
	$Hub.skill_requested.connect(purchase_skill)
	$Hub.entry_requested.connect(unlock_entry)
	$Hub.storage_transfer_requested.connect(transfer_storage)
	$Hub.equip_requested.connect(equip_item)
	$Hub.unequip_requested.connect(unequip_item)
	$Hub.swap_requested.connect(swap_weapons)
	$Hub.scroll_remove_requested.connect(unsocket_scroll)
	$Hub.sell_requested.connect(sell_item)
	$Hub.buy_requested.connect(buy_item)
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


func transfer_storage(from_storage: bool, index: int) -> bool:
	if active_run != null or not has_node("Hub") or not $Hub.visible:
		return false
	var previous_inventory := state.inventory.copy()
	var previous_storage := state.storage.copy()
	var source := state.storage if from_storage else state.inventory
	var destination := state.inventory if from_storage else state.storage
	var moved := state.transfer_item(source, destination, index)
	if moved == 0:
		$Hub.warehouse_panel.refresh(state, "移動できません。移動先の空き容量を確認してください。")
		return false
	if saving_enabled and not save_store.save_state(state):
		state.inventory = previous_inventory
		state.storage = previous_storage
		$Hub.warehouse_panel.refresh(state, "保存に失敗したため、アイテム移動を取り消しました。")
		_update_save_status()
		return false
	var action := "取り出しました" if from_storage else "預けました"
	$Hub.refresh(state)
	$Hub.warehouse_panel.refresh(state, "%d個%s。" % [moved, action])
	_update_save_status()
	return true


func equip_item(from_storage: bool, index: int, slot: int) -> bool:
	var source := state.storage if from_storage else state.inventory
	if index >= 0 and index < source.entries.size() and source.entries[index].item.kind == ItemData.Kind.SCROLL:
		return _prepare(func() -> bool: return state.equipment.socket(source, index, slot), "魔法を装着しました。")
	return _prepare(func() -> bool: return state.equipment.equip(state.storage if from_storage else state.inventory, index, slot), "装備を変更しました。交換前の装備は選択元に戻しました。")


func unequip_item(slot: int) -> bool:
	return _prepare(func() -> bool: return state.equipment.unequip(state.inventory, slot), "装備を外し、持ち込み所持品に戻しました。")


func sell_item(from_storage: bool, index: int, amount: int) -> bool:
	return _prepare(func() -> bool: return state.sell_item(from_storage, index, amount), "%d個を売却しました。Goldに反映しました。" % amount)


func swap_weapons() -> bool:
	return _prepare(state.equipment.swap_weapons, "Main / Sub Weaponを入れ替えました。")


func buy_item(to_storage: bool, item_id: StringName, amount: int) -> bool:
	return _prepare(func() -> bool: return state.buy_item(to_storage, item_id, amount), "%d個購入し、%sへ入れました。" % [amount, "倉庫" if to_storage else "持ち込み所持品"])


func _prepare(action: Callable, success_message: String) -> bool:
	if active_run != null or not has_node("Hub") or not $Hub.visible:
		return false
	var previous_inventory := state.inventory.copy()
	var previous_storage := state.storage.copy()
	var previous_slots := state.equipment.slots.duplicate()
	var previous_gold := state.gold
	var previous_skills := state.skill_levels.duplicate(true)
	var previous_entries := state.unlocked_entries.duplicate(true)
	var succeeded: bool = action.call()
	var message := success_message if succeeded else "変更できません。選択した品・Gold・空き容量を確認してください。"
	if succeeded and saving_enabled and not save_store.save_state(state):
		state.inventory = previous_inventory
		state.storage = previous_storage
		state.equipment.slots.assign(previous_slots)
		state.gold = previous_gold
		state.skill_levels = previous_skills
		state.unlocked_entries = previous_entries
		succeeded = false
		message = "保存に失敗したため、変更を取り消しました。"
	$Hub.refresh(state, message)
	_update_save_status()
	return succeeded


func start_run() -> void:
	if active_run != null or not has_node("Hub") or not $Hub.visible:
		return
	var stage: StageData = $Hub.departure_page.selected_stage
	if stage == null:
		stage = preload("res://data/stages/ancient_ruins.tres")
	var entry_floor: int = $Hub.departure_page.starting_floor
	if not state.can_start(stage, entry_floor) or stage.settings == null or stage.floor_count < 1:
		return
	if saving_enabled and not save_store.save_state(state):
		_update_save_status()
		return
	$Hub.warehouse_panel.close()
	$Hub.hide()
	active_run = run_scene.instantiate()
	active_run.name = "Run"
	active_run.initial_state = state
	if stage != null:
		active_run.stage_data = stage
		active_run.starting_floor = entry_floor
		active_run.dungeon_settings = stage.settings
		active_run.final_floor = stage.floor_count
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
	$Hub.show_page("home")
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


func unsocket_scroll(slot: int) -> bool:
	return _prepare(func() -> bool: return state.equipment.unsocket(state.inventory, slot), "魔法を取り外し、所持品に戻しました。")


func purchase_skill(id: StringName) -> bool:
	return _prepare(func() -> bool: return state.purchase_skill(id), "スキルを強化しました。")


func unlock_entry(stage: StageData, floor_number: int) -> bool:
	return _prepare(func() -> bool: return state.unlock_entry(stage, floor_number), "%dFからの途中開始を解放しました。" % floor_number)

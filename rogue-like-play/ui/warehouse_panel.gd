class_name WarehousePanel
extends Control

signal transfer_requested(from_storage: bool, index: int)
signal closed
signal equipment_requested

var state: RunCarryover
var inventory_index := -1
var storage_index := -1


func _ready() -> void:
	hide()
	$Panel/InventoryList.item_selected.connect(_select_inventory)
	$Panel/StorageList.item_selected.connect(_select_storage)
	$Panel/Deposit.pressed.connect(func(): transfer_requested.emit(false, inventory_index))
	$Panel/Withdraw.pressed.connect(func(): transfer_requested.emit(true, storage_index))
	$Panel/Close.pressed.connect(close)
	$Panel/Equipment.pressed.connect(func(): close(); equipment_requested.emit())


func present(current_state: RunCarryover) -> void:
	state = current_state
	inventory_index = -1
	storage_index = -1
	refresh()
	show()
	$Panel/InventoryList.grab_focus()


func refresh(current_state: RunCarryover = state, message: String = "") -> void:
	state = current_state
	$Panel/Gold.text = "Gold  %d" % state.gold
	$Panel/InventoryTitle.text = "持ち込みInventory  %d / %d枠" % [state.inventory.entries.size(), state.inventory.max_entries]
	$Panel/StorageTitle.text = "倉庫  %d / %d枠" % [state.storage.entries.size(), state.storage.max_entries]
	_fill_list($Panel/InventoryList, state.inventory)
	_fill_list($Panel/StorageList, state.storage)
	if inventory_index >= state.inventory.entries.size():
		inventory_index = -1
	if storage_index >= state.storage.entries.size():
		storage_index = -1
	if inventory_index >= 0:
		$Panel/InventoryList.select(inventory_index)
	if storage_index >= 0:
		$Panel/StorageList.select(storage_index)
	$Panel/Deposit.disabled = inventory_index < 0
	$Panel/Withdraw.disabled = storage_index < 0
	$Panel/Feedback.text = message


func close() -> void:
	hide()
	closed.emit()


func _fill_list(list: ItemList, inventory: Inventory) -> void:
	list.clear()
	for entry: InventoryEntry in inventory.entries:
		list.add_item("%s  ×%d" % [entry.item.display_name, entry.count])
		list.set_item_tooltip(list.item_count - 1, entry.item.description())


func _select_inventory(index: int) -> void:
	inventory_index = index
	storage_index = -1
	$Panel/StorageList.deselect_all()
	$Panel/Deposit.disabled = false
	$Panel/Withdraw.disabled = true


func _select_storage(index: int) -> void:
	storage_index = index
	inventory_index = -1
	$Panel/InventoryList.deselect_all()
	$Panel/Deposit.disabled = true
	$Panel/Withdraw.disabled = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

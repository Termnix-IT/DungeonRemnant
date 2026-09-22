class_name WarehousePanel
extends Control

signal transfer_requested(from_storage: bool, index: int)
signal closed
signal equipment_requested

var state: RunCarryover
var inventory_index := -1
var storage_index := -1


func _ready() -> void:
	_resize()
	get_viewport().size_changed.connect(_resize)
	$Panel.minimum_size_changed.connect(_resize.call_deferred)
	hide()
	%InventoryList.item_selected.connect(_select_inventory)
	%StorageList.item_selected.connect(_select_storage)
	%Deposit.pressed.connect(func(): transfer_requested.emit(false, inventory_index))
	%Withdraw.pressed.connect(func(): transfer_requested.emit(true, storage_index))
	%Close.pressed.connect(close)
	%Equipment.pressed.connect(func(): close(); equipment_requested.emit())


func present(current_state: RunCarryover) -> void:
	state = current_state
	inventory_index = -1
	storage_index = -1
	refresh()
	show()
	_resize.call_deferred()
	UIMotion.of($Panel).reveal(UIMotion.WINDOW_TIME)
	%InventoryList.grab_focus()


func refresh(current_state: RunCarryover = state, message: String = "") -> void:
	state = current_state
	for target: Control in [%InventoryList, %StorageList, %Help, %Visual, %Direction]:
		UIMotion.of(target).reset()
	%Gold.text = "Gold  %d" % state.gold
	%InventoryTitle.text = "所持品  %d / %d枠" % [state.inventory.entries.size(), state.inventory.max_entries]
	%StorageTitle.text = "倉庫  %d / %d枠" % [state.storage.entries.size(), state.storage.max_entries]
	_fill_list(%InventoryList, state.inventory)
	_fill_list(%StorageList, state.storage)
	if inventory_index >= state.inventory.entries.size():
		inventory_index = -1
	if storage_index >= state.storage.entries.size():
		storage_index = -1
	if inventory_index >= 0:
		%InventoryList.select(inventory_index)
	if storage_index >= 0:
		%StorageList.select(storage_index)
	%Deposit.disabled = inventory_index < 0
	%Withdraw.disabled = storage_index < 0
	%Feedback.text = message
	_update_details()


func close() -> void:
	hide()
	closed.emit()


func _fill_list(list: ItemList, inventory: Inventory) -> void:
	list.clear()
	for entry: InventoryEntry in inventory.entries:
		(list as ItemCardList).add_card(entry.item, entry.count)
		list.set_item_tooltip(list.item_count - 1, ItemTooltipList.description(entry.item))


func _select_inventory(index: int) -> void:
	inventory_index = index
	storage_index = -1
	%StorageList.deselect_all()
	UIMotion.of(%StorageList).reset()
	%Deposit.disabled = false
	%Withdraw.disabled = true
	_update_details()
	UIMotion.reveal_selection([%Help, %Visual, %Direction])


func _select_storage(index: int) -> void:
	storage_index = index
	inventory_index = -1
	%InventoryList.deselect_all()
	UIMotion.of(%InventoryList).reset()
	%Deposit.disabled = true
	%Withdraw.disabled = false
	_update_details()
	UIMotion.reveal_selection([%Help, %Visual, %Direction])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _update_details() -> void:
	var details := %Help as ItemDetails
	details.reset()
	var source := state.storage if storage_index >= 0 else state.inventory
	var index := storage_index if storage_index >= 0 else inventory_index
	if index >= 0 and index < source.entries.size():
		var item := source.entries[index].item
		%Visual.item = item
		%Direction.text = "倉庫 → 所持品" if storage_index >= 0 else "所持品 → 倉庫"
		details.line(item.label(), &"HeadingLabel")
		details.line(ItemGlyph.category(item), &"MutedLabel")
		details.line(item.description())
		details.line("選択数 ×%d" % source.entries[index].count, &"GoldLabel")
	else:
		%Visual.item = null
		%Direction.text = "移動するアイテム"
	details.line("倉庫の品は冒険へ持ち込まず、死亡・中断でも失いません。", &"MutedLabel")


func _resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(1.0, minf((viewport.x - 40) / 1280.0, (viewport.y - 40) / 650.0))
	$Panel.size = Vector2(1280, 650)
	$Panel.scale = Vector2.ONE * factor
	$Panel.position = (viewport - $Panel.size * factor) / 2

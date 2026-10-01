class_name WarehousePanel
extends Control

signal transfer_requested(from_storage: bool, index: int)
signal closed
signal equipment_requested

var state: RunCarryover
var inventory_index := -1
var storage_index := -1
# The item of the last requested move, for the success moment after saving.
var moved_item: ItemData


# The transfer column's art box; the 48px icon draws at 3x (144px) inside.
const VISUAL_SIZE := 176.0
const STORAGE_NOTE := "倉庫の品は冒険へ持ち込まず、死亡・中断でも失いません。"

func _ready() -> void:
	# The transfer column matches the equipment page: the item at 3x its icon,
	# centred, with its name and count beneath.
	(%Help as ItemDetails).centered = true
	# Set here: ItemVisual's own _init would override a size from the scene.
	%Visual.custom_minimum_size = Vector2.ONE * VISUAL_SIZE
	# The one-stack rule sits on the buttons, leaving the column's height to
	# the item; the list rows already name each item's kind.
	for button: Button in [%Deposit, %Withdraw]:
		button.tooltip_text = "選択した1スタックをまとめて移動"
	_resize()
	get_viewport().size_changed.connect(_resize)
	$Panel.minimum_size_changed.connect(_resize.call_deferred)
	hide()
	%InventoryList.item_selected.connect(_select_inventory)
	%StorageList.item_selected.connect(_select_storage)
	%Deposit.pressed.connect(func():
		moved_item = _entry_item(state.inventory, inventory_index)
		transfer_requested.emit(false, inventory_index))
	%Withdraw.pressed.connect(func():
		moved_item = _entry_item(state.storage, storage_index)
		transfer_requested.emit(true, storage_index))
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
	%Feedback.text = message if not message.is_empty() else STORAGE_NOTE
	# The standing rule is quiet; only a move's result reads in the body tone.
	%Feedback.theme_type_variation = &"BodyLabel" if not message.is_empty() else &"MutedLabel"
	_update_details()


func _entry_item(source: Inventory, index: int) -> ItemData:
	return source.entries[index].item if index >= 0 and index < source.entries.size() else null


# Success moment after saving: the moved item's glyph flies from the centre
# to its row in the destination list, which then acknowledges the arrival.
func present_move(to_storage: bool) -> void:
	var item := moved_item
	moved_item = null
	var list: ItemCardList = %StorageList if to_storage else %InventoryList
	if item == null or not is_visible_in_tree():
		UIMotion.of(list).reveal()
		return
	var destination := state.storage if to_storage else state.inventory
	var point := list.get_global_rect().get_center()
	for index in destination.entries.size():
		if destination.entries[index].item.id == item.id:
			var row := list.card_rect(index)
			# A row scrolled out of view, or not laid out yet, lands on the
			# list's centre instead.
			if row.size.x > 0 and row.size.y > 0 and Rect2(Vector2.ZERO, list.size).encloses(row):
				point = list.global_position + row.get_center()
			break
	UIMotion.fly_glyph_at(self, item, %Visual, point).finished.connect(func():
		if is_instance_valid(list) and list.is_visible_in_tree():
			UIMotion.of(list).reveal())


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
		details.line(item.description())
		details.line("選択数 ×%d" % source.entries[index].count, &"BodyLabel")
	else:
		%Visual.item = null
		%Direction.text = "移動するアイテム"


const PANEL_SIZE := Vector2(1440, 650)


func _resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(1.0, minf((viewport.x - 40) / PANEL_SIZE.x, (viewport.y - 40) / PANEL_SIZE.y))
	$Panel.size = PANEL_SIZE
	$Panel.scale = Vector2.ONE * factor
	$Panel.position = (viewport - $Panel.size * factor) / 2

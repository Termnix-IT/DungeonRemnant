class_name HubWarehouse
extends Control

# The warehouse page: one dark slab from the screen's left edge to its right,
# what she carries on the left, the warehouse on the right, and between them,
# where the slab thins to a veil over the hall, the chosen goods, which way
# they would go and the one move action. Both lists' bands point at the
# middle. Leaving is the back key.

signal transfer_requested(from_storage: bool, index: int)
signal equipment_requested

const STORAGE_NOTE := "倉庫の品は冒険へ持ち込まず、死亡・中断でも失いません。"
const SHOWCASE_SIZE := 192.0

var state: RunCarryover
var inventory_index := -1
var storage_index := -1
# The item of the last requested move, for the success moment after saving.
var moved_item: ItemData
var inventory_list: ItemCardList
var storage_list: ItemCardList
var inventory_title: Label
var storage_title: Label
var direction: Label
var showcase: ItemShowcase
var details: ItemDetails
var result_label: Label
var amount_label: Label
var change_label: Label
var move_button: Button
var equipment_link: Button
var _middle: VBoxContainer


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var carried := HubUI.open_column(columns, 1.0, &"SlabSolid")
	inventory_title = _stock_heading(carried, "持ち込み")
	inventory_list = _stock_list(carried, "持ち込みの品はない", false)
	inventory_list.item_selected.connect(_select_inventory)
	# Arranging what she wears is the equipment page's; here only the way there.
	HubUI.rule(carried)
	equipment_link = HubUI.button(carried, "装備を整える", func(): equipment_requested.emit(), &"TextAction")
	equipment_link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_middle = HubUI.open_column(columns, 0.9, &"SlabVeil")
	_build_middle(_middle)
	var kept := HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	storage_title = _stock_heading(kept, "倉庫")
	storage_list = _stock_list(kept, "倉庫に品はない", true)
	storage_list.item_selected.connect(_select_storage)
	HubUI.rule(kept)
	# As tall as the link across, so both feet share one line.
	var note := HubUI.label(kept, STORAGE_NOTE, &"NoteLabel")
	note.custom_minimum_size.y = 44
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HubUI.accept_to_action(inventory_list, move_button)
	HubUI.accept_to_action(storage_list, move_button)
	# Left and right step between the two stocks.
	inventory_list.gui_input.connect(_cross.bind(inventory_list))
	storage_list.gui_input.connect(_cross.bind(storage_list))


# A stock's name with its use beside it, quiet, above its list.
func _stock_heading(column: VBoxContainer, title: String) -> Label:
	column.theme_type_variation = &"DetailStack"
	var row := HBoxContainer.new()
	row.theme_type_variation = &"CompactRow"
	column.add_child(row)
	var name_label := HubUI.label(row, title, &"ItemNameLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var count := HubUI.label(row, "", &"NoteLabel")
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return count


func _stock_list(column: VBoxContainer, empty: String, points_left: bool) -> ItemCardList:
	var list := ItemCardList.new()
	list.theme_type_variation = &"OpenCardList"
	list.points_left = points_left
	list.empty_text = empty
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(list)
	return list


func _build_middle(column: VBoxContainer) -> void:
	column.theme_type_variation = &"DetailStack"
	direction = HubUI.label(column, "", &"NoteLabel")
	direction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	showcase = ItemShowcase.new()
	showcase.show_effect = false
	showcase.stack(SHOWCASE_SIZE)
	showcase.visual.framed = false
	showcase.visual.idle = true
	column.add_child(showcase)
	details = ItemDetails.new()
	details.centered = true
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(details)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	details.fit_lines(gap, 48)
	# The counter, as in the shop: how many go, one quiet line of what the
	# move does to both stocks, and a move's result, right above the action.
	HubUI.rule(column)
	var counter := VBoxContainer.new()
	counter.theme_type_variation = &"CompactStack"
	column.add_child(counter)
	var amount_row := HBoxContainer.new()
	counter.add_child(amount_row)
	var caption := HubUI.label(amount_row, "移動する数", &"NoteLabel")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label = HubUI.label(amount_row, "", &"ValueLabel")
	amount_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	change_label = HubUI.label(counter, "", &"NoteLabel")
	change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	result_label = HubUI.label(counter, "", &"BodyLabel")
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	move_button = HubUI.primary_action(column, "移動する", _move)
	move_button.tooltip_text = "選択した1スタックをまとめて移動"


func present(current_state: RunCarryover) -> void:
	inventory_index = -1
	storage_index = -1
	refresh(current_state)
	inventory_list.grab_focus()


func refresh(current_state: RunCarryover = state, message: String = "") -> void:
	state = current_state
	for target: Control in [inventory_list, storage_list, showcase, details, direction]:
		UIMotion.of(target).reset()
	inventory_title.text = "%d / %d 枠" % [state.inventory.entries.size(), state.inventory.max_entries]
	storage_title.text = "%d / %d 枠" % [state.storage.entries.size(), state.storage.max_entries]
	_fill_list(inventory_list, state.inventory)
	_fill_list(storage_list, state.storage)
	if inventory_index >= state.inventory.entries.size():
		inventory_index = -1
	if storage_index >= state.storage.entries.size():
		storage_index = -1
	if inventory_index >= 0:
		inventory_list.select(inventory_index)
	if storage_index >= 0:
		storage_list.select(storage_index)
	result_label.text = message
	result_label.visible = not message.is_empty()
	_update_details()


func _fill_list(list: ItemCardList, inventory: Inventory) -> void:
	list.clear()
	for entry: InventoryEntry in inventory.entries:
		list.add_card(entry.item, entry.count)
		list.set_item_tooltip(list.item_count - 1, ItemTooltipList.description(entry.item))


func _entry_item(source: Inventory, index: int) -> ItemData:
	return source.entries[index].item if index >= 0 and index < source.entries.size() else null


func _select_inventory(index: int) -> void:
	inventory_index = index
	storage_index = -1
	storage_list.deselect_all()
	UIMotion.of(storage_list).reset()
	_update_details()
	UIMotion.reveal_selection([showcase, details, direction])


func _select_storage(index: int) -> void:
	storage_index = index
	inventory_index = -1
	inventory_list.deselect_all()
	UIMotion.of(inventory_list).reset()
	_update_details()
	UIMotion.reveal_selection([showcase, details, direction])


# Left from the warehouse, right from what she carries: the other stock takes
# focus and its row is chosen, so the middle follows.
func _cross(event: InputEvent, list: ItemCardList) -> void:
	var to_storage := list == inventory_list and event.is_action_pressed("ui_right")
	var to_carried := list == storage_list and event.is_action_pressed("ui_left")
	if not (to_storage or to_carried):
		return
	list.accept_event()
	var other := storage_list if to_storage else inventory_list
	other.grab_focus()
	if other.item_count > 0:
		var index := clampi(list.get_selected_items()[0] if not list.get_selected_items().is_empty() else 0, 0, other.item_count - 1)
		other.select(index)
		other.item_selected.emit(index)


func _move() -> void:
	if storage_index >= 0:
		moved_item = _entry_item(state.storage, storage_index)
		transfer_requested.emit(true, storage_index)
	elif inventory_index >= 0:
		moved_item = _entry_item(state.inventory, inventory_index)
		transfer_requested.emit(false, inventory_index)


func _update_details() -> void:
	details.reset()
	var from_storage := storage_index >= 0
	var source := state.storage if from_storage else state.inventory
	var index := storage_index if from_storage else inventory_index
	var item := _entry_item(source, index)
	showcase.present(item)
	move_button.disabled = item == null
	if item == null:
		direction.text = "持ち込み　⇄　倉庫"
		move_button.text = "移動する"
		amount_label.text = "—"
		change_label.text = ""
		details.line("どちらかの一覧から品を選んでください。", &"NoteLabel")
		return
	direction.text = "倉庫　→　持ち込み" if from_storage else "持ち込み　→　倉庫"
	move_button.text = "← 持ち出す" if from_storage else "倉庫へ預ける →"
	details.item_text(item, showcase, &"NoteLabel")
	# The move tried on copies: what would arrive, and both stocks after it.
	var carried := state.inventory.copy()
	var kept := state.storage.copy()
	var moved := state.transfer_item(kept if from_storage else carried, carried if from_storage else kept, index)
	amount_label.text = "×%d" % moved
	move_button.disabled = moved == 0
	if moved == 0:
		change_label.text = "%sに空きがありません" % ("持ち込み" if from_storage else "倉庫")
		return
	change_label.text = "持ち込み %d → %d 枠　·　倉庫 %d → %d 枠" % [state.inventory.entries.size(), carried.entries.size(), state.storage.entries.size(), kept.entries.size()]
	if moved < source.entries[index].count:
		change_label.text += "　·　%d個は残る" % (source.entries[index].count - moved)


# Opening the page: both stocks' rows arrive from their edges, the middle a
# beat later.
func play_entrance() -> void:
	inventory_list.play_intro()
	storage_list.play_intro()
	UIMotion.of(_middle).appear(UIMotion.STAGGER_TIME)


# Success moment after saving: the moved item's glyph flies from the middle
# to its row in the destination list, which then acknowledges the arrival.
func present_move(to_storage: bool) -> void:
	var item := moved_item
	moved_item = null
	var list := storage_list if to_storage else inventory_list
	UIMotion.of(result_label).reveal()
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
	UIMotion.fly_glyph_at(self, item, showcase.visual, point).finished.connect(func():
		if is_instance_valid(list) and list.is_visible_in_tree():
			UIMotion.of(list).reveal())

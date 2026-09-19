class_name HubSell
extends Control

signal sell_requested(from_storage: bool, index: int, amount: int)
signal buy_requested(to_storage: bool, item_id: StringName, amount: int)
signal mode_changed

var state: RunCarryover
var source_choice: OptionButton
var item_list: ItemList
var quantity: SpinBox
var details: Label
var total_label: Label
var sell_button: Button
var sell_all_button: Button
var buy_tab: Button
var sell_tab: Button
var heading: Label
var source_label: Label
var quantity_label: Label
var help_label: Label
var buying := false
# Inventory keeps individual equipment entries; the shop groups only its view.
var rows: Array[Dictionary] = []


func _ready() -> void:
	var columns := HBoxContainer.new()
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catalog := _column(columns, 1.4)
	var toolbar := HBoxContainer.new()
	catalog.add_child(toolbar)
	sell_tab = _button(toolbar, "売却", &"ItemButton", set_buying.bind(false))
	buy_tab = _button(toolbar, "購入", &"ItemButton", set_buying.bind(true))
	var tabs := ButtonGroup.new()
	for button in [sell_tab, buy_tab]:
		button.custom_minimum_size.x = 100
		button.toggle_mode = true
		button.button_group = tabs
	sell_tab.button_pressed = true
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	source_label = _label(toolbar, "売却元", &"MutedLabel")
	source_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	source_choice = OptionButton.new()
	source_choice.add_item("倉庫")
	source_choice.add_item("持ち込み所持品")
	source_choice.custom_minimum_size = Vector2(230, 44)
	toolbar.add_child(source_choice)
	source_choice.item_selected.connect(func(_index: int): refresh(state))
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.add_child(item_list)
	item_list.item_selected.connect(_select)
	help_label = _label(catalog, "", &"MutedLabel")
	help_label.custom_minimum_size.y = 48
	var info := _column(columns, 1.0)
	heading = _label(info, "", &"HeadingLabel")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details = _label(scroll, "", &"BodyLabel")
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quantity_row := HBoxContainer.new()
	info.add_child(quantity_row)
	quantity_label = _label(quantity_row, "", &"MutedLabel")
	quantity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 1
	quantity.step = 1
	quantity.custom_minimum_size = Vector2(180, 44)
	quantity_row.add_child(quantity)
	quantity.value_changed.connect(func(_value: float): _update_quote())
	var quote := PanelContainer.new()
	quote.theme_type_variation = &"ItemPanel"
	info.add_child(quote)
	total_label = _label(quote, "", &"GoldLabel")
	total_label.custom_minimum_size.y = 108
	sell_button = _button(info, "売却する", &"GoldButton", _transact)
	sell_all_button = _button(info, "選択アイテムを全部売却", &"SecondaryButton", _sell_all)


func _column(parent: Container, stretch: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"MainPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	parent.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	return column


func _label(parent: Node, text: String, role: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = role
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, role: StringName, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = role
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func set_buying(value: bool) -> void:
	buying = value
	buy_tab.button_pressed = buying
	sell_tab.button_pressed = not buying
	refresh(state)
	mode_changed.emit()


func refresh(current: RunCarryover) -> void:
	state = current
	rows.clear()
	item_list.clear()
	if buying:
		for item in ItemCatalog.shop_items():
			rows.append({"item": item, "count": _owned(item.id), "index": -1})
	else:
		var groups := {}
		for index in _source().entries.size():
			var entry := _source().entries[index]
			if entry.item.socketed_scroll != null:
				continue
			if groups.has(entry.item.id):
				rows[groups[entry.item.id]].count += entry.count
			else:
				groups[entry.item.id] = rows.size()
				rows.append({"item": entry.item, "count": entry.count, "index": index})
	for row in rows:
		var item: ItemData = row.item
		item_list.add_item("%s  /  %d Gold  /  所持 %d個" % [item.display_name, item.buy_price, row.count] if buying else "%s  ×%d" % [item.display_name, row.count])
		item_list.set_item_tooltip(item_list.item_count - 1, item.description())
	if rows.is_empty():
		item_list.add_item("購入できるアイテムはありません" if buying else "売却できるアイテムはありません")
		item_list.set_item_disabled(0, true)
	heading.text = "次の冒険に備える" if buying else "次の旅の資金に"
	source_label.text = "購入先" if buying else "売却元"
	quantity_label.text = "購入数" if buying else "売却数"
	help_label.text = "購入したアイテムは選んだ購入先へ入ります。" if buying else "同じアイテムをまとめて表示。装備中の品・魔法装着中の杖は売却されません。"
	sell_all_button.visible = not buying
	quantity.value = 1
	_update_quote()


func _source() -> Inventory:
	return state.storage if source_choice.selected == 0 else state.inventory


func _owned(item_id: StringName) -> int:
	var count := 0
	for entry in _source().entries:
		if entry.item.id == item_id:
			count += entry.count
	return count


func _purchase_limit(item: ItemData) -> int:
	var destination := _source()
	var capacity := destination.max_entries - destination.entries.size()
	if item.stackable():
		capacity = destination.max_stack - _owned(item.id) if _owned(item.id) > 0 else (destination.max_stack if capacity > 0 else 0)
	return mini(capacity, int(state.gold / item.buy_price))


func _select(index: int) -> void:
	var row := rows[index]
	quantity.max_value = maxi(1, _purchase_limit(row.item)) if buying else row.count
	quantity.value = 1
	_update_quote()
	UIMotion.of(details).reveal()


func _update_quote() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		details.text = "一覧からアイテムを選んでください。"
		total_label.text = "所持Gold  %d" % state.gold
		sell_button.text = "購入する" if buying else "売却する"
		sell_button.disabled = true
		sell_all_button.disabled = true
		quantity.editable = false
		return
	var row := rows[selected[0]]
	var item: ItemData = row.item
	var price := item.buy_price if buying else item.sell_price
	var amount := int(quantity.value)
	var total := price * amount
	quantity.editable = true
	details.text = "%s  /  所持 %d個\n単価  %d Gold\n%s" % [item.display_name, row.count, price, item.description()]
	if buying:
		var limit := _purchase_limit(item)
		total_label.text = "所持Gold     %d\n購入合計     − %d\n購入後       %d" % [state.gold, total, state.gold - total]
		sell_button.text = "%d個を購入する  /  %d Gold" % [amount, total]
		sell_button.disabled = limit < amount
		quantity.editable = limit > 0
		if limit == 0:
			total_label.text = "購入できません。\nGoldまたは購入先の空き容量が不足しています。"
	else:
		total_label.text = "所持Gold     %d\n売却合計     + %d\n売却後       %d" % [state.gold, total, state.gold + total]
		sell_button.text = "%d個を売却する  /  %d Gold" % [amount, total]
		sell_button.disabled = total <= 0 or state.gold + total > SaveCodec.MAX_GOLD
		var all_value: int = price * row.count
		sell_all_button.text = "選択品を全部売却  /  %d個・%d Gold" % [row.count, all_value]
		sell_all_button.disabled = price <= 0 or state.gold + all_value > SaveCodec.MAX_GOLD


func _transact() -> void:
	# Commit typed SpinBox text before reading its value.
	if quantity.get_line_edit().has_focus():
		quantity.apply()
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var row := rows[selected[0]]
	if buying:
		buy_requested.emit(source_choice.selected == 0, row.item.id, int(quantity.value))
	else:
		sell_requested.emit(source_choice.selected == 0, row.index, int(quantity.value))


func _sell_all() -> void:
	var selected := item_list.get_selected_items()
	if not buying and not selected.is_empty():
		var row := rows[selected[0]]
		sell_requested.emit(source_choice.selected == 0, row.index, row.count)

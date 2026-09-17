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
	HubTheme.panel(self, Vector2.ZERO, Vector2(730, 560))
	sell_tab = HubTheme.button(self, "売却", Vector2(24, 16), Vector2(150, 44), set_buying.bind(false))
	buy_tab = HubTheme.button(self, "購入", Vector2(188, 16), Vector2(150, 44), set_buying.bind(true))
	var tabs := ButtonGroup.new()
	for button in [sell_tab, buy_tab]:
		button.toggle_mode = true
		button.button_group = tabs
	sell_tab.button_pressed = true
	source_label = HubTheme.label(self, "売却元", Vector2(362, 18), Vector2(88, 40), 17)
	source_choice = OptionButton.new()
	source_choice.add_item("倉庫")
	source_choice.add_item("持ち込み所持品")
	HubTheme.place(source_choice, self, Vector2(452, 16), Vector2(254, 44))
	source_choice.item_selected.connect(func(_index: int): refresh(state))
	item_list = ItemList.new()
	HubTheme.place(item_list, self, Vector2(24, 80), Vector2(682, 396))
	item_list.item_selected.connect(_select)
	help_label = HubTheme.label(self, "", Vector2(24, 495), Vector2(682, 48), 17)
	HubTheme.panel(self, Vector2(750, 0), Vector2(530, 560))
	heading = HubTheme.label(self, "", Vector2(774, 20), Vector2(482, 40), 26)
	var scroll := ScrollContainer.new()
	HubTheme.place(scroll, self, Vector2(774, 78), Vector2(482, 138))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details = HubTheme.label(scroll, "", Vector2.ZERO, Vector2(458, 138), 18)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_label = HubTheme.label(self, "", Vector2(774, 228), Vector2(180, 42))
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 1
	quantity.step = 1
	HubTheme.place(quantity, self, Vector2(1010, 226), Vector2(246, 46))
	quantity.value_changed.connect(func(_value: float): _update_quote())
	total_label = HubTheme.label(self, "", Vector2(774, 290), Vector2(482, 120), 21)
	total_label.modulate = HubTheme.GOLD
	sell_button = HubTheme.button(self, "売却する", Vector2(774, 423), Vector2(482, 50), _transact)
	sell_all_button = HubTheme.button(self, "選択アイテムを全部売却", Vector2(774, 486), Vector2(482, 50), _sell_all)


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
	help_label.text = "購入したアイテムは選んだ購入先へ入ります。" if buying else "同じアイテムをまとめて表示。装備中の品は売却されません。"
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

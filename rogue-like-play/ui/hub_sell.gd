class_name HubSell
extends Control

# The shop, laid out so the eye runs left to right: choose the goods (a list
# filtered by category tabs, on a slab like the lobby menu), learn them (name,
# a short note, the counter and the one trade action, on the hall with only a
# shade behind), then see what they do to her (the heroine from the knees up,
# her whole stats before and after over her). No framed box parts the
# screen, and each number shows once or twice rather than four times.
# Buying and selling switch at the header's title place (mode_tabs).

signal sell_requested(from_storage: bool, index: int, amount: int)
signal buy_requested(to_storage: bool, item_id: StringName, amount: int)
signal mode_changed

const SHOWCASE_SIZE := 128.0
const CATEGORIES: Array[String] = ["すべて", "武器", "防具", "装飾", "消耗品", "魔法"]
const CATEGORY_KINDS := [-1, ItemData.Kind.WEAPON, ItemData.Kind.ARMOR, ItemData.Kind.ACCESSORY, ItemData.Kind.CONSUMABLE, ItemData.Kind.SCROLL]
# The heroine from the knees up: her height in screen pixels, the share of
# it from the texture's top down to her knees, and where her face sits across.
const HERO_HEIGHT := 960.0
const HERO_KNEES := 0.72
const HERO_FACE_X := 0.4
# Her whole stats for the next run.
const HERO_STATS := [["hp", "最大HP"], ["attack", "攻撃力"], ["defense", "防御力"], ["reach", "射程"]]

var state: RunCarryover
var mode_tabs: HBoxContainer
var buy_tab: Button
var sell_tab: Button
var category_tabs: CategoryTabs
var source_choice: SegmentedChoice
var source_label: Label
var item_list: ItemCardList
var help_label: Label
var showcase: ItemShowcase
var details: ItemDetails
var swap_label: Label
var quantity: QuantityStepper
var quantity_label: Label
var total_label: Label
var possession: Label
var sell_all_button: Button
var sell_button: Button
var hero: LobbyHero
var hero_specs: StatBars
var heading: Label
var buying := false
# Inventory keeps individual equipment entries; the shop groups only its view.
var rows: Array[Dictionary] = []
# The item of the last requested trade, for the success moment after saving.
var traded_item: ItemData
var _source_row: HBoxContainer
var _place_row: HBoxContainer
var _hero_holder: Control
var _hero_frame: Control


func _ready() -> void:
	_build_mode_tabs()
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_catalog(HubUI.open_column(columns, 1.1, &"SlabColumn"))
	_build_info(HubUI.open_column(columns, 1.15, &"ShadeColumn"))
	_build_hero(columns)


# Two title-sized tabs the hub shows in its header in place of the title.
func _build_mode_tabs() -> void:
	mode_tabs = HBoxContainer.new()
	mode_tabs.theme_type_variation = &"ModeTabs"
	var group := ButtonGroup.new()
	buy_tab = HubUI.button(mode_tabs, "購入", set_buying.bind(true), &"ModeTab")
	sell_tab = HubUI.button(mode_tabs, "売却", set_buying.bind(false), &"ModeTab")
	for tab in [buy_tab, sell_tab]:
		tab.custom_minimum_size.y = 0
		tab.toggle_mode = true
		tab.button_group = group
	sell_tab.button_pressed = true


func _build_catalog(catalog: VBoxContainer) -> void:
	category_tabs = CategoryTabs.new()
	catalog.add_child(category_tabs)
	category_tabs.setup(CATEGORIES)
	category_tabs.changed.connect(func(_index: int): refresh(state))
	# Selling chooses which stock to show, so the choice stands by the list;
	# buying chooses where the goods go, so it stands by the counter.
	_source_row = HBoxContainer.new()
	_source_row.theme_type_variation = &"CompactRow"
	catalog.add_child(_source_row)
	source_label = HubUI.label(_source_row, "売却元", &"NoteLabel")
	source_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	source_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_choice = SegmentedChoice.new()
	_source_row.add_child(source_choice)
	source_choice.add_item("倉庫")
	source_choice.add_item("持ち込み")
	source_choice.item_selected.connect(func(_index: int): refresh(state))
	item_list = ItemCardList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.add_child(item_list)
	item_list.item_selected.connect(_select)
	help_label = HubUI.label(catalog, "", &"NoteLabel")


func _build_info(info: VBoxContainer) -> void:
	info.theme_type_variation = &"DetailStack"
	heading = HubUI.label(info, "", &"MutedLabel")
	heading.visible = false
	showcase = ItemShowcase.new()
	showcase.show_effect = false
	showcase.visual.custom_minimum_size = Vector2.ONE * SHOWCASE_SIZE
	info.add_child(showcase)
	details = ItemDetails.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(details)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(gap)
	details.fit_lines(gap, 48)
	# The counter: where the goods go, how many, one large price and one
	# quiet line of what changes, right above the trade, parted by a rule.
	HubUI.rule(info)
	var counter_stack := VBoxContainer.new()
	counter_stack.theme_type_variation = &"CompactStack"
	info.add_child(counter_stack)
	_place_row = HBoxContainer.new()
	_place_row.theme_type_variation = &"CompactRow"
	counter_stack.add_child(_place_row)
	var place_caption := HubUI.label(_place_row, "購入先", &"NoteLabel")
	place_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	place_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	place_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quantity_row := HBoxContainer.new()
	counter_stack.add_child(quantity_row)
	quantity_label = HubUI.label(quantity_row, "", &"NoteLabel")
	quantity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity = QuantityStepper.new()
	quantity_row.add_child(quantity)
	quantity.value_changed.connect(func(_value: float): _update_quote())
	total_label = HubUI.label(counter_stack, "", &"PriceLabel")
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	possession = HubUI.label(counter_stack, "", &"NoteLabel")
	possession.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sell_all_button = HubUI.button(info, "全部売却", _sell_all, &"SecondaryButton")
	sell_all_button.tooltip_text = "選択品を全部売却"
	sell_button = HubUI.primary_action(info, "売却する", _transact)


# Unframed, like the lobby: the heroine from the knees up, cut by the page's
# foot and the screen's right edge, with what the goods do to her whole stats
# laid over her legs.
func _build_hero(columns: HBoxContainer) -> void:
	_hero_holder = Control.new()
	_hero_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_holder.size_flags_stretch_ratio = 0.95
	_hero_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_hero_holder)
	# Reaches past the page to the screen's right edge, and clips there and
	# at the page's foot.
	_hero_frame = Control.new()
	_hero_frame.clip_contents = true
	_hero_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_holder.add_child(_hero_frame)
	hero = LobbyHero.new()
	hero.texture = HubLobby.HERO_TEXTURE
	hero.modulate = get_theme_color(&"hero_tint", &"HubLobby")
	_hero_frame.add_child(hero)
	_hero_holder.resized.connect(_place_hero)
	var band := PanelContainer.new()
	band.theme_type_variation = &"ShopHeroBand"
	_hero_holder.add_child(band)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"CompactStack"
	band.add_child(stack)
	HubUI.label(stack, "次の冒険の能力", &"NoteLabel")
	swap_label = HubUI.label(stack, "", &"NoteLabel")
	hero_specs = StatBars.new()
	stack.add_child(hero_specs)


func _place_hero() -> void:
	# The page leaves this much of the screen on its right.
	var screen_margin := 80.0
	_hero_frame.position = Vector2.ZERO
	_hero_frame.size = Vector2(_hero_holder.size.x + screen_margin, _hero_holder.size.y)
	var texture := hero.texture
	var width := HERO_HEIGHT * texture.get_width() / texture.get_height()
	hero.size = Vector2(width, HERO_HEIGHT)
	# Knees on the page's foot, her face over the middle of the column.
	hero.position = Vector2(_hero_holder.size.x * 0.5 - width * HERO_FACE_X, _hero_holder.size.y - HERO_HEIGHT * HERO_KNEES)
	hero.pivot_offset = Vector2(width * 0.5, HERO_HEIGHT)


func set_buying(value: bool) -> void:
	buying = value
	buy_tab.set_pressed_no_signal(buying)
	sell_tab.set_pressed_no_signal(not buying)
	refresh(state)
	mode_changed.emit()


func refresh(current: RunCarryover) -> void:
	state = current
	for target: Control in [item_list, showcase, details, possession]:
		UIMotion.of(target).reset()
	_place_choice()
	rows.clear()
	item_list.clear()
	var kind: int = CATEGORY_KINDS[category_tabs.selected]
	if buying:
		for item in ItemCatalog.shop_items():
			if kind < 0 or item.kind == kind:
				rows.append({"item": item, "count": _owned(item.id), "index": -1})
	else:
		var groups := {}
		for index in _source().entries.size():
			var entry := _source().entries[index]
			if entry.item.socketed_scroll != null or (kind >= 0 and entry.item.kind != kind):
				continue
			if groups.has(entry.item.id):
				rows[groups[entry.item.id]].count += entry.count
			else:
				groups[entry.item.id] = rows.size()
				rows.append({"item": entry.item, "count": entry.count, "index": index})
	for row in rows:
		var item: ItemData = row.item
		item_list.add_card(item, row.count, item.buy_price if buying else item.sell_price)
	item_list.empty_text = ("この分類の品は扱っていない" if buying else "売れる品はここにない")
	help_label.text = "" if buying else "装備中の品と、魔法を込めた杖は売れません。"
	help_label.visible = not buying
	sell_all_button.visible = not buying
	quantity.value = 1
	showcase.present(null)
	_update_quote()
	_show_hero_specs(null)


# One choice, two homes: by the list when selling, in the counter when buying.
func _place_choice() -> void:
	var home := _place_row if buying else _source_row
	if source_choice.get_parent() != home:
		source_choice.reparent(home)
	_source_row.visible = not buying
	_place_row.visible = buying


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


func _select(index: int, animate: bool = true) -> void:
	var row := rows[index]
	quantity.max_value = maxi(1, _purchase_limit(row.item)) if buying else row.count
	quantity.value = 1
	showcase.present(row.item)
	_update_quote()
	_show_hero_specs(row.item)
	if animate:
		UIMotion.reveal_selection([showcase, details, possession])


func _update_quote() -> void:
	var selected := item_list.get_selected_items()
	quantity_label.text = "購入数" if buying else "売却数"
	if selected.is_empty():
		# Assigning text equal to the last assignment would keep appended
		# lines; reset clears whatever the previous goods wrote.
		details.reset()
		details.line("品を選んでください。", &"MutedLabel")
		# The balance is in the header; nothing chosen, nothing changes.
		possession.text = ""
		total_label.text = "—"
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
	details.reset()
	details.item_text(item, showcase, &"NoteLabel")
	quantity_label.text = "%s　最大 %d" % ["数量" if buying else "売る数", int(quantity.max_value)]
	var place := source_choice.get_item_text(source_choice.selected)
	var after: int = row.count + amount if buying else row.count - amount
	if buying:
		var limit := _purchase_limit(item)
		total_label.text = UIFormat.gold(total)
		possession.text = "%s %d → %d個　·　購入後 %s" % [place, row.count, after, UIFormat.gold(state.gold - total)]
		sell_button.text = "%d個を購入する" % amount
		sell_button.disabled = limit < amount
		quantity.editable = limit > 0
		if limit == 0:
			total_label.text = "買えません"
			possession.text = "所持金か、%sの空きが足りません" % place
	else:
		total_label.text = "+%s" % UIFormat.gold(total)
		possession.text = "%s %d → %d個　·　売却後 %s" % [place, row.count, after, UIFormat.gold(state.gold + total)]
		sell_button.text = "%d個を売却する" % amount
		sell_button.disabled = total <= 0 or state.gold + total > SaveCodec.MAX_GOLD
		var all_value: int = price * row.count
		sell_all_button.text = "全部売却  %d個・%s" % [row.count, UIFormat.gold(all_value)]
		sell_all_button.disabled = price <= 0 or state.gold + all_value > SaveCodec.MAX_GOLD


# The slot equipment would go to: an empty compatible one first, otherwise
# the first (Main for weapons). -1 for goods that are not worn.
func _slot_for(item: ItemData) -> int:
	if item == null or item.kind == ItemData.Kind.SCROLL:
		return -1
	var slot := -1
	for candidate in 5:
		if state.equipment.accepts(item, candidate):
			if state.equipment.slots[candidate] == null:
				return candidate
			if slot < 0:
				slot = candidate
	return slot


# Her whole stats for the next run, as they are and if the goods were worn.
func _show_hero_specs(item: ItemData) -> void:
	var before := state.preparation_stats()
	var after := before
	# Only goods being bought would be worn; selling shows her as she is.
	var slot := _slot_for(item) if buying else -1
	if slot >= 0:
		var gear := Equipment.new()
		gear.slots.assign(state.equipment.slots)
		gear.slots[slot] = item
		after = state.preparation_stats(gear)
	var current: ItemData = state.equipment.slots[slot] if slot >= 0 else null
	swap_label.text = ("%sと入れ替え（今：%s）" % [Equipment.SLOT_NAMES[slot], current.label() if current != null else "なし"]) if slot >= 0 else ""
	swap_label.visible = slot >= 0
	var shown := []
	for stat: Array in HERO_STATS:
		# Bars leave room for the change against her current value.
		shown.append([stat[1], before[stat[0]], after[stat[0]], maxi(before[stat[0]], after[stat[0]]) * 1.25 + 1])
	hero_specs.show_rows(shown)


func step_category(direction: int) -> void:
	category_tabs.step(direction)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var pad := event is InputEventJoypadButton
	if pad or event is InputEventKey:
		category_tabs.use_pad(pad)
	var back: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q) or (pad and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER)
	var next: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) or (pad and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	var swap: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R) or (pad and event.pressed and event.button_index == JOY_BUTTON_Y)
	if back or next:
		step_category(-1 if back else 1)
		get_viewport().set_input_as_handled()
	elif swap:
		set_buying(not buying)
		get_viewport().set_input_as_handled()


# Success moment after saving: the traded item's glyph travels from the
# showcase to where the trade landed, which then acknowledges it.
func present_trade(target: Control) -> void:
	if traded_item == null or not is_visible_in_tree():
		return
	# A purchase reselects its item so it can be bought again. Ordinary
	# refreshes and sales still clear the selection.
	if buying:
		for index in rows.size():
			if rows[index].item.id == traded_item.id:
				item_list.select(index)
				_select(index, false)
				break
	UIMotion.fly_glyph(self, traded_item, showcase.visual, target).finished.connect(func():
		if is_instance_valid(target) and target.is_visible_in_tree():
			UIMotion.of(target).pulse(1.06, UIMotion.GOLD_TIME))


func _transact() -> void:
	# Commit typed SpinBox text before reading its value.
	if quantity.get_line_edit().has_focus():
		quantity.apply()
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var row := rows[selected[0]]
	traded_item = row.item
	if buying:
		buy_requested.emit(source_choice.selected == 0, row.item.id, int(quantity.value))
	else:
		sell_requested.emit(source_choice.selected == 0, row.index, int(quantity.value))


func _sell_all() -> void:
	var selected := item_list.get_selected_items()
	if not buying and not selected.is_empty():
		var row := rows[selected[0]]
		traded_item = row.item
		sell_requested.emit(source_choice.selected == 0, row.index, row.count)

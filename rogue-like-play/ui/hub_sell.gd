class_name HubSell
extends Control

# The shop, laid out so the eye runs left to right: choose the goods (icons
# with their names and prices in a grid, filtered by category tabs, on a slab
# from the left edge; the full text is each icon's tooltip), see them (the
# goods large on a glow in the open hall, where the merchant's counter shows
# behind them), and decide in the right column as on every hub screen: their
# name and main effect, what they would change in her, the counter and the
# one trade action at its foot. Each number shows once or twice rather than
# four times.
# Buying and selling switch at the header's title place (mode_tabs).

signal sell_requested(from_storage: bool, index: int, amount: int)
signal buy_requested(to_storage: bool, item_id: StringName, amount: int)
signal mode_changed

# The goods share the middle with what they would change in her: 172px is the
# least that still draws the 48px art at three times (ItemVisual fills 84% in
# 48px steps).
const SHOWCASE_SIZE := 240.0
# The goods are small icons, each with its name and price beside it, two
# to a row.
const GRID_COLUMNS := 2
const CELL_WIDTH := 254.0
const CELL_SIZE := 72.0
const CELL_ICON := 48.0
const CATEGORIES: Array[String] = ["すべて", "武器", "防具", "装飾", "消耗品", "魔法"]
const CATEGORY_KINDS := [-1, ItemData.Kind.WEAPON, ItemData.Kind.ARMOR, ItemData.Kind.ACCESSORY, ItemData.Kind.CONSUMABLE, ItemData.Kind.SCROLL]

var state: RunCarryover
var mode_tabs: HBoxContainer
var buy_tab: Button
var sell_tab: Button
var category_tabs: CategoryTabs
var source_choice: SegmentedChoice
var source_label: Label
var grid: IconGrid
var sell_rule: HintMark
var showcase: ItemShowcase
var swap_label: Label
var quantity: QuantityStepper
var quantity_label: Label
var total_label: Label
var possession: Label
var sell_all_button: Button
var sell_button: Button
var hero_specs: StatBars
var heading: Label
var buying := false
# Inventory keeps individual equipment entries; the shop groups only its view.
# The rows shown, in the grid's order: {item, count, index}.
var rows: Array[Dictionary] = []
# The item of the last requested trade, for the success moment after saving.
var traded_item: ItemData
var _source_row: HBoxContainer
var _place_row: HBoxContainer
var hero_stats: HeroStats
var _catalog: VBoxContainer
var _info: VBoxContainer
var _stage: VBoxContainer
var _counter_rule: Control


func _ready() -> void:
	_build_mode_tabs()
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The list and the details share one dark slab, melting into the hall
	# only at its right edge; the background shows above it and round her.
	# The list and the display share the left two thirds, so the right column
	# stands where it does on every hub screen.
	var choosing := HBoxContainer.new()
	choosing.theme_type_variation = &"ShopColumns"
	choosing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choosing.size_flags_stretch_ratio = 2.1
	columns.add_child(choosing)
	_catalog = HubUI.open_column(choosing, 1.1, &"SlabSolid")
	_build_catalog(_catalog)
	# The middle is the open hall, with the goods on display in it.
	_stage = VBoxContainer.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_stretch_ratio = 0.8
	_stage.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choosing.add_child(_stage)
	_info = HubUI.open_column(columns, 1.0, &"SlabSolidEnd")
	_build_info(_info)
	# What the goods would change in her stands right above the counter.
	hero_stats = HeroStats.new()
	hero_stats.visible = false
	add_child(hero_stats)
	hero_stats.move_stats_to(_info, _counter_rule.get_index())
	hero_specs = hero_stats.specs
	swap_label = hero_stats.swap_label


# Two title-sized tabs the hub shows in its header in place of the title.
func _build_mode_tabs() -> void:
	mode_tabs = HBoxContainer.new()
	mode_tabs.theme_type_variation = &"ModeTabs"
	TabUnderline.attach(mode_tabs)
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
	category_tabs.changed.connect(func(_index: int): _show_stock())
	# Selling chooses which stock to show, so the choice stands by the list;
	# buying chooses where the goods go, so it stands by the counter.
	_source_row = HBoxContainer.new()
	_source_row.theme_type_variation = &"CompactRow"
	catalog.add_child(_source_row)
	source_label = HubUI.label(_source_row, "売却元", &"NoteLabel")
	source_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sell_rule = HintMark.make(_source_row, "装備中の品と、魔法を込めた杖は売れない。", HubSettings.TOPIC_PREPARATION)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_source_row.add_child(spacer)
	source_choice = SegmentedChoice.new()
	source_choice.option_role = &"CategoryTab"
	_source_row.add_child(source_choice)
	source_choice.add_item("倉庫")
	source_choice.add_item("持ち込み")
	source_choice.item_selected.connect(func(_index: int): _show_stock())
	grid = IconGrid.new()
	grid.columns = GRID_COLUMNS
	grid.cell_size = CELL_SIZE
	grid.cell_width = CELL_WIDTH
	grid.icon_size = CELL_ICON
	# Looking at an icon with the focus previews it, as arrowing down the old
	# list did; Enter or a double click moves on to the trade.
	grid.choose_on_focus = true
	catalog.add_child(grid)
	grid.chosen.connect(_select)
	grid.activated.connect(func(place: int):
		_select(place)
		if sell_button.is_visible_in_tree() and not sell_button.disabled:
			sell_button.grab_focus())


func _build_info(info: VBoxContainer) -> void:
	info.theme_type_variation = &"DetailStack"
	heading = HubUI.label(info, "", &"MutedLabel")
	heading.visible = false
	# The goods on display stand large on a glow in the hall; their name and
	# main effect head the column.
	showcase = ItemShowcase.new()
	showcase.visual.framed = false
	showcase.visual.idle = true
	info.add_child(showcase)
	showcase.visual.custom_minimum_size = Vector2.ONE * SHOWCASE_SIZE
	showcase.visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	showcase.visual.reparent(_stage, false)
	HubUI.rule(info)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(gap)
	# The counter: where the goods go, how many, one large price and one
	# quiet line of what changes, right above the trade, parted by a rule.
	_counter_rule = HubUI.rule(info)
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
	quantity.use_selector()
	quantity.value_changed.connect(func(_value: float): _update_quote())
	total_label = HubUI.label(counter_stack, "", &"PriceLabel")
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	possession = HubUI.label(counter_stack, "", &"NoteLabel")
	possession.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sell_all_button = HubUI.button(info, "全部売却", _sell_all, &"SecondaryButton")
	sell_all_button.tooltip_text = "選択品を全部売却"
	sell_button = HubUI.primary_action(info, "売却する", _transact)


func set_buying(value: bool) -> void:
	buying = value
	buy_tab.set_pressed_no_signal(buying)
	sell_tab.set_pressed_no_signal(not buying)
	_show_stock()
	mode_changed.emit()


# Another stock for the player (buying or selling, a category, a source):
# the list's rows arrive anew.
func _show_stock() -> void:
	refresh(state)
	UIMotion.of(grid.scroll).appear(0.0, UIMotion.ROW_TIME)


# Opening the page: the list's rows arrive top first, the counter a beat
# later.
func play_entrance() -> void:
	UIMotion.of(_catalog).appear(0.0, UIMotion.WINDOW_TIME)
	UIMotion.of(_stage).appear(UIMotion.STAGGER_TIME)
	UIMotion.of(_info).appear(UIMotion.STAGGER_TIME)


func refresh(current: RunCarryover) -> void:
	state = current
	for target: Control in [grid.scroll, showcase, possession]:
		UIMotion.of(target).reset()
	_place_choice()
	var shown: Array[Dictionary] = []
	var kind: int = CATEGORY_KINDS[category_tabs.selected]
	if buying:
		for item in ItemCatalog.shop_items():
			if kind < 0 or item.kind == kind:
				# Owned copies read in the counter; the icon's corner stays bare.
				shown.append({"item": item, "count": _owned(item.id), "index": shown.size(), "badge": 1})
	else:
		var groups := {}
		for index in _source().entries.size():
			var entry := _source().entries[index]
			if entry.item.socketed_scroll != null or (kind >= 0 and entry.item.kind != kind):
				continue
			if groups.has(entry.item.id):
				shown[groups[entry.item.id]].count += entry.count
			else:
				groups[entry.item.id] = shown.size()
				shown.append({"item": entry.item, "count": entry.count, "index": index})
	for row in shown:
		var item: ItemData = row.item
		var price := UIFormat.gold(item.buy_price if buying else item.sell_price)
		row.note = price
		row.tooltip = "%s\n\n%s %s" % [ItemTooltipList.description(item), "購入" if buying else "売却", price]
	grid.clear_choice()
	grid.show_rows(shown, "この分類の品は扱っていない" if buying else "売れる品はここにない")
	rows = grid.entries
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


# The place among the icons shown of the chosen goods, or -1.
func chosen_place() -> int:
	return grid.place_of(grid.selected)


# Chooses the goods at a place, as a click on the icon does.
func pick(place: int) -> void:
	grid.choose(place)
	_select(place)


func _select(index: int, animate: bool = true) -> void:
	var row := rows[index]
	quantity.max_value = maxi(1, _purchase_limit(row.item)) if buying else row.count
	quantity.value = 1
	showcase.present(row.item)
	_update_quote()
	_show_hero_specs(row.item)
	if animate:
		UIMotion.reveal_selection([showcase, possession])


func _update_quote() -> void:
	var place := chosen_place()
	quantity_label.text = "購入数" if buying else "売却数"
	if place < 0:
		# The balance is in the header; nothing chosen, nothing changes.
		possession.text = ""
		total_label.text = "—"
		sell_button.text = "購入する" if buying else "売却する"
		sell_button.disabled = true
		sell_all_button.disabled = true
		quantity.editable = false
		return
	var row := rows[place]
	var item: ItemData = row.item
	var price := item.buy_price if buying else item.sell_price
	var amount := int(quantity.value)
	var total := price * amount
	quantity.editable = true
	quantity_label.text = "%s　最大 %d" % ["数量" if buying else "売る数", int(quantity.max_value)]
	var where := source_choice.get_item_text(source_choice.selected)
	var after: int = row.count + amount if buying else row.count - amount
	if buying:
		var limit := _purchase_limit(item)
		total_label.text = UIFormat.gold(total)
		possession.text = "%s %d → %d個　·　購入後 %s" % [where, row.count, after, UIFormat.gold(state.gold - total)]
		sell_button.text = "%d個を購入する" % amount
		sell_button.disabled = limit < amount
		quantity.editable = limit > 0
		if limit == 0:
			total_label.text = "買えません"
			possession.text = "所持金か、%sの空きが足りません" % where
	else:
		total_label.text = "+%s" % UIFormat.gold(total)
		possession.text = "%s %d → %d個　·　売却後 %s" % [where, row.count, after, UIFormat.gold(state.gold + total)]
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
	# Only goods being bought would be worn; selling shows her as she is.
	var slot := _slot_for(item) if buying else -1
	if slot < 0:
		hero_stats.show_stats(before)
		return
	var gear := Equipment.new()
	gear.slots.assign(state.equipment.slots)
	gear.slots[slot] = item
	hero_stats.show_stats(before, state.preparation_stats(gear), HeroStats.swap_text(slot, state.equipment.slots[slot]))

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
				grid.choose(index)
				_select(index, false)
				break
	UIMotion.fly_glyph(self, traded_item, showcase.visual, target).finished.connect(func():
		if is_instance_valid(target) and target.is_visible_in_tree():
			UIMotion.of(target).pulse(1.06, UIMotion.GOLD_TIME))


func _transact() -> void:
	# Commit typed SpinBox text before reading its value.
	if quantity.get_line_edit().has_focus():
		quantity.apply()
	var place := chosen_place()
	if place < 0:
		return
	var row := rows[place]
	traded_item = row.item
	if buying:
		buy_requested.emit(source_choice.selected == 0, row.item.id, int(quantity.value))
	else:
		sell_requested.emit(source_choice.selected == 0, row.index, int(quantity.value))


func _sell_all() -> void:
	var place := chosen_place()
	if not buying and place >= 0:
		var row := rows[place]
		traded_item = row.item
		sell_requested.emit(source_choice.selected == 0, row.index, row.count)

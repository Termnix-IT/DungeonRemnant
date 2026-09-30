class_name HubEquipment
extends Control

signal equip_requested(from_storage: bool, index: int, slot: int)
signal unequip_requested(slot: int)
signal scroll_remove_requested(slot: int)
signal swap_requested
signal warehouse_requested
signal done_requested

var state: RunCarryover
var selected_slot := 0
var candidates: Array[Dictionary] = []
var slots: Array[Button] = []
var slot_names: Array[Label] = []
var slot_glyphs: Array[Control] = []
var candidate_list: ItemCardList
var carried_list: ItemCardList
var stat_caption: Label
var stat_sheet: GridContainer
var stat_values: Array[Label] = []
var comparison: ItemDetails
var equip_button: Button
var unequip_button: Button
var done_button: Button
var swap_button: Button
var scroll_remove_button: Button
var showcase: ItemShowcase
var portrait: CharacterPreview
# The candidate of the last equip request, for the success moment after saving.
var equipped_item: ItemData
const SLOT_CAPTIONS := Equipment.SLOT_NAMES
const STAT_ROWS: Array = [["HP", "hp"], ["攻撃力", "attack"], ["防御力", "defense"], ["主武器の射程", "reach"]]
# Slot art is the 48px item icon at its native size, so it is never blurred.
const SLOT_ICON := 48


func _ready() -> void:
	var columns := HubUI.columns(self)
	var catalog := HubUI.section(columns, 1.03)
	HubUI.label(catalog, "装備候補", &"HeadingLabel")
	HubUI.label(catalog, "所持品・倉庫から選択", &"MutedLabel")
	candidate_list = ItemCardList.new()
	candidate_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.add_child(candidate_list)
	candidate_list.item_selected.connect(_select_candidate)
	HubUI.label(catalog, "持ち込みアイテム", &"BodyLabel")
	carried_list = ItemCardList.new()
	carried_list.custom_minimum_size.y = 112
	catalog.add_child(carried_list)
	HubUI.button(catalog, "倉庫で持ち込みを整理", func(): warehouse_requested.emit())
	var detail := HubUI.section(columns, 1.0)
	showcase = ItemShowcase.new()
	detail.add_child(showcase)
	var compare_box := PanelContainer.new()
	compare_box.theme_type_variation = &"InsetPanel"
	compare_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(compare_box)
	comparison = ItemDetails.new()
	comparison.size_flags_vertical = Control.SIZE_EXPAND_FILL
	compare_box.add_child(comparison)
	equip_button = HubUI.button(detail, "選択した装備に変更", _equip, &"GoldButton")
	unequip_button = HubUI.button(detail, "選択枠の装備を外す", func():
		equipped_item = null
		unequip_requested.emit(selected_slot))
	var build := HubUI.section(columns, 1.25)
	build.theme_type_variation = &"DetailStack"
	HubUI.label(build, "冒険者の装備", &"HeadingLabel")
	var body := HBoxContainer.new()
	body.theme_type_variation = &"CompactRow"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(left)
	portrait = CharacterPreview.new()
	portrait.custom_minimum_size = Vector2(120, 180)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_stretch_ratio = 1.2
	body.add_child(portrait)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(right)
	for slot in 5:
		var parent := left if slot < 2 else right
		var control := HubUI.button(parent, "", select_slot.bind(slot), &"ItemButton")
		control.custom_minimum_size = Vector2(112, 88)
		control.toggle_mode = true
		slots.append(control)
		_build_slot(control, slot)
	# The next run's four numbers, shown as a sheet; a selected candidate
	# previews its change in place, coloured by rise or fall.
	stat_caption = HubUI.label(build, "", &"MutedLabel")
	stat_sheet = GridContainer.new()
	stat_sheet.theme_type_variation = &"StatSheet"
	stat_sheet.columns = 2
	build.add_child(stat_sheet)
	for row: Array in STAT_ROWS:
		var cell := VBoxContainer.new()
		cell.theme_type_variation = &"CompactStack"
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_sheet.add_child(cell)
		HubUI.label(cell, row[0], &"HudSmall")
		var value := HubUI.label(cell, "", &"StatValue")
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		stat_values.append(value)
	scroll_remove_button = HubUI.button(build, "選択枠の魔法を外す", func():
		equipped_item = null
		scroll_remove_requested.emit(selected_slot))
	swap_button = HubUI.button(build, "主武器と副武器を入れ替え", func(): swap_requested.emit())
	done_button = HubUI.button(build, "準備完了・ステージ選択へ", func(): done_requested.emit())


func refresh(current: RunCarryover) -> void:
	state = current
	for target: Control in [candidate_list, showcase, comparison]:
		UIMotion.of(target).reset()
	swap_button.disabled = state.equipment.slots[Equipment.Slot.SUB] == null
	for index in slots.size():
		slots[index].set_pressed_no_signal(index == selected_slot)
		var item := state.equipment.slots[index]
		slot_names[index].text = item.label() if item != null else "未装備"
		slot_glyphs[index].queue_redraw()
		slots[index].tooltip_text = Equipment.SLOT_NAMES[index] + "：" + (ItemTooltipList.description(item) if item != null else "未装備")
	_show_stats(state.preparation_stats())
	carried_list.clear()
	for entry in state.inventory.entries:
		carried_list.add_card(entry.item, entry.count)
	if carried_list.item_count == 0:
		carried_list.add_item("持ち込みアイテムはありません")
		carried_list.set_item_disabled(0, true)
	_fill_candidates()


# Before and after for the next run; without an after, the current values.
func _show_stats(before: Dictionary, after: Dictionary = {}) -> void:
	var changes := false
	for row: Array in STAT_ROWS:
		changes = changes or after.get(row[1], before[row[1]]) != before[row[1]]
	stat_caption.text = "次の冒険（変更後）" if changes else "次の冒険"
	for index in STAT_ROWS.size():
		var key: String = STAT_ROWS[index][1]
		var value := stat_values[index]
		var next: int = after.get(key, before[key])
		value.text = "%d" % before[key] if next == before[key] else "%d → %d" % [before[key], next]
		value.theme_type_variation = &"StatValue" if next == before[key] else (&"StatUp" if next > before[key] else &"StatDown")


# The sheet as plain text, for tests and accessibility checks.
func stat_text() -> String:
	var parts: Array[String] = []
	for index in STAT_ROWS.size():
		parts.append("%s %s" % [STAT_ROWS[index][0], stat_values[index].text])
	return " / ".join(parts)


# A slot shows the equipped item's icon beside its caption, with the name on
# the full width below, laid out by Containers inside the Button; the Button
# keeps input and focus.
func _build_slot(button: Button, slot: int) -> void:
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"CompactMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Glyph and caption share the top line; the name gets the full width below.
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"CompactStack"
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)
	var header := HBoxContainer.new()
	header.theme_type_variation = &"CompactRow"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(header)
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2.ONE * SLOT_ICON
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(_draw_slot_glyph.bind(slot, glyph))
	header.add_child(glyph)
	slot_glyphs.append(glyph)
	var caption := HubUI.label(header, SLOT_CAPTIONS[slot], &"HudSmall")
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label := HubUI.label(stack, "", &"")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	slot_names.append(name_label)
	button.toggled.connect(func(_on: bool): glyph.queue_redraw())


# A stand-in without an id, so ItemGlyph draws the category symbol rather
# than any specific item's icon.
func _empty_slot_symbol(slot: int) -> ItemData:
	var symbol := ItemData.new()
	if slot <= Equipment.Slot.SUB:
		symbol.kind = ItemData.Kind.WEAPON
		symbol.weapon = WeaponData.new()
	else:
		symbol.kind = ItemData.Kind.ARMOR if slot == Equipment.Slot.ARMOR else ItemData.Kind.ACCESSORY
	return symbol


func _draw_slot_glyph(slot: int, glyph: Control) -> void:
	if state == null:
		return
	var item: ItemData = state.equipment.slots[slot]
	if item == null:
		# An empty slot shows the faint common symbol of what it accepts.
		ItemGlyph.paint(glyph, Rect2(Vector2.ONE * 8, glyph.size - Vector2.ONE * 16), _empty_slot_symbol(slot), glyph.get_theme_color(&"font_color", &"HudSmall"))
		return
	# Equipped art stays at full colour; only the drawn fallback symbol dims.
	var role := &"GoldLabel" if slots[slot].button_pressed or slot == Equipment.Slot.MAIN else &"Label"
	ItemGlyph.paint(glyph, Rect2(Vector2.ZERO, glyph.size), item, glyph.get_theme_color(&"font_color", role))


# Success moment after saving: the chosen candidate flies into its slot, which
# then acknowledges it while the adventurer brightens. Swaps and removals
# have no single item to carry and only pulse their slots.
func present_equip(changed: Array[int]) -> void:
	if equipped_item != null and changed.size() == 1 and is_visible_in_tree():
		var slot := slots[changed[0]]
		UIMotion.fly_glyph(self, equipped_item, showcase.visual, slot).finished.connect(func():
			if is_instance_valid(slot) and slot.is_visible_in_tree():
				UIMotion.of(slot).pulse()
				UIMotion.of(portrait).flash()
				UIMotion.of(stat_sheet).pulse(1.04, UIMotion.GOLD_TIME))
	else:
		for index in changed:
			UIMotion.of(slots[index]).pulse()
	equipped_item = null


func select_slot(slot: int) -> void:
	selected_slot = slot
	refresh(state)
	if not candidate_list.get_selected_items().is_empty():
		UIMotion.of(candidate_list).select_card()
	UIMotion.reveal_selection([showcase, comparison])


func _select_candidate(_index: int) -> void:
	_compare()
	UIMotion.reveal_selection([showcase, comparison])


func _fill_candidates() -> void:
	candidates.clear()
	candidate_list.clear()
	for from_storage in [false, true]:
		var source := state.storage if from_storage else state.inventory
		for index in source.entries.size():
			var item := source.entries[index].item
			if state.equipment.accepts(item, selected_slot) or (item.kind == ItemData.Kind.SCROLL and state.equipment.can_socket(selected_slot)):
				candidates.append({"from_storage": from_storage, "index": index, "item": item})
				candidate_list.add_card(item, source.entries[index].count, -1, "倉庫" if from_storage else "所持")
				candidate_list.set_item_tooltip(candidate_list.item_count - 1, ItemTooltipList.description(item))
	if candidates.is_empty():
		candidate_list.add_item("この枠に装備できる候補はありません")
		candidate_list.set_item_disabled(0, true)
	else:
		candidate_list.select(0)
	_compare()


func _compare() -> void:
	comparison.reset()
	scroll_remove_button.visible = state.equipment.can_socket(selected_slot) and state.equipment.slots[selected_slot].socketed_scroll != null
	equip_button.text = "選択した装備に変更"
	unequip_button.disabled = selected_slot == Equipment.Slot.MAIN or state.equipment.slots[selected_slot] == null
	var selected := candidate_list.get_selected_items()
	equip_button.disabled = selected.is_empty() or candidates.is_empty()
	if equip_button.disabled:
		showcase.present(state.equipment.slots[selected_slot])
		comparison.text = "候補を選ぶと、変更前後の差分を表示します。\n主武器は外せません。"
		return
	var candidate: ItemData = candidates[selected[0]].item
	showcase.present(candidate)
	if candidate.kind == ItemData.Kind.SCROLL:
		comparison.line(candidate.label(), &"HeadingLabel")
		comparison.line(candidate.description())
		comparison.line("交換前の魔法は選択元に戻ります。", &"MutedLabel")
		equip_button.text = "選択枠の杖に魔法を装着"
		return
	var preview := Equipment.new()
	preview.slots.assign(state.equipment.slots)
	preview.slots[selected_slot] = candidate
	var before := state.preparation_stats()
	var after := state.preparation_stats(preview)
	var current := state.equipment.slots[selected_slot]
	_show_stats(before, after)
	comparison.line("%sに装備した場合（現在：%s）" % [SLOT_CAPTIONS[selected_slot], current.label() if current != null else "なし"], &"MutedLabel")
	# Only values that change; an unchanged list hides the one that matters.
	var rows: Array = []
	for stat: Array in [["HP", "hp"], ["攻撃力", "attack"], ["防御力", "defense"]]:
		if before[stat[1]] != after[stat[1]]:
			rows.append([stat[0], before[stat[1]], after[stat[1]]])
	if candidate.kind == ItemData.Kind.WEAPON:
		var old_reach := current.weapon.reach if current != null else 0
		if old_reach != candidate.weapon.reach:
			rows.append(["この枠の射程", old_reach, candidate.weapon.reach])
	comparison.stat_table(rows)
	if rows.is_empty():
		comparison.line("能力値は変わりません", &"MutedLabel")
	comparison.item_text(candidate, showcase)
	if current != null:
		comparison.line("外す装備", &"ItemNameLabel")
		comparison.line("%s　%s" % [current.label(), ItemGlyph.main_effect(current)], &"MutedLabel")


func _equip() -> void:
	var selected := candidate_list.get_selected_items()
	if selected.is_empty() or candidates.is_empty():
		return
	var candidate := candidates[selected[0]]
	equipped_item = candidate.item
	equip_requested.emit(candidate.from_storage, candidate.index, selected_slot)

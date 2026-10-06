class_name HubEquipment
extends Control

# The equipment page, in the shop's order: choose a slot (the five slots as
# open rows on a slab like the lobby menu), learn its candidates (their list,
# the chosen one's art and note, the lesser actions and the one equip
# action), then see what they do to her (the heroine from the knees up with
# her whole stats before and after). Leaving is the back key; this page holds
# no button that only moves elsewhere.

signal equip_requested(from_storage: bool, index: int, slot: int)
signal unequip_requested(slot: int)
signal scroll_remove_requested(slot: int)
signal swap_requested
signal warehouse_requested

var state: RunCarryover
var selected_slot := 0
var candidates: Array[Dictionary] = []
var slots: Array[Button] = []
var slot_names: Array[Label] = []
var slot_glyphs: Array[Control] = []
var slot_rows: VBoxContainer
var candidate_heading: Label
var candidate_list: ItemCardList
var carried_label: Label
var comparison: ItemDetails
var equip_button: Button
var unequip_button: Button
var swap_button: Button
var scroll_remove_button: Button
var showcase: ItemShowcase
var hero_stats: HeroStats
var _candidates_column: VBoxContainer
# The candidate of the last equip request, for the success moment after saving.
var equipped_item: ItemData
const SLOT_CAPTIONS := Equipment.SLOT_NAMES
# Slot art is the 48px item icon at its native size, so it is never blurred.
const SLOT_ICON := 48
const SLOT_HEIGHT := 72.0
# The chosen candidate at twice its 48px icon beside its name.
const SHOWCASE_SIZE := 120.0
const BAND_TIP := 18.0


func _ready() -> void:
	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"ShopColumns"
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_slots(HubUI.open_column(columns, 0.72, &"SlabSolid"))
	_candidates_column = HubUI.open_column(columns, 1.15, &"SlabColumn")
	_build_candidates(_candidates_column)
	hero_stats = HeroStats.new()
	hero_stats.size_flags_stretch_ratio = 0.95
	columns.add_child(hero_stats)
	# What the candidate would change stands under its note, right above
	# the equip action; she stays on the right.
	hero_stats.move_stats_to(comparison.get_parent(), comparison.get_index() + 1)


func _build_slots(column: VBoxContainer) -> void:
	column.theme_type_variation = &"DetailStack"
	HubUI.label(column, "装備枠", &"NoteLabel")
	slot_rows = VBoxContainer.new()
	slot_rows.theme_type_variation = &"SlotRows"
	column.add_child(slot_rows)
	# The band is the rows' own drawing under the slots, so it can slide.
	UIMotion.of(slot_rows)
	slot_rows.draw.connect(_draw_slot_band)
	for slot in 5:
		var control := HubUI.button(slot_rows, "", select_slot.bind(slot), &"SlotRow")
		control.custom_minimum_size = Vector2(0, SLOT_HEIGHT)
		control.toggle_mode = true
		# Enter on a slot goes on to its candidates.
		control.gui_input.connect(_slot_accept.bind(control, slot))
		control.draw.connect(_draw_slot_row.bind(control, slot))
		slots.append(control)
		_build_slot(control, slot)
	HubUI.space(column)
	# What she carries is the warehouse's to arrange; here only its count.
	HubUI.rule(column)
	var carried := HBoxContainer.new()
	carried.theme_type_variation = &"CompactRow"
	column.add_child(carried)
	carried_label = HubUI.label(carried, "", &"NoteLabel")
	carried_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carried_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HubUI.button(carried, "倉庫で整える  ›", func(): warehouse_requested.emit(), &"TextAction")


func _build_candidates(column: VBoxContainer) -> void:
	column.theme_type_variation = &"DetailStack"
	candidate_heading = HubUI.label(column, "", &"NoteLabel")
	candidate_list = ItemCardList.new()
	candidate_list.theme_type_variation = &"OpenCardList"
	candidate_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(candidate_list)
	candidate_list.item_selected.connect(_select_candidate)
	HubUI.rule(column)
	showcase = ItemShowcase.new()
	showcase.show_effect = false
	showcase.visual.framed = false
	showcase.visual.idle = true
	showcase.visual.custom_minimum_size = Vector2.ONE * SHOWCASE_SIZE
	column.add_child(showcase)
	comparison = ItemDetails.new()
	comparison.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(comparison)
	# A fixed height: a long note scrolls instead of taking the list's room.
	comparison.custom_minimum_size.y = 72
	# The lesser actions read as words; the one equip action is the plate.
	var lesser := HBoxContainer.new()
	lesser.theme_type_variation = &"TextActions"
	column.add_child(lesser)
	unequip_button = HubUI.button(lesser, "外す", func():
		equipped_item = null
		unequip_requested.emit(selected_slot), &"TextAction")
	scroll_remove_button = HubUI.button(lesser, "魔法を外す", func():
		equipped_item = null
		scroll_remove_requested.emit(selected_slot), &"TextAction")
	swap_button = HubUI.button(lesser, "主武器と副武器を入れ替え", func(): swap_requested.emit(), &"TextAction")
	equip_button = HubUI.primary_action(column, "装備する", _equip)
	HubUI.accept_to_action(candidate_list, equip_button)


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
		slots[index].queue_redraw()
	slot_rows.queue_redraw()
	carried_label.text = "持ち込み　%d / %d 枠" % [state.inventory.entries.size(), state.inventory.max_entries]
	candidate_heading.text = "%sの候補" % SLOT_CAPTIONS[selected_slot]
	_fill_candidates()


# A slot reads as the equipped item's icon, the slot's name small above the
# item's; the Button keeps input and focus.
func _build_slot(button: Button, slot: int) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"CompactRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -BAND_TIP - 6
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2.ONE * SLOT_ICON
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(_draw_slot_glyph.bind(slot, glyph))
	row.add_child(glyph)
	slot_glyphs.append(glyph)
	var text := VBoxContainer.new()
	text.theme_type_variation = &"CompactStack"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var caption := HubUI.label(text, SLOT_CAPTIONS[slot], &"NoteLabel")
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	var name_label := HubUI.label(text, "", &"ItemNameLabel")
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	slot_names.append(name_label)
	button.toggled.connect(func(_on: bool): glyph.queue_redraw())


# The slots other than the chosen one are parted by faint rules.
func _draw_slot_row(button: Button, slot: int) -> void:
	var rect := Rect2(Vector2.ZERO, button.size)
	var rail := button.get_theme_color(&"rail", &"HubLobby")
	if not button.button_pressed and slot < SLOT_CAPTIONS.size() - 1:
		var y := rect.end.y - 0.5
		button.draw_polyline_colors(PackedVector2Array([Vector2(0, y), Vector2(rect.size.x * 0.5, y), Vector2(rect.size.x, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.22), Color(rail, 0.0)]), 1.0, true)


# The chosen slot is the lobby menu's warm band pointed at the candidates,
# sliding from the slot chosen before (UIMotion.follow_mark).
func _draw_slot_band() -> void:
	var chosen := slots[selected_slot]
	var target := Rect2(chosen.position + Vector2(0, 4), chosen.size - Vector2(0, 8))
	var rect := UIMotion.of(slot_rows).follow_mark(target)
	var rail := slot_rows.get_theme_color(&"rail", &"HubLobby")
	var band := slot_rows.get_theme_color(&"band", &"HubLobby")
	# It arrives with its slot when the page opens.
	var alpha := chosen.modulate.a
	var tip := rect.end.x
	var middle := rect.get_center().y
	var outline := PackedVector2Array([rect.position, Vector2(tip - BAND_TIP, rect.position.y), Vector2(tip, middle), Vector2(tip - BAND_TIP, rect.end.y), Vector2(rect.position.x, rect.end.y)])
	slot_rows.draw_polygon(outline, PackedColorArray([Color(band, band.a * 0.5 * alpha), Color(band, band.a * 1.6 * alpha), Color(band, band.a * 1.8 * alpha), Color(band, band.a * 1.6 * alpha), Color(band, band.a * 0.5 * alpha)]))
	slot_rows.draw_polyline_colors(outline, PackedColorArray([Color(rail, 0.0), Color(rail, 0.85 * alpha), Color(rail, alpha), Color(rail, 0.85 * alpha), Color(rail, 0.0)]), 1.5, true)


# Opening the page: the slots arrive top first, the candidates a beat later,
# the heroine last from the screen's right edge.
func play_entrance() -> void:
	for index in slots.size():
		UIMotion.of(slots[index]).appear(UIMotion.ROW_STAGGER * index, UIMotion.ROW_TIME)
	# The band reads its slot's fade, so the rows redraw while they arrive.
	slot_rows.create_tween().tween_method(func(_at: float): slot_rows.queue_redraw(), 0.0, 1.0, UIMotion.rows_time(slots.size()))
	candidate_list.play_intro()
	UIMotion.of(_candidates_column).appear(UIMotion.STAGGER_TIME)
	hero_stats.play_entrance(UIMotion.STAGGER_TIME * 2)


func _draw_slot_glyph(slot: int, glyph: Control) -> void:
	if state == null:
		return
	var item: ItemData = state.equipment.slots[slot]
	if item == null:
		# An empty slot shows the faint common symbol of what it accepts.
		ItemGlyph.paint(glyph, Rect2(Vector2.ONE * 8, glyph.size - Vector2.ONE * 16), ItemGlyph.slot_symbol(slot), glyph.get_theme_color(&"font_color", &"NoteLabel"))
		return
	# Gold only marks the chosen slot.
	var role := &"GoldLabel" if slots[slot].button_pressed else &"Label"
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
				UIMotion.of(hero_stats.hero).flash()
				UIMotion.of(hero_stats.specs).pulse(1.04, UIMotion.GOLD_TIME))
	else:
		for index in changed:
			UIMotion.of(slots[index]).pulse()
	equipped_item = null


func select_slot(slot: int) -> void:
	selected_slot = slot
	refresh(state)
	# Focus follows the choice, so the focus edge never sits on another slot.
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused is Button and slots.has(focused):
		slots[slot].grab_focus()
	# Another slot's candidates: their rows arrive anew.
	candidate_list.play_intro()
	if not candidate_list.get_selected_items().is_empty():
		UIMotion.of(candidate_list).select_card()
	UIMotion.reveal_selection([showcase, comparison])


func _slot_accept(event: InputEvent, control: Button, slot: int) -> void:
	if not event.is_action_pressed("ui_accept") or event.is_echo():
		return
	control.accept_event()
	select_slot(slot)
	if candidate_list.item_count > 0:
		candidate_list.grab_focus()


func step_slot(direction: int) -> void:
	select_slot(posmod(selected_slot + direction, slots.size()))


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
	candidate_list.empty_text = "この枠に付けられる品はない"
	if not candidates.is_empty():
		candidate_list.select(0)
	_compare()


func _compare() -> void:
	comparison.reset()
	var current := state.equipment.slots[selected_slot]
	scroll_remove_button.visible = state.equipment.can_socket(selected_slot) and current.socketed_scroll != null
	equip_button.text = "装備する"
	equip_button.tooltip_text = ""
	# The Main weapon cannot be taken off; an empty slot has nothing to take.
	unequip_button.visible = selected_slot != Equipment.Slot.MAIN
	unequip_button.disabled = current == null
	var selected := candidate_list.get_selected_items()
	equip_button.disabled = selected.is_empty() or candidates.is_empty()
	var before := state.preparation_stats()
	if equip_button.disabled:
		showcase.present(current)
		comparison.line("今の装備です。" if current != null else "この枠は空いています。", &"NoteLabel")
		hero_stats.show_stats(before)
		return
	var candidate: ItemData = candidates[selected[0]].item
	showcase.present(candidate)
	if candidate.kind == ItemData.Kind.SCROLL:
		comparison.line(candidate.description(), &"NoteLabel")
		equip_button.text = "杖に魔法を込める"
		equip_button.tooltip_text = "込めてあった魔法は、元の場所へ戻る"
		hero_stats.show_stats(before)
		return
	var preview := Equipment.new()
	preview.slots.assign(state.equipment.slots)
	preview.slots[selected_slot] = candidate
	hero_stats.show_stats(before, state.preparation_stats(preview), HeroStats.swap_text(selected_slot, current))
	comparison.item_text(candidate, showcase, &"NoteLabel")


func _equip() -> void:
	var selected := candidate_list.get_selected_items()
	if selected.is_empty() or candidates.is_empty():
		return
	var candidate := candidates[selected[0]]
	equipped_item = candidate.item
	equip_requested.emit(candidate.from_storage, candidate.index, selected_slot)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var pad: bool = event is InputEventJoypadButton and event.pressed
	var back: bool = (key and event.keycode == KEY_Q) or (pad and event.button_index == JOY_BUTTON_LEFT_SHOULDER)
	var next: bool = (key and event.keycode == KEY_E) or (pad and event.button_index == JOY_BUTTON_RIGHT_SHOULDER)
	if back or next:
		step_slot(-1 if back else 1)
		get_viewport().set_input_as_handled()

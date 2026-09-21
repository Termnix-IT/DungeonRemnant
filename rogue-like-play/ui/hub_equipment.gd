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
var candidate_list: ItemCardList
var carried_list: ItemCardList
var stats_label: Label
var comparison: ItemDetails
var equip_button: Button
var unequip_button: Button
var done_button: Button
var swap_button: Button
var scroll_remove_button: Button
var showcase: ItemShowcase


func _ready() -> void:
	var columns := HubUI.columns(self)
	var catalog := HubUI.section(columns, 1.03)
	HubUI.label(catalog, "装備候補", &"HeadingLabel")
	HubUI.label(catalog, "所持品・倉庫から選択", &"MutedLabel")
	candidate_list = ItemCardList.new()
	candidate_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.add_child(candidate_list)
	candidate_list.item_selected.connect(func(_index: int): _compare(); UIMotion.of(comparison).reveal())
	HubUI.label(catalog, "持ち込みアイテム", &"BodyLabel")
	carried_list = ItemCardList.new()
	carried_list.custom_minimum_size.y = 112
	catalog.add_child(carried_list)
	HubUI.button(catalog, "倉庫で持ち込みを整理", func(): warehouse_requested.emit())
	var detail := HubUI.section(columns, 1.0)
	showcase = ItemShowcase.new()
	detail.add_child(showcase)
	comparison = ItemDetails.new()
	comparison.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(comparison)
	equip_button = HubUI.button(detail, "選択した装備に変更", _equip, &"GoldButton")
	unequip_button = HubUI.button(detail, "選択枠の装備を外す", func(): unequip_requested.emit(selected_slot))
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
	var portrait := CharacterPreview.new()
	portrait.custom_minimum_size = Vector2(120, 180)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_stretch_ratio = 2.0
	body.add_child(portrait)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(right)
	for slot in 5:
		var parent := left if slot < 2 else right
		var control := HubUI.button(parent, "", select_slot.bind(slot), &"ItemButton")
		control.custom_minimum_size = Vector2(98, 70)
		control.clip_text = true
		control.toggle_mode = true
		slots.append(control)
	stats_label = HubUI.label(build, "", &"BodyLabel")
	scroll_remove_button = HubUI.button(build, "選択枠の魔法を外す", func(): scroll_remove_requested.emit(selected_slot))
	swap_button = HubUI.button(build, "Main / Sub を入れ替え", func(): swap_requested.emit())
	done_button = HubUI.button(build, "準備完了・ステージ選択へ", func(): done_requested.emit())


func refresh(current: RunCarryover) -> void:
	state = current
	swap_button.disabled = state.equipment.slots[Equipment.Slot.SUB] == null
	for index in slots.size():
		slots[index].set_pressed_no_signal(index == selected_slot)
		var item := state.equipment.slots[index]
		slots[index].text = "%s\n%s" % [["主武器", "副武器", "防具", "装飾 1", "装飾 2"][index], item.label() if item != null else "未装備"]
		slots[index].tooltip_text = Equipment.SLOT_NAMES[index] + "：" + (ItemTooltipList.description(item) if item != null else "未装備")
	var stats := state.preparation_stats()
	stats_label.text = "次のRun：HP %d / ATK %d\nDEF %d / Main射程 %d" % [stats.hp, stats.attack, stats.defense, stats.reach]
	carried_list.clear()
	for entry in state.inventory.entries:
		carried_list.add_card(entry.item, entry.count)
	if carried_list.item_count == 0:
		carried_list.add_item("持ち込みアイテムはありません")
		carried_list.set_item_disabled(0, true)
	_fill_candidates()


func select_slot(slot: int) -> void:
	selected_slot = slot
	refresh(state)
	UIMotion.of(comparison).reveal()


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
		comparison.text = "候補を選ぶと、変更前後の差分を表示します。\nMain Weaponは外せません。"
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
	comparison.line(candidate.label(), &"HeadingLabel")
	comparison.line("現在：%s" % (current.label() if current != null else "なし"), &"MutedLabel")
	comparison.delta("HP", before.hp, after.hp)
	comparison.delta("ATK", before.attack, after.attack)
	comparison.delta("DEF", before.defense, after.defense)
	if candidate.kind == ItemData.Kind.WEAPON:
		var old_reach := current.weapon.reach if current != null else 0
		comparison.delta("この枠の射程", old_reach, candidate.weapon.reach)
	comparison.line(candidate.description())


func _equip() -> void:
	var selected := candidate_list.get_selected_items()
	if selected.is_empty() or candidates.is_empty():
		return
	var candidate := candidates[selected[0]]
	equip_requested.emit(candidate.from_storage, candidate.index, selected_slot)

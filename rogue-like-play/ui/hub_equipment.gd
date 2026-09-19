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
var candidate_list: ItemList
var carried_list: ItemList
var stats_label: Label
var comparison: Label
var equip_button: Button
var unequip_button: Button
var done_button: Button
var swap_button: Button
var scroll_remove_button: Button


func _ready() -> void:
	HubTheme.panel(self, Vector2.ZERO, Vector2(350, 560))
	HubTheme.label(self, "装備スロット", Vector2(20, 14), Vector2(310, 34), &"HeadingLabel")
	for slot in 5:
		var control := HubTheme.button(self, "", Vector2(18, 60 + slot * 69), Vector2(314, 60), select_slot.bind(slot))
		control.alignment = HORIZONTAL_ALIGNMENT_LEFT
		control.theme_type_variation = &"ItemButton"
		control.toggle_mode = true
		slots.append(control)
	stats_label = HubTheme.label(self, "", Vector2(20, 411), Vector2(310, 83), &"MutedLabel")
	swap_button = HubTheme.button(self, "Main / Sub を入れ替え", Vector2(18, 500), Vector2(314, 48), func(): swap_requested.emit(), &"SecondaryButton")
	scroll_remove_button = HubTheme.button(self, "選択枠の魔法を外す", Vector2(18, 463), Vector2(314, 32), func(): scroll_remove_requested.emit(selected_slot), &"SecondaryButton")
	HubTheme.panel(self, Vector2(370, 0), Vector2(470, 560))
	HubTheme.label(self, "装備候補  /  所持品・倉庫", Vector2(390, 14), Vector2(430, 34), &"HeadingLabel")
	candidate_list = ItemList.new()
	HubTheme.place(candidate_list, self, Vector2(390, 60), Vector2(430, 266))
	candidate_list.item_selected.connect(func(_index: int): _compare())
	comparison = HubTheme.label(self, "", Vector2(390, 344), Vector2(430, 128), &"BodyLabel")
	equip_button = HubTheme.button(self, "選択した装備に変更", Vector2(390, 490), Vector2(270, 48), _equip)
	unequip_button = HubTheme.button(self, "外す", Vector2(672, 490), Vector2(148, 48), func(): unequip_requested.emit(selected_slot), &"SecondaryButton")
	HubTheme.panel(self, Vector2(860, 0), Vector2(420, 560))
	HubTheme.label(self, "持ち込みアイテム", Vector2(880, 14), Vector2(380, 34), &"HeadingLabel")
	carried_list = ItemList.new()
	HubTheme.place(carried_list, self, Vector2(880, 60), Vector2(380, 258))
	HubTheme.label(self, "所持品はすべて次のRunへ持ち込みます。\n持ち込まない品は倉庫へ。", Vector2(880, 338), Vector2(380, 72), &"MutedLabel")
	HubTheme.button(self, "倉庫で持ち込みを整理", Vector2(880, 422), Vector2(380, 48), func(): warehouse_requested.emit())
	done_button = HubTheme.button(self, "準備完了・ステージ選択へ", Vector2(880, 490), Vector2(380, 48), func(): done_requested.emit())


func refresh(current: RunCarryover) -> void:
	state = current
	swap_button.disabled = state.equipment.slots[Equipment.Slot.SUB] == null
	for index in slots.size():
		slots[index].set_pressed_no_signal(index == selected_slot)
		var item := state.equipment.slots[index]
		slots[index].text = "%s  %s\n%s" % ["›" if index == selected_slot else " ", Equipment.SLOT_NAMES[index], item.label() if item != null else "なし"]
	var stats := state.preparation_stats()
	stats_label.text = "次のRun：HP %d / ATK %d\nDEF %d / Main射程 %d" % [stats.hp, stats.attack, stats.defense, stats.reach]
	HubTheme.fill_inventory(carried_list, state.inventory)
	if carried_list.item_count == 0:
		carried_list.add_item("持ち込みアイテムはありません")
		carried_list.set_item_disabled(0, true)
	_fill_candidates()


func select_slot(slot: int) -> void:
	selected_slot = slot
	refresh(state)


func _fill_candidates() -> void:
	candidates.clear()
	candidate_list.clear()
	for from_storage in [false, true]:
		var source := state.storage if from_storage else state.inventory
		for index in source.entries.size():
			var item := source.entries[index].item
			if state.equipment.accepts(item, selected_slot) or (item.kind == ItemData.Kind.SCROLL and state.equipment.can_socket(selected_slot)):
				candidates.append({"from_storage": from_storage, "index": index, "item": item})
				candidate_list.add_item("[%s]  %s" % ["倉庫" if from_storage else "所持", item.display_name])
	if candidates.is_empty():
		candidate_list.add_item("この枠に装備できる候補はありません")
		candidate_list.set_item_disabled(0, true)
	else:
		candidate_list.select(0)
	_compare()


func _compare() -> void:
	scroll_remove_button.visible = state.equipment.can_socket(selected_slot) and state.equipment.slots[selected_slot].socketed_scroll != null
	equip_button.text = "選択した装備に変更"
	unequip_button.disabled = selected_slot == Equipment.Slot.MAIN or state.equipment.slots[selected_slot] == null
	var selected := candidate_list.get_selected_items()
	equip_button.disabled = selected.is_empty() or candidates.is_empty()
	if equip_button.disabled:
		comparison.text = "候補を選ぶと、変更前後の差分を表示します。\nMain Weaponは外せません。"
		return
	var candidate: ItemData = candidates[selected[0]].item
	if candidate.kind == ItemData.Kind.SCROLL:
		comparison.text = candidate.description() + "\n交換前の魔法は選択元に戻ります。"
		equip_button.text = "選択枠の杖に魔法を装着"
		return
	var preview := Equipment.new()
	preview.slots.assign(state.equipment.slots)
	preview.slots[selected_slot] = candidate
	var before := state.preparation_stats()
	var after := state.preparation_stats(preview)
	var current := state.equipment.slots[selected_slot]
	comparison.text = "%s → %s\nHP %+d   ATK %+d   DEF %+d\n%s" % [current.display_name if current != null else "なし", candidate.display_name, after.hp - before.hp, after.attack - before.attack, after.defense - before.defense, candidate.description()]
	if candidate.kind == ItemData.Kind.WEAPON:
		var old_reach := current.weapon.reach if current != null else 0
		comparison.text += "\nこの枠の射程：%d → %d (%+d)" % [old_reach, candidate.weapon.reach, candidate.weapon.reach - old_reach]


func _equip() -> void:
	var selected := candidate_list.get_selected_items()
	if selected.is_empty() or candidates.is_empty():
		return
	var candidate := candidates[selected[0]]
	equip_requested.emit(candidate.from_storage, candidate.index, selected_slot)

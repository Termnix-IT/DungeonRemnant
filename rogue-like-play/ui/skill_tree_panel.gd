class_name SkillTreePanel
extends Control

signal hp_requested
signal skill_requested(id: StringName)
signal entry_requested(stage: StageData, floor_number: int)
var state: RunCarryover
var root_button: Button
var root_label: Label
var nodes: Dictionary = {}
var entry_buttons: Array[Button] = []
var stage_choice: OptionButton
var stages: Array[StageData] = [preload("res://data/stages/ancient_ruins.tres"), preload("res://data/stages/forest.tres")]

func _ready() -> void:
	HubTheme.panel(self, Vector2.ZERO, Vector2(620, 560))
	HubTheme.panel(self, Vector2(640, 0), Vector2(640, 560))
	HubTheme.label(self, "ステータス強化", Vector2(22, 14), Vector2(580, 36), 25)
	root_label = HubTheme.label(self, "", Vector2(22, 56), Vector2(580, 34), 17)
	root_button = HubTheme.button(self, "", Vector2(22, 96), Vector2(576, 44), func(): hp_requested.emit())
	for index in SkillCatalog.NODES.size():
		var node := SkillCatalog.NODES[index]
		var button := HubTheme.button(self, "", Vector2(22, 154 + index * 96), Vector2(576, 84), func(): skill_requested.emit(node.id))
		button.add_theme_font_size_override("font_size", 17)
		nodes[node.id] = button
	HubTheme.label(self, "ダンジョン途中解放", Vector2(662, 14), Vector2(596, 36), 25)
	HubTheme.label(self, "中ボス撃破後にコインで解放。Lv1と永久強化で開始。", Vector2(662, 57), Vector2(596, 40), 17)
	stage_choice = OptionButton.new()
	for stage in stages:
		stage_choice.add_item(stage.display_name)
	HubTheme.place(stage_choice, self, Vector2(662, 103), Vector2(596, 42))
	stage_choice.item_selected.connect(func(_index: int): refresh(state))
	for index in 4:
		var floor_number := 11 + index * 10
		var button := HubTheme.button(self, "", Vector2(662, 161 + index * 94), Vector2(596, 78), func(): entry_requested.emit(stages[stage_choice.selected], floor_number))
		button.add_theme_font_size_override("font_size", 18)
		entry_buttons.append(button)

func refresh(current: RunCarryover) -> void:
	state = current
	root_label.text = "最大HP（基礎） %d / 3　→ 生命力・攻撃力・魔力量" % state.hp_upgrade_level
	var hp_cost := state.upgrade.price(state.hp_upgrade_level)
	root_button.text = "基礎HP：強化上限" if hp_cost < 0 else "最大HP +1　 /　%d Gold" % hp_cost
	root_button.disabled = hp_cost < 0 or state.gold < hp_cost
	for node in SkillCatalog.NODES:
		var rank := state.skill_rank(node.id)
		var cost := node.price(rank)
		var prerequisite := "基礎HP" if node.prerequisite == &"hp" else SkillCatalog.find(node.prerequisite).display_name
		nodes[node.id].text = "%s %d / %d（1段階 +%d）\n%s Lv%d → %s" % [node.display_name, rank, node.max_rank, node.amount, prerequisite, node.prerequisite_rank, "%d Gold" % cost if cost >= 0 else "強化上限"]
		nodes[node.id].disabled = not state.can_purchase_skill(node.id)
	var stage := stages[stage_choice.selected]
	for index in 4:
		var floor_number := 11 + index * 10
		var status := "解放済み" if floor_number in state.unlocked_entries.get(String(stage.id), []) else ("%d Gold" % stage.entry_costs[index] if floor_number - 1 in state.defeated_bosses.get(String(stage.id), []) else "%dFの中ボス撃破が必要" % (floor_number - 1))
		entry_buttons[index].text = "%dFから開始\n%s" % [floor_number, status]
		entry_buttons[index].disabled = not state.can_unlock_entry(stage, floor_number)

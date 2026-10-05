extends CanvasLayer

signal start_requested
signal skill_requested(id: StringName)
signal entry_requested(stage: StageData, floor_number: int)
signal purchase_requested
signal storage_transfer_requested(from_storage: bool, index: int)
signal equip_requested(from_storage: bool, index: int, slot: int)
signal unequip_requested(slot: int)
signal scroll_remove_requested(slot: int)
signal swap_requested
signal sell_requested(from_storage: bool, index: int, amount: int)
signal buy_requested(to_storage: bool, item_id: StringName, amount: int)
signal settings_changed

@export var stages: Array[StageData] = [preload("res://data/stages/ancient_ruins.tres"), preload("res://data/stages/forest.tres"), preload("res://data/stages/unknown.tres")]
var gold_label: Label
var equipment_label: Label
var carried_label: Label
var stored_label: Label
var main_glyph: Control
var upgrade_label: Label
var feedback: Label
var purchase_button: Button
var start_button: Button
var save_label: Label
var warehouse_button: Button
var equipment_button: Button
var sell_button: Button
var upgrade_button: Button
var back_button: Button
var title_label: Label
var subtitle_label: Label
var equipment_page: HubEquipment
var sell_page: HubSell
var departure_page: HubDeparture
var home_page: HubLobby
var decide_button: Button
var hero_button: Button
var hero_speech: Panel
var settings := GameSettings.new()
var upgrade_page: Control
var settings_page: HubSettings
var page := "home"
var equipment_return := "stages"
var _state: RunCarryover
var _content: Control
var _page_host: Control
var _shell: VBoxContainer
var _warehouse_focus: Control
var _ambience: HubAmbience
var _title_block: HBoxContainer
var purse: GoldPurse
var key_guide: KeyGuide
@onready var warehouse_panel: WarehousePanel = $WarehousePanel


func _ready() -> void:
	var background := TextureRect.new()
	background.texture = preload("res://art/hub/lobby_hall.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.16)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# Flickering light and dust over the painting, beneath every panel.
	_ambience = HubAmbience.new()
	add_child(_ambience)
	_content = Control.new()
	_content.name = "Content"
	_content.theme = HubTheme.create()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_resize()
	get_viewport().size_changed.connect(_resize)
	_shell = VBoxContainer.new()
	_content.add_child(_shell)
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 86
	_shell.add_child(header)
	# Header: the screen's name and line on the left, Gold on the right. The
	# lobby keeps only Gold, and no screen carries the game's logo.
	_title_block = HBoxContainer.new()
	_title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_block)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_block.add_child(heading)
	title_label = HubUI.label(heading, "旅支度の間", &"TitleLabel")
	subtitle_label = HubUI.label(heading, "小さな準備が、大きな冒険につながる。", &"MutedLabel")
	purse = GoldPurse.new()
	purse.custom_minimum_size.x = 220
	purse.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(purse)
	# PurseValue takes its colour from GoldLabel, shared with quotes and the
	# warehouse balance.
	gold_label = purse.value_label
	_page_host = Control.new()
	_page_host.custom_minimum_size.y = 600
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_child(_page_host)
	_build_home()
	equipment_page = _page(HubEquipment.new()) as HubEquipment
	equipment_page.equip_requested.connect(func(source: bool, index: int, slot: int): equip_requested.emit(source, index, slot))
	equipment_page.unequip_requested.connect(func(slot: int): unequip_requested.emit(slot))
	equipment_page.scroll_remove_requested.connect(func(slot: int): scroll_remove_requested.emit(slot))
	equipment_page.swap_requested.connect(func(): swap_requested.emit())
	equipment_page.warehouse_requested.connect(open_warehouse)
	equipment_page.done_requested.connect(func(): show_page(equipment_return))
	sell_page = _page(HubSell.new()) as HubSell
	sell_page.sell_requested.connect(func(source: bool, index: int, amount: int): sell_requested.emit(source, index, amount))
	sell_page.buy_requested.connect(func(destination: bool, item_id: StringName, amount: int): buy_requested.emit(destination, item_id, amount))
	sell_page.mode_changed.connect(func():
		feedback.text = ""
		_shop_hints())
	# Buying and selling switch at the title's place in the header.
	var heading_box: VBoxContainer = title_label.get_parent()
	heading_box.add_child(sell_page.mode_tabs)
	heading_box.move_child(sell_page.mode_tabs, 0)
	sell_page.mode_tabs.visible = false
	departure_page = _page(HubDeparture.new()) as HubDeparture
	departure_page.confirm_requested.connect(func(): show_page("confirm"))
	departure_page.equipment_requested.connect(func(): equipment_return = "confirm"; show_page("equipment"))
	departure_page.departure_requested.connect(func(): start_requested.emit())
	var tree := SkillTreePanel.new()
	upgrade_page = _page(tree)
	settings_page = _page(HubSettings.new()) as HubSettings
	settings_page.changed.connect(func(): settings_changed.emit())
	tree.hp_requested.connect(func(): purchase_requested.emit())
	tree.skill_requested.connect(func(id: StringName): skill_requested.emit(id))
	tree.entry_requested.connect(func(stage: StageData, floor_number: int): entry_requested.emit(stage, floor_number))
	purchase_button = tree.upgrade_button
	upgrade_label = tree.root_label
	# Footer: the key guide at the bottom left, the same on every screen.
	var footer := HBoxContainer.new()
	footer.theme_type_variation = &"KeyGuide"
	_shell.add_child(footer)
	key_guide = KeyGuide.new()
	key_guide.custom_minimum_size.y = 44
	footer.add_child(key_guide)
	back_button = key_guide.add_hint("Esc", "B", "戻る", go_back)
	feedback = HubUI.label(footer, "", &"GoldLabel")
	feedback.custom_minimum_size.y = 44
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_label = HubUI.label(_shell, "", &"MutedLabel")
	warehouse_panel.theme = _content.theme
	warehouse_panel.transfer_requested.connect(func(source: bool, index: int): storage_transfer_requested.emit(source, index))
	warehouse_panel.closed.connect(_warehouse_closed)
	warehouse_panel.equipment_requested.connect(func(): show_page("equipment"))
	move_child(warehouse_panel, get_child_count() - 1)
	UIMotion.bind_buttons(_content)
	UIMotion.bind_buttons(home_page)
	UIMotion.bind_buttons(warehouse_panel)


func _page(control: Control) -> Control:
	_page_host.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.hide()
	return control


# The lobby spans the whole screen over the hall painting, above the scaled
# page content, so the header's Gold and settings stay reachable through it.
func _build_home() -> void:
	home_page = HubLobby.new()
	home_page.theme = _content.theme
	home_page.settings = settings
	add_child(home_page)
	home_page.hide()
	home_page.selection_changed.connect(func(id: StringName): _ambience.focus(id))
	home_page.activated.connect(_enter)
	start_button = home_page.buttons[0]
	equipment_button = home_page.buttons[1]
	warehouse_button = home_page.buttons[2]
	sell_button = home_page.buttons[3]
	upgrade_button = home_page.buttons[4]
	decide_button = home_page.decide_button
	hero_button = home_page.hero_button
	hero_speech = home_page.hero_speech
	equipment_label = home_page.equipment_label
	main_glyph = home_page.main_glyph
	carried_label = home_page.carried_label
	stored_label = home_page.stored_label


func _enter(id: StringName) -> void:
	match id:
		&"departure":
			show_page("stages")
		&"equipment":
			equipment_return = "stages"
			show_page("equipment")
		&"storage":
			open_warehouse()
		&"shop":
			show_page("sell")
		&"upgrade":
			show_page("upgrade")
		&"settings":
			show_page("settings")


# The stage the departure entry shows: the last one chosen, else the first
# that can be entered.
func featured_stage() -> StageData:
	if departure_page.selected_stage != null and _state.stage_available(departure_page.selected_stage):
		return departure_page.selected_stage
	for stage in stages:
		if _state.stage_available(stage):
			return stage
	return null


# Page content for the 1600×900 base: 80px of hall either side, and the
# whole block shrinks together on smaller screens.
const CONTENT_SIZE := Vector2(1440, 810)


func _resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(1.0, minf((viewport.x - 40) / CONTENT_SIZE.x, (viewport.y - 36) / CONTENT_SIZE.y))
	_content.size = CONTENT_SIZE
	_content.scale = Vector2.ONE * factor
	_content.position = (viewport - _content.size * factor) * 0.5


func refresh(state: RunCarryover, message: String = "") -> void:
	_state = state
	gold_label.text = UIFormat.amount(state.gold)
	home_page.refresh(state, featured_stage())
	(upgrade_page as SkillTreePanel).refresh(state)
	feedback.text = message
	equipment_page.refresh(state)
	sell_page.refresh(state)
	warehouse_panel.refresh(state)
	if page == "confirm":
		departure_page.present_confirmation(state)
	if not home_page.visible and page == "home":
		show_page("home")


func show_page(target: String) -> void:
	if target == "confirm" and (departure_page.selected_stage == null or not _state.stage_available(departure_page.selected_stage)):
		return
	page = target
	hero_speech.hide()
	for control in [home_page, equipment_page, sell_page, departure_page, upgrade_page, settings_page]:
		control.hide()
	key_guide.visible = page != "home"
	key_guide.clear_hints()
	title_label.visible = page != "sell"
	sell_page.mode_tabs.visible = page == "sell"
	# Gold stays where the eye looks for it; it is quiet where nothing costs.
	purse.quiet = page not in ["home", "sell", "upgrade"]
	for child in _title_block.get_children():
		child.visible = page != "home"
	# On the lobby the left edge belongs to the menu.
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if page == "home" else HORIZONTAL_ALIGNMENT_LEFT
	_ambience.focus(home_page.selected_id() if page == "home" else &"")
	feedback.text = ""
	subtitle_label.text = "身につけるもの、背負っていくもの。"
	match page:
		"home":
			title_label.text = "旅支度の間"
			subtitle_label.text = "小さな準備が、大きな冒険につながる。"
			home_page.refresh(_state, featured_stage())
			home_page.show()
			home_page.focus_selected()
		"equipment":
			title_label.text = "装備・持ち込み準備"
			equipment_page.show()
			equipment_page.refresh(_state)
			equipment_page.done_button.text = "出撃確認へ戻る" if equipment_return == "confirm" else "準備完了・ステージ選択へ"
			equipment_page.slots[0].grab_focus()
		"sell":
			title_label.text = "ショップ"
			subtitle_label.text = "薬も武具も、金次第。"
			sell_page.show()
			sell_page.refresh(_state)
			_shop_hints()
			sell_page.source_choice.focus_selected()
		"upgrade":
			title_label.text = "永久強化"
			subtitle_label.text = "冒険の記憶は、この身に残る。"
			upgrade_page.show()
			(upgrade_page as SkillTreePanel).focus_first_action()
		"settings":
			title_label.text = "設定"
			subtitle_label.text = "音と画面を整える。"
			settings_page.show()
			settings_page.refresh(settings)
			settings_page.focus_first()
		"stages":
			title_label.text = "ステージ選択"
			subtitle_label.text = "次は、どこへ潜ろうか。"
			departure_page.show()
			departure_page.present_selection(stages, _state)
		"confirm":
			var stage := departure_page.selected_stage
			title_label.text = "出撃確認  /  %s・全%d階" % [stage.display_name, stage.floor_count]
			subtitle_label.text = "持ち物を確かめたら、出発だ。"
			departure_page.show()
			departure_page.present_confirmation(_state)
	# Pages are anchored in a plain host, not laid out by a Container, so the
	# whole page can slide: forward pages from the right, home from the left.
	var side := -1.0 if page == "home" else 1.0
	for control in [home_page, equipment_page, sell_page, departure_page, upgrade_page, settings_page]:
		if control.visible:
			UIMotion.of(control).enter(0.0, Vector2(side * UIMotion.PAGE_DISTANCE, 0), UIMotion.WINDOW_TIME)


# Routine save notes ("保存済み" and the like) stay out of sight so the hub
# does not read like a page footer; only a status that needs attention shows.
func show_save_status(text: String, alert: bool) -> void:
	save_label.text = text
	save_label.visible = alert


# The shop's keys: the trade, the category tabs and the switch of mode.
func _shop_hints() -> void:
	if page != "sell":
		return
	key_guide.clear_hints()
	key_guide.add_hint("Enter", "A", "購入" if sell_page.buying else "売却")
	key_guide.add_hint("Q / E", "LB / RB", "分類")
	key_guide.add_hint("R", "Y", "売却へ" if sell_page.buying else "購入へ", func(): sell_page.set_buying(not sell_page.buying))


func present_action(kind: StringName, gold_delta: int, slots: Array[int]) -> void:
	# Called only after mutation and persistence succeeded; animation never
	# owns transaction timing, state, focus or input availability.
	preload("res://audio/game_audio.gd").play(self, &"level_up" if kind == &"upgrade" else &"confirm", -22.0)
	if gold_delta != 0:
		feedback.text += "  (%+d G)" % gold_delta
		UIMotion.of(gold_label).pulse(1.08, UIMotion.GOLD_TIME)
	UIMotion.of(feedback).reveal()
	match kind:
		&"buy", &"sell":
			UIMotion.of(sell_page.total_label).pulse(1.025, UIMotion.GOLD_TIME)
			UIMotion.of(sell_page.item_list).reveal()
			sell_page.present_trade(sell_page.possession if kind == &"buy" else gold_label)
		&"equip":
			equipment_page.present_equip(slots)
		&"upgrade":
			(upgrade_page as SkillTreePanel).present_upgrade()
		&"deposit", &"withdraw":
			warehouse_panel.present_move(kind == &"deposit")
			UIMotion.of(warehouse_panel.get_node("%Feedback")).reveal()


func open_warehouse() -> void:
	hero_speech.hide()
	if page == "home":
		equipment_return = "stages"
	_warehouse_focus = _content.get_viewport().gui_get_focus_owner()
	_content.hide()
	home_page.hide()
	warehouse_panel.present(_state)


func _warehouse_closed() -> void:
	_content.show()
	home_page.visible = page == "home"
	if is_instance_valid(_warehouse_focus) and _warehouse_focus.is_visible_in_tree():
		_warehouse_focus.grab_focus()


func go_back() -> void:
	if page == "confirm":
		show_page("stages")
	elif page == "equipment" and equipment_return == "confirm":
		show_page("confirm")
	else:
		show_page("home")


func _unhandled_input(event: InputEvent) -> void:
	if visible and not warehouse_panel.visible and event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

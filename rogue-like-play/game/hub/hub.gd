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
# The page the warehouse goes back to: the lobby or the equipment page.
var warehouse_return := "home"
# The page a "?" mark opened the help from, which back returns to.
var help_return := ""
var _state: RunCarryover
var _content: Control
var _page_host: Control
var _shell: VBoxContainer
var _frame: Control
# The screens that stand in a place of their own rather than in the lobby's
# hall: the weapon rack for the equipment page.
const PAGE_BACKGROUNDS := {"equipment": preload("res://art/hub/pages/equipment.png")}
# How close the header and the footer come to the screen's edges.
const EDGE_X := 40.0
const EDGE_TOP := 22.0
const EDGE_BOTTOM := 16.0
var _ambience: HubAmbience
var _page_background: TextureRect
var _page_background_tween: Tween
var _title_block: HBoxContainer
var purse: GoldPurse
var key_guide: KeyGuide
var warehouse_page: HubWarehouse


func _ready() -> void:
	# HintMarks find the hub here to open the help at their topic.
	add_to_group(&"hub")
	var background := TextureRect.new()
	background.texture = preload("res://art/hub/lobby_hall.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	# A screen with a painting of its own fades it in over the lobby hall.
	_page_background = TextureRect.new()
	_page_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_page_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_page_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_background.modulate.a = 0.0
	add_child(_page_background)
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
	# The header and the footer stand near the screen's edges, outside the
	# page block, in a layer of their own above the lobby; the shell keeps
	# their room so the pages sit where they did.
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.theme = _content.theme
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The header holds the screen's name alone, so the pages begin under it.
	var header_room := Control.new()
	header_room.custom_minimum_size.y = 56
	header_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(header_room)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(header)
	header.anchor_right = 1.0
	header.offset_left = EDGE_X
	header.offset_right = -EDGE_X
	header.offset_top = EDGE_TOP
	# Header: the screen's name on the left, Gold on the right. The lobby
	# keeps only Gold, and no screen carries the game's logo.
	_title_block = HBoxContainer.new()
	_title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_block)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_block.add_child(heading)
	title_label = HubUI.label(heading, "旅支度の間", &"TitleLabel")
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
	sell_page = _page(HubSell.new()) as HubSell
	warehouse_page = _page(HubWarehouse.new()) as HubWarehouse
	warehouse_page.transfer_requested.connect(func(source: bool, index: int): storage_transfer_requested.emit(source, index))
	warehouse_page.equipment_requested.connect(func(): show_page("equipment"))
	# The shop's, the equipment's and the warehouse's slabs run off the
	# screen's left edge (the warehouse's also off its right), their lists
	# lined up with the title and the Gold above them.
	var bleed := EDGE_X - (get_viewport().get_visible_rect().size.x - CONTENT_SIZE.x) * 0.5
	for bleeding: Control in [sell_page, equipment_page, warehouse_page]:
		bleeding.offset_left = bleed
	warehouse_page.offset_right = -bleed
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
	# Its map's slab runs off the left edge; its detail and the heroine off the right.
	departure_page.offset_left = bleed
	departure_page.offset_right = -bleed
	departure_page.confirm_requested.connect(func(): show_page("confirm"))
	departure_page.equipment_requested.connect(func(): equipment_return = "confirm"; show_page("equipment"))
	departure_page.departure_requested.connect(func(): start_requested.emit())
	var tree := SkillTreePanel.new()
	upgrade_page = _page(tree)
	# Its tree's slab runs off the left edge, its detail's off the right.
	tree.offset_left = bleed
	tree.offset_right = -bleed
	heading_box.add_child(tree.mode_tabs)
	heading_box.move_child(tree.mode_tabs, 1)
	tree.mode_tabs.visible = false
	tree.mode_changed.connect(_upgrade_hints)
	settings_page = _page(HubSettings.new()) as HubSettings
	settings_page.offset_left = bleed
	settings_page.changed.connect(func(): settings_changed.emit())
	tree.hp_requested.connect(func(): purchase_requested.emit())
	tree.skill_requested.connect(func(id: StringName): skill_requested.emit(id))
	tree.entry_requested.connect(func(stage: StageData, floor_number: int): entry_requested.emit(stage, floor_number))
	purchase_button = tree.upgrade_button
	# Footer: the key guide at the bottom left, the same on every screen.
	var footer_room := Control.new()
	footer_room.custom_minimum_size.y = 44
	footer_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(footer_room)
	var footer := HBoxContainer.new()
	footer.theme_type_variation = &"KeyGuide"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(footer)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.anchor_right = 1.0
	footer.offset_left = EDGE_X
	footer.offset_right = -EDGE_X
	footer.offset_top = -EDGE_BOTTOM - 44
	footer.offset_bottom = -EDGE_BOTTOM
	key_guide = KeyGuide.new()
	key_guide.custom_minimum_size.y = 44
	footer.add_child(key_guide)
	back_button = key_guide.add_hint("Esc", "B", "戻る", go_back)
	feedback = HubUI.label(footer, "", &"GoldLabel")
	feedback.custom_minimum_size.y = 44
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_label = HubUI.label(_shell, "", &"MutedLabel")
	# Above the lobby.
	move_child(_frame, get_child_count() - 1)
	UIMotion.bind_buttons(_content)
	UIMotion.bind_buttons(_frame)
	UIMotion.bind_buttons(home_page)


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
	warehouse_page.refresh(state)
	if page == "confirm":
		departure_page.present_confirmation(state)
	if not home_page.visible and page == "home":
		show_page("home")


# Crossfades to the page's own painting, or back to the lobby hall when it has
# none; the lobby's lamp flicker belongs to the hall alone.
func _show_page_background() -> void:
	var texture: Texture2D = PAGE_BACKGROUNDS.get(page)
	if _page_background_tween != null:
		_page_background_tween.kill()
	if texture != null:
		_page_background.texture = texture
	var shown := 1.0 if texture != null else 0.0
	_page_background_tween = create_tween().set_trans(Tween.TRANS_SINE).set_parallel()
	_page_background_tween.tween_property(_page_background, "modulate:a", shown, UIMotion.WINDOW_TIME)
	_page_background_tween.tween_property(_ambience, "lights_mix", 1.0 - shown, UIMotion.WINDOW_TIME)


func show_page(target: String) -> void:
	if target == "confirm" and (departure_page.selected_stage == null or not _state.stage_available(departure_page.selected_stage)):
		return
	page = target
	hero_speech.hide()
	for control in [home_page, equipment_page, sell_page, warehouse_page, departure_page, upgrade_page, settings_page]:
		control.hide()
	key_guide.clear_hints()
	# The lobby has nowhere to go back to; it shows how to choose and enter.
	back_button.visible = page != "home"
	title_label.visible = page not in ["sell", "upgrade"]
	sell_page.mode_tabs.visible = page == "sell"
	(upgrade_page as SkillTreePanel).mode_tabs.visible = page == "upgrade"
	# Gold stays where the eye looks for it; it is quiet where nothing costs.
	purse.quiet = page not in ["home", "sell", "upgrade"]
	for child in _title_block.get_children():
		child.visible = page != "home"
	# On the lobby the left edge belongs to the menu.
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if page == "home" else HORIZONTAL_ALIGNMENT_LEFT
	_ambience.focus(home_page.selected_id() if page == "home" else &"")
	_show_page_background()
	feedback.text = ""
	match page:
		"home":
			title_label.text = "旅支度の間"
			home_page.refresh(_state, featured_stage())
			home_page.show()
			home_page.focus_selected()
			key_guide.add_hint("Enter", "A", "決定")
			key_guide.add_hint("↑ / ↓", "▲ / ▼", "選ぶ")
		"equipment":
			title_label.text = "装備・持ち込み準備"
			equipment_page.show()
			equipment_page.refresh(_state)
			key_guide.add_hint("Enter", "A", "装備")
			key_guide.add_hint("Q / E", "LB / RB", "装備枠")
			equipment_page.slots[equipment_page.selected_slot].grab_focus()
		"sell":
			title_label.text = "ショップ"
			sell_page.show()
			sell_page.refresh(_state)
			_shop_hints()
			sell_page.source_choice.focus_selected()
		"warehouse":
			title_label.text = "倉庫"
			warehouse_page.show()
			warehouse_page.present(_state)
			key_guide.add_hint("Enter", "A", "移動")
			key_guide.add_hint("← / →", "◀ / ▶", "持ち込み・倉庫")
		"upgrade":
			title_label.text = "永久強化"
			upgrade_page.show()
			_upgrade_hints()
			(upgrade_page as SkillTreePanel).focus_first_action()
		"settings":
			title_label.text = "設定"
			settings_page.show()
			settings_page.refresh(settings)
			settings_page.focus_first()
			_settings_hints()
		"stages":
			title_label.text = "ステージ選択"
			departure_page.show()
			departure_page.present_selection(stages, _state)
			key_guide.add_hint("Enter", "A", "出撃準備")
			key_guide.add_hint("← / →", "◀ / ▶", "ステージ")
		"confirm":
			title_label.text = "出撃確認"
			departure_page.show()
			departure_page.present_confirmation(_state)
			key_guide.add_hint("Enter", "A", "挑戦")
	# Pages are anchored in a plain host, not laid out by a Container, so the
	# whole page can slide: forward pages from the right, home from the left.
	var side := -1.0 if page == "home" else 1.0
	for control in [home_page, equipment_page, sell_page, warehouse_page, departure_page, upgrade_page, settings_page]:
		if control.visible:
			UIMotion.of(control).enter(0.0, Vector2(side * UIMotion.PAGE_DISTANCE, 0), UIMotion.WINDOW_TIME)
			# Pages built in the screen grammar bring their parts in one by one.
			if control.has_method(&"play_entrance"):
				control.play_entrance()


# Routine save notes ("保存済み" and the like) stay out of sight so the hub
# does not read like a page footer; only a status that needs attention shows.
func show_save_status(text: String, alert: bool) -> void:
	save_label.text = text
	save_label.visible = alert


# The upgrade's keys: the action, moving between nodes, the switch of mode.
func _upgrade_hints() -> void:
	if page != "upgrade":
		return
	var tree := upgrade_page as SkillTreePanel
	key_guide.clear_hints()
	key_guide.add_hint("Enter", "A", "解放" if tree.entries_shown else "強化")
	key_guide.add_hint("矢印", "十字", "選ぶ")
	key_guide.add_hint("R", "Y", "能力の成長へ" if tree.entries_shown else "開始地点へ", func(): tree.set_entries(not tree.entries_shown))


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
			warehouse_page.present_move(kind == &"deposit")


# The warehouse goes back to where it was opened from: the lobby, or the
# equipment page that asked for it.
func open_warehouse() -> void:
	if page == "home":
		equipment_return = "stages"
	warehouse_return = "equipment" if page == "equipment" else "home"
	show_page("warehouse")


# Opens the settings' help at a topic, from a "?" mark anywhere in the hub;
# back returns to where the mark was.
func open_help(topic: int) -> void:
	var from := page
	show_page("settings")
	help_return = from if from != "settings" else ""
	settings_page.open_help(topic)
	_settings_hints()


func _settings_hints() -> void:
	title_label.text = "ヘルプ" if settings_page.help_shown else "設定"
	key_guide.clear_hints()
	key_guide.add_hint("↑ / ↓", "▲ / ▼", "項目")
	if not settings_page.help_shown:
		key_guide.add_hint("← / →", "◀ / ▶", "変更")


func go_back() -> void:
	if page == "settings" and settings_page.help_shown:
		if help_return.is_empty():
			settings_page.close_help()
			_settings_hints()
		else:
			var back := help_return
			help_return = ""
			show_page(back)
		return
	if page == "confirm":
		show_page("stages")
	elif page == "equipment" and equipment_return == "confirm":
		show_page("confirm")
	elif page == "warehouse":
		show_page(warehouse_return)
	else:
		show_page("home")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

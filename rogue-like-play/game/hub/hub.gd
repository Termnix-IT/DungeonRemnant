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

@export var stages: Array[StageData] = [preload("res://data/stages/ancient_ruins.tres"), preload("res://data/stages/forest.tres"), preload("res://data/stages/unknown.tres")]
var gold_label: Label
var equipment_label: Label
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
var home_page: Control
var hero_button: Button
var hero_speech: Panel
var upgrade_page: Control
var page := "home"
var equipment_return := "stages"
var _state: RunCarryover
var _content: Control
var _page_host: Control
var _shell: VBoxContainer
var _warehouse_focus: Control
@onready var warehouse_panel: WarehousePanel = $WarehousePanel


func _ready() -> void:
	var background := TextureRect.new()
	background.texture = preload("res://art/hub/guild_hall.png")
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
	var brand := VBoxContainer.new()
	brand.custom_minimum_size.x = 300
	header.add_child(brand)
	HubUI.label(brand, "DungeonRemnant", &"TitleLabel")
	HubUI.label(brand, "残されたものたちの、もう一度", &"MutedLabel")
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	title_label = HubUI.label(heading, "旅支度の間", &"TitleLabel")
	subtitle_label = HubUI.label(heading, "小さな準備が、大きな冒険につながる。", &"MutedLabel")
	var purse := PanelContainer.new()
	purse.theme_type_variation = &"ItemPanel"
	purse.custom_minimum_size.x = 190
	purse.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(purse)
	gold_label = HubUI.label(purse, "", &"ValueLabel")
	# Gold role is shared with quotes and the warehouse balance.
	gold_label.theme_type_variation = &"GoldLabel"
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page_host = Control.new()
	_page_host.custom_minimum_size.y = 600
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_child(_page_host)
	home_page = _page(Control.new())
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
	sell_page.mode_changed.connect(func(): feedback.text = "")
	departure_page = _page(HubDeparture.new()) as HubDeparture
	departure_page.confirm_requested.connect(func(): show_page("confirm"))
	departure_page.equipment_requested.connect(func(): equipment_return = "confirm"; show_page("equipment"))
	departure_page.departure_requested.connect(func(): start_requested.emit())
	var tree := SkillTreePanel.new()
	upgrade_page = _page(tree)
	tree.hp_requested.connect(func(): purchase_requested.emit())
	tree.skill_requested.connect(func(id: StringName): skill_requested.emit(id))
	tree.entry_requested.connect(func(stage: StageData, floor_number: int): entry_requested.emit(stage, floor_number))
	purchase_button = tree.upgrade_button
	upgrade_label = tree.root_label
	var footer := HBoxContainer.new()
	_shell.add_child(footer)
	back_button = HubUI.button(footer, "戻る  /  Esc", go_back)
	back_button.custom_minimum_size = Vector2(215, 44)
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
	UIMotion.bind_buttons(warehouse_panel)


func _page(control: Control) -> Control:
	_page_host.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.hide()
	return control


func _build_home() -> void:
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"HomeMargin"
	home_page.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	var navigation := HBoxContainer.new()
	navigation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(navigation)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(left)
	var center := HubUI.space(navigation)
	center.size_flags_stretch_ratio = 1.2
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(right)
	start_button = _home_action(left, "出撃", "ステージを選び、次の冒険へ", func(): show_page("stages"))
	start_button.theme_type_variation = &"PrimaryButton"
	equipment_button = _home_action(left, "装備", "装備と持ち込みを整える", func(): equipment_return = "stages"; show_page("equipment"))
	warehouse_button = _home_action(left, "倉庫", "使うもの、残すものを選ぶ", open_warehouse)
	sell_button = _home_action(right, "ショップ", "アイテムを購入・売却する", func(): show_page("sell"))
	upgrade_button = _home_action(right, "永久強化", "冒険の先へ、ずっと残る力", func(): show_page("upgrade"))
	var summary := PanelContainer.new()
	summary.theme_type_variation = &"ItemPanel"
	right.add_child(summary)
	equipment_label = HubUI.label(summary, "", &"MutedLabel")
	var note := HubUI.label(stack, "装備と倉庫は、次の冒険へ引き継がれます。", &"MutedLabel")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hero := AnimatedSprite2D.new()
	hero.name = "Hero"
	hero.sprite_frames = MioAnimation.build_front_idle_frames()
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Anchor the 128px frame at its feet.
	hero.centered = false
	hero.offset = Vector2(-64, -121)
	hero.position = Vector2(640, 448)
	hero.scale = Vector2(2, 2)
	home_page.add_child(hero)
	var eyes := AnimatedSprite2D.new()
	eyes.name = "Eyes"
	eyes.sprite_frames = MioAnimation.build_front_idle_frames(true)
	eyes.animation = &"idle_front"
	eyes.centered = false
	eyes.position = hero.offset + Vector2(55, 31)
	hero.add_child(eyes)
	hero.frame_changed.connect(func(): eyes.set_frame_and_progress(hero.frame, hero.frame_progress))
	hero.play(&"idle_front")
	# Less than one screen pixel of breathing at native UI scale, feet anchored.
	# Keep X scale fixed so the hair and costume never sway sideways.
	var breathing := hero.create_tween().set_loops()
	breathing.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathing.tween_property(hero, "scale:y", 1.994, 2.4)
	breathing.tween_property(hero, "scale:y", 2.0, 2.4)
	hero_button = HubTheme.button(home_page, "", Vector2(550, 206), Vector2(180, 242), func(): hero_speech.visible = not hero_speech.visible)
	hero_button.name = "HeroButton"
	hero_button.tooltip_text = "話しかける"
	hero_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hero_button.theme_type_variation = &"CharacterButton"
	hero_speech = HubTheme.panel(home_page, Vector2(430, 88), Vector2(420, 64))
	hero_speech.name = "HeroSpeech"
	hero_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_speech.theme_type_variation = &"SpeechPanel"
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(198, 63), Vector2(210, 78), Vector2(222, 63)])
	tail.color = hero_speech.get_theme_stylebox("panel").border_color
	hero_speech.add_child(tail)
	var tail_fill := Polygon2D.new()
	tail_fill.polygon = PackedVector2Array([Vector2(200, 62), Vector2(210, 76), Vector2(220, 62)])
	tail_fill.color = hero_speech.get_theme_stylebox("panel").bg_color
	hero_speech.add_child(tail_fill)
	var invitation := HubTheme.label(hero_speech, "準備ができたら、出発しよう。", Vector2(16, 12), Vector2(388, 40), &"GoldLabel")
	invitation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_speech.hide()


func _home_action(parent: Node, text: String, description: String, action: Callable) -> Button:
	var button := HubUI.button(parent, "", action)
	button.custom_minimum_size.y = 124
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var icon := NavigationIcon.new()
	icon.kind = text
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(copy)
	HubUI.label(copy, text + "  ›", &"HeadingLabel")
	HubUI.label(copy, description, &"MutedLabel")
	button.tooltip_text = text + "：" + description
	return button


func _resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(1.0, minf((viewport.x - 40) / 1280.0, (viewport.y - 36) / 810.0))
	_content.size = Vector2(1280, 810)
	_content.scale = Vector2.ONE * factor
	_content.position = (viewport - _content.size * factor) * 0.5


func refresh(state: RunCarryover, message: String = "") -> void:
	_state = state
	gold_label.text = "Gold   %s" % state.gold
	equipment_label.text = "Main  %s\n持ち込み  %d / %d枠\n倉庫      %d / %d枠" % [state.equipment.slots[0].display_name, state.inventory.entries.size(), state.inventory.max_entries, state.storage.entries.size(), state.storage.max_entries]
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
	for control in [home_page, equipment_page, sell_page, departure_page, upgrade_page]:
		control.hide()
	back_button.visible = page != "home"
	feedback.text = ""
	subtitle_label.text = "装備と持ち込みを整え、次のRunへ。"
	match page:
		"home":
			title_label.text = "旅支度の間"
			subtitle_label.text = "小さな準備が、大きな冒険につながる。"
			home_page.show()
			start_button.grab_focus()
		"equipment":
			title_label.text = "装備・持ち込み準備"
			equipment_page.show()
			equipment_page.refresh(_state)
			equipment_page.done_button.text = "出撃確認へ戻る" if equipment_return == "confirm" else "準備完了・ステージ選択へ"
			equipment_page.slots[0].grab_focus()
		"sell":
			title_label.text = "ショップ"
			subtitle_label.text = "品を選び、価格と取引後の所持数を確認。"
			sell_page.show()
			sell_page.refresh(_state)
			sell_page.source_choice.grab_focus()
		"upgrade":
			title_label.text = "永久強化"
			subtitle_label.text = "冒険を越えて残る力。前提条件と次の効果を確認。"
			upgrade_page.show()
			(upgrade_page as SkillTreePanel).focus_first_action()
		"stages":
			title_label.text = "ステージ選択"
			subtitle_label.text = "冒険先を選び、出撃に備える。"
			departure_page.show()
			departure_page.present_selection(stages, _state)
		"confirm":
			var stage := departure_page.selected_stage
			title_label.text = "出撃確認  /  %s・全%d階" % [stage.display_name, stage.floor_count]
			departure_page.show()
			departure_page.present_confirmation(_state)
	for control in [home_page, equipment_page, sell_page, departure_page, upgrade_page]:
		if control.visible:
			UIMotion.of(control).reveal(UIMotion.WINDOW_TIME)


func present_action(kind: StringName, gold_delta: int, slots: Array[int]) -> void:
	# Called only after mutation and persistence succeeded; animation never
	# owns transaction timing, state, focus or input availability.
	preload("res://audio/game_audio.gd").play(self, &"level_up" if kind == &"upgrade" else &"confirm", -22.0)
	if gold_delta != 0:
		feedback.text += "  (%+d Gold)" % gold_delta
		UIMotion.of(gold_label).pulse(1.08, UIMotion.GOLD_TIME)
	UIMotion.of(feedback).reveal()
	match kind:
		&"buy", &"sell":
			UIMotion.of(sell_page.total_label).pulse(1.025, UIMotion.GOLD_TIME)
			UIMotion.of(sell_page.item_list).reveal()
		&"equip":
			for slot in slots:
				UIMotion.of(equipment_page.slots[slot]).pulse()
		&"upgrade":
			(upgrade_page as SkillTreePanel).present_upgrade()
		&"deposit", &"withdraw":
			var destination := "InventoryList" if kind == &"withdraw" else "StorageList"
			UIMotion.of(warehouse_panel.get_node("%" + destination)).reveal()
			UIMotion.of(warehouse_panel.get_node("%Feedback")).reveal()


func open_warehouse() -> void:
	hero_speech.hide()
	if page == "home":
		equipment_return = "stages"
	_warehouse_focus = _content.get_viewport().gui_get_focus_owner()
	_content.hide()
	warehouse_panel.present(_state)


func _warehouse_closed() -> void:
	_content.show()
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

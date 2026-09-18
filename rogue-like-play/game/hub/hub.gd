extends CanvasLayer

signal start_requested
signal purchase_requested
signal storage_transfer_requested(from_storage: bool, index: int)
signal equip_requested(from_storage: bool, index: int, slot: int)
signal unequip_requested(slot: int)
signal scroll_remove_requested(slot: int)
signal swap_requested
signal sell_requested(from_storage: bool, index: int, amount: int)
signal buy_requested(to_storage: bool, item_id: StringName, amount: int)

@export var stages: Array[StageData] = [preload("res://data/stages/ancient_ruins.tres")]
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
var upgrade_page: Control
var page := "home"
var equipment_return := "stages"
var _state: RunCarryover
var _content: Control
var _warehouse_focus: Control
var _page_tween: Tween
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
	shade.color = Color(0.015, 0.02, 0.025, 0.32)
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
	HubTheme.panel(_content, Vector2.ZERO, Vector2(1280, 98))
	title_label = HubTheme.label(_content, "旅支度の間", Vector2(26, 10), Vector2(850, 44), 32)
	subtitle_label = HubTheme.label(_content, "小さな準備が、大きな冒険につながる。", Vector2(28, 58), Vector2(850, 30), 17)
	subtitle_label.modulate = HubTheme.MUTED
	gold_label = HubTheme.label(_content, "", Vector2(970, 24), Vector2(280, 48), 26)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.modulate = HubTheme.GOLD
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
	upgrade_page = _page(Control.new())
	HubTheme.panel(upgrade_page, Vector2(240, 30), Vector2(800, 490))
	HubTheme.label(upgrade_page, "冒険を重ね、少しずつ強く。", Vector2(278, 60), Vector2(724, 54), 30)
	upgrade_label = HubTheme.label(upgrade_page, "", Vector2(278, 148), Vector2(724, 146), 25)
	HubTheme.label(upgrade_page, "強化は次のRunから適用されます。\n死亡・中断しても失われません。", Vector2(278, 300), Vector2(724, 86), 20)
	purchase_button = HubTheme.button(upgrade_page, "", Vector2(278, 420), Vector2(724, 62), func(): purchase_requested.emit())
	back_button = HubTheme.button(_content, "戻る  /  Esc", Vector2(0, 704), Vector2(215, 48), go_back)
	feedback = HubTheme.label(_content, "", Vector2(238, 700), Vector2(1030, 54), 17)
	feedback.modulate = HubTheme.GOLD
	save_label = HubTheme.label(_content, "", Vector2(0, 762), Vector2(1280, 24), 14)
	save_label.modulate = HubTheme.MUTED
	warehouse_panel.theme = _content.theme
	warehouse_panel.transfer_requested.connect(func(source: bool, index: int): storage_transfer_requested.emit(source, index))
	warehouse_panel.closed.connect(_warehouse_closed)
	warehouse_panel.equipment_requested.connect(func(): show_page("equipment"))
	move_child(warehouse_panel, get_child_count() - 1)


func _page(control: Control) -> Control:
	HubTheme.place(control, _content, Vector2(0, 122), Vector2(1280, 560))
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.hide()
	return control


func _build_home() -> void:
	start_button = _home_action("出撃", "ステージを選び、次の冒険へ", Vector2(28, 65), func(): show_page("stages"))
	start_button.add_theme_stylebox_override("normal", HubTheme.box(Color(0.16, 0.13, 0.075, 0.96), HubTheme.GOLD, 2))
	equipment_button = _home_action("装備", "装備と持ち込みを整える", Vector2(28, 205), func(): equipment_return = "stages"; show_page("equipment"))
	warehouse_button = _home_action("倉庫", "使うもの、残すものを選ぶ", Vector2(28, 345), open_warehouse)
	sell_button = _home_action("ショップ", "アイテムを購入・売却する", Vector2(880, 65), func(): show_page("sell"))
	upgrade_button = _home_action("永久強化", "冒険の先へ、ずっと残る力", Vector2(880, 205), func(): show_page("upgrade"))
	var summary := HubTheme.panel(home_page, Vector2(880, 345), Vector2(372, 124))
	equipment_label = HubTheme.label(summary, "", Vector2(20, 14), Vector2(332, 100), 17)
	var hero := AnimatedSprite2D.new()
	hero.sprite_frames = MioAnimation.build_frame_set()
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.position = Vector2(640, 328)
	hero.scale = Vector2(2.5, 2.5)
	home_page.add_child(hero)
	hero.play(&"idle_front")
	var invitation := HubTheme.label(home_page, "準備ができたら、出発しよう。", Vector2(430, 431), Vector2(420, 40), 20)
	invitation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	invitation.modulate = HubTheme.GOLD
	var note := HubTheme.label(home_page, "装備と倉庫は、次の冒険へ引き継がれます。", Vector2(290, 514), Vector2(700, 30), 17)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _home_action(text: String, description: String, position: Vector2, action: Callable) -> Button:
	var button := HubTheme.button(home_page, "", position, Vector2(372, 124), action)
	HubTheme.label(button, text + "    ›", Vector2(24, 17), Vector2(324, 46), 32)
	var hint := HubTheme.label(button, description, Vector2(26, 75), Vector2(320, 30), 16)
	hint.modulate = HubTheme.MUTED
	button.tooltip_text = text + "：" + description
	return button


func _resize() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(1.0, minf((viewport.x - 40) / 1280.0, (viewport.y - 36) / 790.0))
	_content.size = Vector2(1280, 790)
	_content.scale = Vector2.ONE * factor
	_content.position = (viewport - _content.size * factor) * 0.5


func refresh(state: RunCarryover, message: String = "") -> void:
	_state = state
	gold_label.text = "Gold   %s" % state.gold
	equipment_label.text = "Main  %s\n持ち込み  %d / %d枠\n倉庫      %d / %d枠" % [state.equipment.slots[0].display_name, state.inventory.entries.size(), state.inventory.max_entries, state.storage.entries.size(), state.storage.max_entries]
	var definition := state.upgrade
	upgrade_label.text = "%s    %d / %d\n\n最大HP ＋%d   /   1段階ごとに＋%d" % [definition.display_name, state.hp_upgrade_level, definition.costs.size(), definition.hp_bonus(state.hp_upgrade_level), definition.hp_per_level]
	var cost := definition.price(state.hp_upgrade_level)
	purchase_button.text = "強化上限に到達" if cost < 0 else "最大HPを強化する  /  %d Gold" % cost
	purchase_button.disabled = cost < 0 or state.gold < cost
	feedback.text = message
	equipment_page.refresh(state)
	sell_page.refresh(state)
	warehouse_panel.refresh(state)
	if page == "confirm":
		departure_page.present_confirmation(state)
	if not home_page.visible and page == "home":
		show_page("home")


func show_page(target: String) -> void:
	if target == "confirm" and (departure_page.selected_stage == null or not departure_page.selected_stage.available):
		return
	page = target
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
			sell_page.show()
			sell_page.refresh(_state)
			sell_page.source_choice.grab_focus()
		"upgrade":
			title_label.text = "永久強化"
			upgrade_page.show()
			back_button.grab_focus()
			if purchase_button.disabled:
				feedback.text = "強化上限に到達しています。" if _state.upgrade.price(_state.hp_upgrade_level) < 0 else "Goldが不足しています。"
		"stages":
			title_label.text = "ステージ選択"
			departure_page.show()
			departure_page.present_selection(stages)
		"confirm":
			var stage := departure_page.selected_stage
			title_label.text = "出撃確認  /  %s・全%d階" % [stage.display_name, stage.floor_count]
			departure_page.show()
			departure_page.present_confirmation(_state)
	if _page_tween != null:
		_page_tween.kill()
	_page_tween = create_tween()
	for control in [home_page, equipment_page, sell_page, departure_page, upgrade_page]:
		if control.visible:
			control.modulate.a = 0.6
			_page_tween.tween_property(control, "modulate:a", 1.0, 0.14)


func open_warehouse() -> void:
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

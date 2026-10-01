class_name HubLobby
extends Control

# The hub's home, laid out like a game lobby rather than a page of cards:
# a decorated menu on the left, the chosen entry's short information floating
# over the floor, and the heroine standing in the hall on the right. The hall
# painting runs behind all three so they read as one scene.
#
# Choosing and entering are separate. Keyboard and gamepad focus chooses, and
# confirming the focused entry enters it. A click chooses an entry; clicking
# the chosen entry again, or the panel's button, enters it.

signal selection_changed(id: StringName)
signal activated(id: StringName)
signal settings_changed

# id, menu label, NavigationIcon kind
const ENTRIES := [
	[&"departure", "出撃", "出撃"],
	[&"equipment", "装備", "装備"],
	[&"storage", "倉庫", "倉庫"],
	[&"shop", "ショップ", "ショップ"],
	[&"upgrade", "強化", "永久強化"],
	[&"settings", "設定", "設定"],
]
const ACTIONS := {
	&"departure": "行き先を選ぶ",
	&"equipment": "装備を整える",
	&"storage": "倉庫を開く",
	&"shop": "ショップに入る",
	&"upgrade": "強化を選ぶ",
}
const DESCRIPTIONS := {
	&"equipment": "身につけるもの、背負っていくもの。",
	&"storage": "使うもの、残すものを選ぶ。冒険で失うことはない。",
	&"shop": "薬も武具も、金次第。",
	&"upgrade": "冒険の記憶は、この身に残る。",
	&"settings": "音と画面を整える。",
}
# Each panel shows the illustration of what it opens.
const ART := {
	&"equipment": preload("res://art/hub/cards/weapons.png"),
	&"storage": preload("res://art/hub/cards/chests.png"),
	&"shop": preload("res://art/hub/cards/shop.png"),
	&"upgrade": preload("res://art/hub/cards/books.png"),
}
const HERO_TEXTURE := preload("res://art/characters/mio_lobby.png")
# Layout in the 1440×900 base viewport. The menu keeps about a fifth of the
# width; the heroine stands about two thirds of the height tall.
const MENU_WIDTH := 300.0
const MENU_TOP := 168.0
const ROW_HEIGHT := 80.0
const PANEL_RECT := Rect2(352, 0, 600, 0)
const PANEL_BOTTOM := 96.0
const HERO_HEIGHT := 0.68
const HERO_CENTER_X := 0.835
const HERO_FEET_Y := 0.965

var buttons: Array[Button] = []
var selected := 0
var decide_button: Button
var title_label: Label
var description_label: Label
var hero: TextureRect
var hero_button: Button
var hero_speech: Panel
var equipment_label: Label
var main_glyph: Control
var carried_label: Label
var stored_label: Label
var gold_value: Label
var upgrade_value: Label
var stage_strip: Label
var volume_choice: SegmentedChoice
var display_choice: SegmentedChoice
var settings: GameSettings
var panel: PanelContainer
var _art: TextureRect
var _details := {}
var _state: RunCarryover
var _stage: StageData
var _band_y := 0.0
var _band_tween: Tween


func _init() -> void:
	name = "Lobby"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hero()
	_build_menu()
	_build_panel()
	# The speech bubble draws over the panel.
	move_child(hero_speech, get_child_count() - 1)
	resized.connect(_place_hero)
	_place_hero()
	_band_y = _row_rect(selected).position.y
	_show_entry()


func _build_menu() -> void:
	var previous: Button
	for index in ENTRIES.size():
		var entry: Array = ENTRIES[index]
		var button := Button.new()
		button.name = String(entry[0]).capitalize().replace(" ", "") + "Entry"
		button.text = entry[1]
		button.theme_type_variation = &"LobbyMenuButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = entry[1]
		add_child(button)
		var row := _row_rect(index)
		button.position = row.position
		button.size = row.size
		var icon := NavigationIcon.new()
		icon.name = "Icon"
		icon.kind = entry[2]
		button.add_child(icon)
		icon.position = Vector2(30, (row.size.y - 48) * 0.5)
		icon.size = Vector2(48, 48)
		button.pressed.connect(_pressed.bind(index))
		button.focus_entered.connect(_focused.bind(index))
		if previous != null:
			previous.focus_neighbor_bottom = button.get_path()
			button.focus_neighbor_top = previous.get_path()
		previous = button
		buttons.append(button)
	buttons[0].focus_neighbor_top = buttons[0].get_path()
	buttons[-1].focus_neighbor_bottom = buttons[-1].get_path()


func _row_rect(index: int) -> Rect2:
	return Rect2(Vector2(16, MENU_TOP + index * ROW_HEIGHT), Vector2(MENU_WIDTH - 16, ROW_HEIGHT))


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "InfoPanel"
	panel.theme_type_variation = &"LobbyInfoPanel"
	add_child(panel)
	# Anchored to the bottom and growing upwards, so the panel keeps to the
	# floor whatever the chosen entry needs.
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = PANEL_RECT.position.x
	panel.offset_right = PANEL_RECT.end.x
	panel.offset_bottom = -PANEL_BOTTOM
	panel.offset_top = -PANEL_BOTTOM
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.modulate = get_theme_color(&"art_tint", &"HubLobby")
	panel.add_child(_art)
	# The art fades out towards the text on the left.
	var fade := Gradient.new()
	var ground := get_theme_stylebox(&"panel", &"LobbyInfoPanel").get(&"bg_color") as Color
	fade.set_color(0, Color(ground, 1.0))
	fade.set_color(1, Color(ground, 0.15))
	fade.add_point(0.45, Color(ground, 0.82))
	var veil_texture := GradientTexture2D.new()
	veil_texture.gradient = fade
	veil_texture.fill_from = Vector2(0, 0.5)
	veil_texture.fill_to = Vector2(1, 0.5)
	var veil := TextureRect.new()
	veil.texture = veil_texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(veil)
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"LobbyInfoMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.theme_type_variation = &"DetailStack"
	margin.add_child(stack)
	title_label = HubUI.label(stack, "", &"LobbyTitle")
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	description_label = HubUI.label(stack, "", &"DescriptionLabel")
	_details[&"departure"] = _strip(stack)
	stage_strip = HubUI.label(_details[&"departure"], "", &"BodyLabel")
	stage_strip.autowrap_mode = TextServer.AUTOWRAP_OFF
	stage_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gear: HBoxContainer = _strip(stack)
	_details[&"equipment"] = gear
	main_glyph = Control.new()
	main_glyph.custom_minimum_size = Vector2(26, 26)
	main_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_glyph.draw.connect(_draw_main_glyph)
	gear.add_child(main_glyph)
	equipment_label = HubUI.label(gear, "", &"ItemNameLabel")
	equipment_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var room: HBoxContainer = _strip(stack)
	_details[&"storage"] = room
	carried_label = _fact(room, "持ち込み")
	_divider(room)
	stored_label = _fact(room, "倉庫")
	var purse: HBoxContainer = _strip(stack)
	_details[&"shop"] = purse
	gold_value = _fact(purse, "所持金", &"GoldLabel")
	var growth: HBoxContainer = _strip(stack)
	_details[&"upgrade"] = growth
	upgrade_value = _fact(growth, "習得した強化")
	var options := VBoxContainer.new()
	options.theme_type_variation = &"DetailStack"
	stack.add_child(options)
	_details[&"settings"] = options
	volume_choice = _setting(options, "音量", GameSettings.VOLUME_NAMES)
	volume_choice.item_selected.connect(func(index: int):
		settings.volume_step = index
		settings.apply_volume()
		settings_changed.emit())
	display_choice = _setting(options, "画面", ["ウィンドウ", "全画面"] as Array[String])
	display_choice.item_selected.connect(func(index: int):
		settings.fullscreen = index == 1
		settings.apply_display()
		settings_changed.emit())
	decide_button = HubUI.button(stack, "", func(): activated.emit(selected_id()), &"PrimaryButton")
	decide_button.name = "Decide"
	decide_button.custom_minimum_size.y = 52
	var frame := Control.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_panel_frame.bind(frame))
	panel.add_child(frame)


func _strip(parent: Node) -> HBoxContainer:
	var inset := PanelContainer.new()
	inset.theme_type_variation = &"InsetPanel"
	parent.add_child(inset)
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"CompactMargin"
	inset.add_child(margin)
	var row := HBoxContainer.new()
	row.theme_type_variation = &"CompactRow"
	margin.add_child(row)
	return row


func _fact(row: HBoxContainer, caption: String, role: StringName = &"ValueLabel") -> Label:
	var caption_label := HubUI.label(row, caption, &"MutedLabel")
	caption_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := HubUI.label(row, "", role)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return value


func _divider(row: HBoxContainer) -> void:
	var line := VSeparator.new()
	line.theme_type_variation = &"LobbyDivider"
	row.add_child(line)


func _setting(parent: Node, caption: String, names: Array[String]) -> SegmentedChoice:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"CompactRow"
	parent.add_child(row)
	var caption_label := HubUI.label(row, caption, &"MutedLabel")
	caption_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption_label.custom_minimum_size.x = 56
	caption_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var choice := SegmentedChoice.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(choice)
	for text in names:
		choice.add_item(text)
	return choice


func _build_hero() -> void:
	hero = TextureRect.new()
	hero.name = "Hero"
	hero.texture = HERO_TEXTURE
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Settle the bright illustration into the lantern light of the hall.
	hero.modulate = get_theme_color(&"hero_tint", &"HubLobby")
	add_child(hero)
	# Barely visible breathing, anchored at the feet.
	var breathing := hero.create_tween().set_loops()
	breathing.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathing.tween_property(hero, "scale:y", 1.004, 2.4)
	breathing.tween_property(hero, "scale:y", 1.0, 2.4)
	hero_button = Button.new()
	hero_button.name = "HeroButton"
	hero_button.theme_type_variation = &"CharacterButton"
	hero_button.tooltip_text = "話しかける"
	hero_button.focus_mode = Control.FOCUS_NONE
	hero_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hero_button.pressed.connect(func(): hero_speech.visible = not hero_speech.visible)
	add_child(hero_button)
	hero_speech = Panel.new()
	hero_speech.name = "HeroSpeech"
	hero_speech.theme_type_variation = &"SpeechPanel"
	hero_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_speech.size = Vector2(300, 60)
	add_child(hero_speech)
	# The tail points down, towards her head.
	var border := hero_speech.get_theme_stylebox("panel").get(&"border_color") as Color
	var fill := hero_speech.get_theme_stylebox("panel").get(&"bg_color") as Color
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(138, 59), Vector2(150, 74), Vector2(162, 59)])
	tail.color = border
	hero_speech.add_child(tail)
	var tail_fill := Polygon2D.new()
	tail_fill.polygon = PackedVector2Array([Vector2(140, 58), Vector2(150, 71), Vector2(160, 58)])
	tail_fill.color = fill
	hero_speech.add_child(tail_fill)
	var invitation := Label.new()
	invitation.text = "準備ができたら、出発しよう。"
	invitation.theme_type_variation = &"ItemNameLabel"
	invitation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	invitation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	invitation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_speech.add_child(invitation)
	invitation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero_speech.hide()


func _place_hero() -> void:
	var extent := Vector2(HERO_TEXTURE.get_size().aspect(), 1.0) * size.y * HERO_HEIGHT
	var feet := Vector2(size.x * HERO_CENTER_X, size.y * HERO_FEET_Y)
	hero.size = extent
	hero.position = feet - Vector2(extent.x * 0.5, extent.y)
	hero.pivot_offset = Vector2(extent.x * 0.5, extent.y)
	# Only her figure answers the pointer, not the empty corners of the art.
	hero_button.position = hero.position + Vector2(extent.x * 0.22, extent.y * 0.04)
	hero_button.size = Vector2(extent.x * 0.56, extent.y * 0.9)
	# Above her head, clear of the information panel.
	hero_speech.position = hero.position + Vector2(extent.x * 0.45 - hero_speech.size.x * 0.5, -hero_speech.size.y - 18)
	queue_redraw()


func refresh(state: RunCarryover, stage: StageData) -> void:
	_state = state
	_stage = stage
	equipment_label.text = state.equipment.slots[Equipment.Slot.MAIN].display_name
	main_glyph.queue_redraw()
	carried_label.text = "%d / %d 枠" % [state.inventory.entries.size(), state.inventory.max_entries]
	stored_label.text = "%d / %d 枠" % [state.storage.entries.size(), state.storage.max_entries]
	gold_value.text = "%d G" % state.gold
	var ranks := state.hp_upgrade_level
	for id in state.skill_levels:
		ranks += int(state.skill_levels[id])
	upgrade_value.text = "%d 段階" % ranks
	if stage != null:
		stage_strip.text = "全%d階    難易度  %s" % [stage.floor_count, stage.difficulty]
	if settings != null:
		volume_choice.select(settings.volume_step)
		display_choice.select(1 if settings.fullscreen else 0)
	_show_entry()


func selected_id() -> StringName:
	return ENTRIES[selected][0]


func select(index: int) -> void:
	if index == selected:
		return
	selected = index
	hero_speech.hide()
	_show_entry()
	if _band_tween != null:
		_band_tween.kill()
	_band_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_band_tween.tween_method(_move_band, _band_y, _row_rect(index).position.y, UIMotion.SELECT_TIME)
	UIMotion.of(panel).reveal(UIMotion.SELECT_TIME)
	selection_changed.emit(selected_id())


func focus_selected() -> void:
	buttons[selected].grab_focus()


func focus_first_setting() -> void:
	volume_choice.focus_selected()


func _move_band(value: float) -> void:
	_band_y = value
	queue_redraw()


func _pressed(index: int) -> void:
	if index == selected:
		activated.emit(selected_id())
	else:
		select(index)


# A click gives focus on mouse down; the click itself chooses on release, so
# only focus that keys or the gamepad moved chooses here.
func _focused(index: int) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		select(index)


func _show_entry() -> void:
	var id := selected_id()
	for index in buttons.size():
		var chosen := index == selected
		buttons[index].theme_type_variation = &"LobbyMenuButtonSelected" if chosen else &"LobbyMenuButton"
		buttons[index].get_node("Icon").modulate = Color.WHITE if chosen else get_theme_color(&"icon_rest", &"HubLobby")
	for key in _details:
		var detail: Control = _details[key]
		# Strips sit inside an inset panel and margin; show the outer one.
		(detail if key == &"settings" else detail.get_parent().get_parent()).visible = key == id
	if id == &"departure" and _stage != null:
		title_label.text = _stage.display_name
		description_label.text = _stage.description
		_art.texture = _stage.illustration
	else:
		title_label.text = ENTRIES[selected][1]
		description_label.text = DESCRIPTIONS.get(id, "")
		_art.texture = ART.get(id)
	decide_button.visible = ACTIONS.has(id)
	decide_button.text = ACTIONS.get(id, "")
	decide_button.tooltip_text = decide_button.text
	# Right from the menu reaches the panel's first control.
	var target: Control = volume_choice.option(volume_choice.selected) if id == &"settings" else decide_button
	for button in buttons:
		button.focus_neighbor_right = target.get_path()
	decide_button.focus_neighbor_left = buttons[selected].get_path()
	for index in volume_choice.item_count:
		volume_choice.option(index).focus_neighbor_left = buttons[selected].get_path() if index == 0 else NodePath()
	queue_redraw()


func _draw_main_glyph() -> void:
	if _state != null and _state.equipment.slots[Equipment.Slot.MAIN] != null:
		ItemGlyph.paint(main_glyph, Rect2(Vector2.ZERO, main_glyph.size), _state.equipment.slots[Equipment.Slot.MAIN], main_glyph.get_theme_color(&"font_color", &"GoldLabel"))


func _draw() -> void:
	_draw_menu_slab()
	_draw_selection()
	# A soft pool of shade grounds the heroine on the floor.
	var feet := hero.position + Vector2(hero.size.x * 0.5, hero.size.y)
	var shadow := get_theme_color(&"shadow", &"HubLobby")
	for ring in 4:
		var radius := Vector2(150 - ring * 28, 22 - ring * 4)
		_draw_ellipse(feet + Vector2(0, -4), radius, Color(shadow, shadow.a * 0.3))


func _draw_menu_slab() -> void:
	var slab := get_theme_color(&"slab", &"HubLobby")
	var rail := get_theme_color(&"rail", &"HubLobby")
	# Dark stone slab that fades into the hall instead of ending in a box edge.
	var colors := PackedColorArray([slab, slab, Color(slab, slab.a * 0.82), Color(slab, 0.0)])
	var right := MENU_WIDTH + 70.0
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(MENU_WIDTH - 8, 0), Vector2(MENU_WIDTH - 8, size.y), Vector2(0, size.y)]), PackedColorArray([slab, Color(slab, slab.a * 0.82), Color(slab, slab.a * 0.82), slab]))
	draw_polygon(PackedVector2Array([Vector2(MENU_WIDTH - 8, 0), Vector2(right, 0), Vector2(right, size.y), Vector2(MENU_WIDTH - 8, size.y)]), PackedColorArray([colors[2], colors[3], colors[3], colors[2]]))
	# Double gilt rail with diamond studs along the slab's edge.
	var x := MENU_WIDTH - 6.0
	draw_line(Vector2(x, 36), Vector2(x, size.y - 36), Color(rail, 0.75), 2.0, true)
	draw_line(Vector2(x - 7, 60), Vector2(x - 7, size.y - 60), Color(rail, 0.3), 1.0, true)
	for y in [36.0, size.y * 0.5, size.y - 36.0]:
		_diamond(Vector2(x, y), 7.0, rail)
	# Crest above the entries: a compass star in a ring.
	var crest := Vector2(MENU_WIDTH * 0.5, MENU_TOP - 64)
	draw_arc(crest, 30, 0, TAU, 48, Color(rail, 0.55), 1.5, true)
	draw_arc(crest, 24, 0, TAU, 48, Color(rail, 0.25), 1.0, true)
	for step in 8:
		var length := 40.0 if step % 2 == 0 else 22.0
		var angle := step * TAU / 8.0 - PI * 0.5
		var tip := crest + Vector2.from_angle(angle) * length
		var side := Vector2.from_angle(angle + PI * 0.5) * (5.0 if step % 2 == 0 else 3.5)
		draw_colored_polygon(PackedVector2Array([crest + side, tip, crest - side]), Color(rail, 0.85 if step % 2 == 0 else 0.5))
	draw_circle(crest, 3.0, rail)
	_ornament_line(MENU_TOP - 14)
	_ornament_line(MENU_TOP + ENTRIES.size() * ROW_HEIGHT + 14)
	# Hairlines between the entries, faded at both ends.
	for index in range(1, ENTRIES.size()):
		var y := MENU_TOP + index * ROW_HEIGHT
		var hair := Color(rail, 0.22)
		draw_polyline_colors(PackedVector2Array([Vector2(40, y), Vector2(150, y), Vector2(262, y)]), PackedColorArray([Color(hair, 0.0), hair, Color(hair, 0.0)]), 1.0, true)


func _ornament_line(y: float) -> void:
	var rail := get_theme_color(&"rail", &"HubLobby")
	var middle := MENU_WIDTH * 0.5
	draw_polyline_colors(PackedVector2Array([Vector2(28, y), Vector2(middle - 14, y)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.7)]), 1.0, true)
	draw_polyline_colors(PackedVector2Array([Vector2(middle + 14, y), Vector2(MENU_WIDTH - 28, y)]), PackedColorArray([Color(rail, 0.7), Color(rail, 0.0)]), 1.0, true)
	_diamond(Vector2(middle, y), 6.0, rail)


func _draw_selection() -> void:
	var gold := get_theme_color(&"band", &"HubLobby")
	var rail := get_theme_color(&"rail", &"HubLobby")
	var top := _band_y + 8.0
	var bottom := _band_y + ROW_HEIGHT - 8.0
	var middle := (top + bottom) * 0.5
	var tip := MENU_WIDTH + 22.0
	# Warm light across the chosen row, ending in a point past the rail.
	var shape := PackedVector2Array([Vector2(16, top), Vector2(tip - 22, top), Vector2(tip, middle), Vector2(tip - 22, bottom), Vector2(16, bottom)])
	draw_polygon(shape, PackedColorArray([Color(gold, gold.a * 0.35), Color(gold, gold.a), Color(gold, gold.a * 1.1), Color(gold, gold.a), Color(gold, gold.a * 0.35)]))
	draw_polyline_colors(PackedVector2Array([Vector2(16, top), Vector2(tip - 22, top), Vector2(tip, middle), Vector2(tip - 22, bottom), Vector2(16, bottom)]), PackedColorArray([Color(rail, 0.0), Color(rail, 0.9), rail, Color(rail, 0.9), Color(rail, 0.0)]), 1.5, true)
	_diamond(Vector2(tip, middle), 5.0, rail)
	# Halo behind the chosen icon.
	var halo := Vector2(16 + 54, middle)
	for ring in 5:
		draw_circle(halo, 34.0 - ring * 6.0, Color(gold, gold.a * 0.35))


func _draw_panel_frame(frame: Control) -> void:
	var rail := get_theme_color(&"rail", &"HubLobby")
	var rect := Rect2(Vector2.ZERO, frame.size)
	frame.draw_rect(rect.grow(-1), Color(rail, 0.55), false, 1.0)
	frame.draw_rect(rect.grow(-6), Color(rail, 0.18), false, 1.0)
	var arm := 26.0
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var inward := Vector2(signf(rect.get_center().x - corner.x), signf(rect.get_center().y - corner.y))
		var at: Vector2 = corner + inward * 3.0
		frame.draw_polyline(PackedVector2Array([at + Vector2(inward.x * arm, 0), at, at + Vector2(0, inward.y * arm)]), rail, 2.0, true)
	for center in [Vector2(rect.get_center().x, 1), Vector2(rect.get_center().x, rect.end.y - 1)]:
		frame.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -6), center + Vector2(6, 0), center + Vector2(0, 6), center + Vector2(-6, 0)]), rail)


func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 32:
		points.append(center + Vector2.from_angle(step * TAU / 32.0) * radius)
	draw_colored_polygon(points, color)
